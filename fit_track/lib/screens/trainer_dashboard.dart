import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'assign_workout_screen.dart';

/// TrainerDashboard
///
/// FIX: Stream now filters by trainer_id server-side (not client-side)
/// so we never download the entire profiles table.
///
/// NEW: Each member card shows a workout summary and quick-access
/// to the AssignWorkoutScreen. The card also displays a "days covered"
/// progress indicator so the trainer can see at a glance which
/// members have full workout plans.
class TrainerDashboard extends StatefulWidget {
  const TrainerDashboard({super.key});

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  final _supabase = Supabase.instance.client;

  // Cache of member_id → workout day count, refreshed after each
  // visit to AssignWorkoutScreen.
  final Map<String, int> _workoutDayCounts = {};

  late final String _trainerId;

  @override
  void initState() {
    super.initState();
    _trainerId = _supabase.auth.currentUser!.id;
    _refreshWorkoutCounts();
  }

  // ──────────────────────────────────────────────────────────────
  // WORKOUT COUNT (how many days are assigned per member)
  // ──────────────────────────────────────────────────────────────

  Future<void> _refreshWorkoutCounts() async {
    try {
      final rows = await _supabase
          .from('workouts')
          .select('member_id')
          .eq('trainer_id', _trainerId);

      final counts = <String, int>{};
      for (final row in rows) {
        final id = row['member_id'] as String;
        counts[id] = (counts[id] ?? 0) + 1;
      }

      if (mounted) setState(() => _workoutDayCounts.addAll(counts));
    } catch (e) {
      debugPrint('[TrainerDashboard] workout count error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // LOGOUT
  // ──────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _supabase.from('profiles').update({
        'role': 'none',
        'app_role': 'none',
      }).eq('id', user.id);
    }
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // NAVIGATE TO ASSIGN WORKOUT
  // ──────────────────────────────────────────────────────────────

  Future<void> _openAssignWorkout(Map<String, dynamic> member) async {
    final didSave = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AssignWorkoutScreen(
          memberId: member['id'] as String,
          memberEmail: member['email'] as String? ?? 'Member',
          gymId: member['gym_id'] as String? ?? '',
        ),
      ),
    );

    // Refresh day counts if trainer saved something
    if (didSave == true) _refreshWorkoutCounts();
  }

  // ──────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainer Hub'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh workout counts',
            onPressed: _refreshWorkoutCounts,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),

      // ── FIX: Filter by trainer_id server-side ─────────────────
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('profiles')
            .stream(primaryKey: ['id'])
            .eq('trainer_id', _trainerId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Post-filter for membership_role so we don't show the
          // trainer's own profile if they share the same trainer_id.
          final members = snapshot.data!
              .where((p) => p['membership_role'] == 'member')
              .toList();

          if (members.isEmpty) {
            return _emptyState();
          }

          return Column(
            children: [
              _summaryBanner(members.length),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: members.length,
                  itemBuilder: (_, i) =>
                      _memberCard(members[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // WIDGETS
  // ──────────────────────────────────────────────────────────────

  Widget _summaryBanner(int count) {
    return Container(
      color: Colors.orange.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.people, color: Colors.orange),
          const SizedBox(width: 8),
          Text(
            '$count member${count == 1 ? '' : 's'} assigned to you',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _memberCard(Map<String, dynamic> member) {
    final memberId = member['id'] as String;
    final email = member['email'] as String? ?? 'Member';
    final dayCount = _workoutDayCounts[memberId] ?? 0;
    final progress = dayCount / 7;

    final statusColor = dayCount == 0
        ? Colors.red.shade300
        : dayCount < 5
            ? Colors.orange.shade400
            : Colors.green.shade500;

    final statusText = dayCount == 0
        ? 'No workout assigned'
        : '$dayCount/7 days planned';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openAssignWorkout(member),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: Text(
                      email[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.circle,
                                size: 8, color: statusColor),
                            const SizedBox(width: 4),
                            Text(statusText,
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // ── Assign button ──
                  FilledButton.icon(
                    onPressed: () => _openAssignWorkout(member),
                    icon: const Icon(Icons.edit_calendar, size: 16),
                    label: const Text('Plan'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Progress bar ──
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No members assigned to you yet.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask your gym owner to assign members to you.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}