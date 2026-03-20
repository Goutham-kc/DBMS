import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

/// ─── JOIN CODE DESIGN ────────────────────────────────────────────────────
/// The gyms table now has TWO separate join codes:
///   trainer_code  — 8-char alphanumeric, shared only with trainers
///   member_code   — 8-char alphanumeric, shared only with members
///
/// Required SQL (run once in Supabase SQL Editor):
///
///   ALTER TABLE gyms
///     ADD COLUMN IF NOT EXISTS trainer_code TEXT UNIQUE,
///     ADD COLUMN IF NOT EXISTS member_code  TEXT UNIQUE;
///
///   -- Back-fill any existing gyms with random codes:
///   UPDATE gyms
///     SET trainer_code = upper(substring(gen_random_uuid()::text, 1, 8)),
///         member_code  = upper(substring(gen_random_uuid()::text, 1, 8))
///   WHERE trainer_code IS NULL OR member_code IS NULL;
/// ─────────────────────────────────────────────────────────────────────────

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final _supabase = Supabase.instance.client;

  // ──────────────────────────────────────────────────────────────
  // ENSURE PROFILE EXISTS
  // ──────────────────────────────────────────────────────────────

  Future<void> ensureProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase.from('profiles').upsert(
        {
          'id': user.id,
          'email': user.email ?? '',
          'app_role': 'none',
          'role': 'none',
          'membership_role': null,
          'gym_id': null,
          'trainer_id': null,
          'is_owner': false,
        },
        onConflict: 'id',
        ignoreDuplicates: true,
      );
    } catch (e) {
      debugPrint('[SupabaseService] ensureProfile error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // GET USER PROFILE
  // ──────────────────────────────────────────────────────────────

  Future<UserModel?> getUserData(String uid) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      return res != null ? UserModel.fromMap(res) : null;
    } catch (e) {
      debugPrint('[SupabaseService] getUserData error: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // SETUP OWNER  — creates gym with both join codes
  // ──────────────────────────────────────────────────────────────

  Future<void> setupAsOwner(String uid) async {
    final existingGym = await _supabase
        .from('gyms')
        .select('id')
        .eq('owner_id', uid)
        .maybeSingle();

    String gymId;

    if (existingGym != null) {
      gymId = existingGym['id'] as String;
    } else {
      // Generate two short random codes
      final trainerCode = _randomCode();
      final memberCode = _randomCode();

      final gymRes = await _supabase.from('gyms').insert({
        'owner_id': uid,
        'gym_name': 'New Fitness Center',
        'trainer_code': trainerCode,
        'member_code': memberCode,
      }).select().single();
      gymId = gymRes['id'] as String;
    }

    await _supabase.from('profiles').upsert(
      {
        'id': uid,
        'gym_id': gymId,
        'membership_role': 'owner',
        'app_role': 'owner',
        'role': 'owner',
        'is_owner': true,
      },
      onConflict: 'id',
    );
  }

  // ──────────────────────────────────────────────────────────────
  // JOIN GYM — validates against role-specific code
  //
  // Trainers enter the trainer_code.
  // Members  enter the member_code.
  // Wrong code type → returns JoinResult.wrongCode.
  // ──────────────────────────────────────────────────────────────

  Future<JoinResult> joinGym({
    required String code,
    required String role,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return JoinResult.error;

    try {
      final codeColumn = role == 'trainer' ? 'trainer_code' : 'member_code';

      // Look up gym by the role-specific code
      final gym = await _supabase
          .from('gyms')
          .select('id, trainer_code, member_code')
          .eq(codeColumn, code.toUpperCase().trim())
          .maybeSingle();

      if (gym == null) {
        // Maybe they entered the OTHER role's code
        final otherColumn =
            role == 'trainer' ? 'member_code' : 'trainer_code';
        final wrong = await _supabase
            .from('gyms')
            .select('id')
            .eq(otherColumn, code.toUpperCase().trim())
            .maybeSingle();
        if (wrong != null) return JoinResult.wrongCode;
        return JoinResult.notFound;
      }

      final gymId = gym['id'] as String;

      String? assignedTrainerId;
      if (role == 'member') {
        assignedTrainerId = await _autoAssignTrainer(gymId);
      }

      final updated = await _supabase
          .from('profiles')
          .update({
            'gym_id': gymId,
            'membership_role': role,
            'app_role': role,
            'role': role,
            'trainer_id': assignedTrainerId,
            'is_owner': false,
          })
          .eq('id', user.id)
          .select();

      return updated.isNotEmpty ? JoinResult.success : JoinResult.error;
    } catch (e) {
      debugPrint('[SupabaseService] joinGym error: $e');
      return JoinResult.error;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // AUTO-ASSIGN TRAINER (load-balanced)
  // ──────────────────────────────────────────────────────────────

  Future<String?> _autoAssignTrainer(String gymId) async {
    try {
      final trainers = await _supabase
          .from('profiles')
          .select('id')
          .eq('gym_id', gymId)
          .eq('membership_role', 'trainer');

      if (trainers.isEmpty) return null;

      final members = await _supabase
          .from('profiles')
          .select('trainer_id')
          .eq('gym_id', gymId)
          .eq('membership_role', 'member');

      final counts = <String, int>{};
      for (final t in trainers) {
        counts[t['id'] as String] = 0;
      }
      for (final m in members) {
        final tid = m['trainer_id'] as String?;
        if (tid != null && counts.containsKey(tid)) {
          counts[tid] = counts[tid]! + 1;
        }
      }

      final bestId =
          counts.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
      debugPrint('[SupabaseService] Auto-assigned trainer $bestId '
          '(${counts[bestId]} existing members)');
      return bestId;
    } catch (e) {
      debugPrint('[SupabaseService] _autoAssignTrainer error: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // UPDATE GYM NAME
  // ──────────────────────────────────────────────────────────────

  Future<bool> updateGymName({
    required String gymId,
    required String newName,
  }) async {
    try {
      await _supabase
          .from('gyms')
          .update({'gym_name': newName})
          .eq('id', gymId);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] updateGymName error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // ASSIGN TRAINER TO MEMBER  (owner manual / reassign)
  // ──────────────────────────────────────────────────────────────

  Future<bool> assignTrainerToMember({
    required String memberId,
    required String? trainerId,
  }) async {
    try {
      await _supabase
          .from('profiles')
          .update({'trainer_id': trainerId})
          .eq('id', memberId);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] assignTrainerToMember error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // GET GYM ROSTER
  // ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getGymRoster(String gymId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, email, membership_role, trainer_id')
          .eq('gym_id', gymId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[SupabaseService] getGymRoster error: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────
  // SIGN OUT
  // ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('profiles').update({
          'app_role': 'none',
          'role': 'none',
        }).eq('id', user.id);
      } catch (e) {
        debugPrint('[SupabaseService] signOut error: $e');
      }
    }
    await _supabase.auth.signOut();
  }

  // ──────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────

  /// Generates an 8-character uppercase alphanumeric code.
  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = DateTime.now().microsecondsSinceEpoch;
    final buf = StringBuffer();
    var seed = rand;
    for (var i = 0; i < 8; i++) {
      seed = (seed * 6364136223846793005 + 1442695040888963407) & 0xFFFFFFFF;
      buf.write(chars[seed.abs() % chars.length]);
    }
    return buf.toString();
  }
}

/// Result codes for joinGym()
enum JoinResult {
  success,
  notFound,   // code doesn't match any gym
  wrongCode,  // code exists but for the other role
  error,      // unexpected exception
}