import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  // ================= GET USER PROFILE =================
  Future<UserModel?> getUserData(String uid) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      return res != null ? UserModel.fromMap(res) : null;
    } catch (_) {
      return null;
    }
  }

  // ================= GET GYM ROSTER =================
  Future<List<Map<String, dynamic>>> getGymRoster(String gymId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, email, membership_role, trainer_id')
          .eq('gym_id', gymId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Roster error: $e");
      return [];
    }
  }

  // ================= SETUP OWNER =================
  Future<void> setupAsOwner(String uid) async {
    final gymRes = await _supabase.from('gyms').insert({
      'owner_id': uid,
      'gym_name': 'New Fitness Center'
    }).select().single();

    final newGymId = gymRes['id'];

    await _supabase.from('profiles').update({
      'gym_id': newGymId,
      'membership_role': 'owner',
      'app_role': 'owner',
      'role': 'owner',
      'is_owner': true,
    }).eq('id', uid);
  }

  // ================= JOIN GYM =================
  Future<bool> joinGym({
    required String gymId,
    required String role,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final gym = await _supabase
        .from('gyms')
        .select('id')
        .eq('id', gymId)
        .maybeSingle();

    if (gym == null) return false;

    final updated = await _supabase
        .from('profiles')
        .update({
          'gym_id': gymId,
          'membership_role': role,
          'app_role': role,
          'role': role,
          'is_owner': false,
        })
        .eq('id', user.id)
        .select();

    return updated.isNotEmpty;
  }

  // ================= SIGN OUT =================
  Future<void> signOut() async {
    final user = _supabase.auth.currentUser;

    if (user != null) {
      await _supabase
          .from('profiles')
          .update({'app_role': 'none'})
          .eq('id', user.id);
    }

    await _supabase.auth.signOut();
  }
}