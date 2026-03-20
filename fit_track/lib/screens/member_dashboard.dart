import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemberDashboard extends StatefulWidget {
  const MemberDashboard({super.key});

  @override
  State<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends State<MemberDashboard> {
  final _supabase = Supabase.instance.client;

  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  // ── All state in one place ─────────────────────────────────────
  bool _loading = true;
  bool _workoutSyncing = false;
  String? _gymId;
  String? _gymName;
  String? _trainerId;
  String? _trainerEmail;
  Map<String, String?> _workoutPlan = {
    for (final d in _days) d: null
  };

  StreamSubscription<List<Map<String, dynamic>>>? _profileSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  // MAIN LOAD — fetches everything in one go, then setState once
  // ──────────────────────────────────────────────────────────────

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Cancel any existing subscription before reloading
    await _profileSub?.cancel();
    _profileSub = null;

    // Temp variables — only written to state in ONE setState at the end
    String? gymId;
    String? gymName;
    String? trainerId;
    String? trainerEmail;
    Map<String, String?> workoutPlan = {for (final d in _days) d: null};

    try {
      // 1. Profile — get gym_id and trainer_id
      final profile = await _supabase
          .from('profiles')
          .select('gym_id, trainer_id')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        // Profile row doesn't exist yet — nothing to show
        if (mounted) setState(() => _loading = false);
        return;
      }

      gymId     = profile['gym_id']     as String?;
      trainerId = profile['trainer_id'] as String?;

      // 2. Gym name — direct lookup (no join, avoids RLS issues)
      if (gymId != null) {
        final gym = await _supabase
            .from('gyms')
            .select('gym_name')
            .eq('id', gymId)
            .maybeSingle();
        gymName = gym?['gym_name'] as String? ?? 'Unknown Gym';
      }

      // 3. Trainer email
      if (trainerId != null) {
        final trainer = await _supabase
            .from('profiles')
            .select('email')
            .eq('id', trainerId)
            .maybeSingle();
        trainerEmail = trainer?['email'] as String?;
      }

      // 4. Workouts
      if (gymId != null) {
        final rows = await _supabase
            .from('workouts')
            .select('day_of_week, workout')
            .eq('member_id', user.id);

        for (final row in rows) {
          workoutPlan[row['day_of_week'] as String] =
              row['workout'] as String?;
        }
      }
    } catch (e) {
      debugPrint('[MemberDashboard] _load error: $e');
    }

    // ONE setState with all values — no partial renders
    if (mounted) {
      setState(() {
        _gymId        = gymId;
        _gymName      = gymName;
        _trainerId    = trainerId;
        _trainerEmail = trainerEmail;
        _workoutPlan  = workoutPlan;
        _loading      = false;
      });
    }

    // Start watching trainer_id changes AFTER state is set
    _watchTrainer(user.id);
  }

  // ──────────────────────────────────────────────────────────────
  // TRAINER WATCHER — only fires setState when trainer_id changes
  // ──────────────────────────────────────────────────────────────

  void _watchTrainer(String userId) {
    _profileSub = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((rows) async {
          if (!mounted || rows.isEmpty) return;

          final newTrainerId = rows.first['trainer_id'] as String?;

          // Ignore if nothing changed — this kills the glitch loop
          if (newTrainerId == _trainerId) return;

          _trainerId = newTrainerId;

          if (newTrainerId == null) {
            if (mounted) setState(() => _trainerEmail = null);
            return;
          }

          // Fetch new trainer's email
          try {
            final trainer = await _supabase
                .from('profiles')
                .select('email')
                .eq('id', newTrainerId)
                .maybeSingle();

            if (mounted) {
              setState(() {
                _trainerEmail = trainer?['email'] as String?;
              });
            }
          } catch (e) {
            debugPrint('[MemberDashboard] trainer email fetch error: $e');
          }
        });
  }

  // ──────────────────────────────────────────────────────────────
  // WORKOUT SYNC
  // ──────────────────────────────────────────────────────────────

  Future<void> _syncWorkouts() async {
    final user = _supabase.auth.currentUser;
    if (user == null || _gymId == null) return;

    setState(() => _workoutSyncing = true);

    try {
      final rows = await _supabase
          .from('workouts')
          .select('day_of_week, workout')
          .eq('member_id', user.id);

      final plan = <String, String?>{for (final d in _days) d: null};
      for (final row in rows) {
        plan[row['day_of_week'] as String] = row['workout'] as String?;
      }

      if (mounted) setState(() => _workoutPlan = plan);
    } catch (e) {
      debugPrint('[MemberDashboard] syncWorkouts error: $e');
    } finally {
      if (mounted) setState(() => _workoutSyncing = false);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // LOGOUT
  // ──────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    try {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Logout Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_gymName ?? 'Member Hub'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _loading = true);
                await _load();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _infoCard(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Your Weekly Plan',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      _workoutSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : TextButton.icon(
                              onPressed: _syncWorkouts,
                              icon: const Icon(Icons.sync, size: 16),
                              label: const Text('Sync',
                                  style: TextStyle(fontSize: 12)),
                            ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_gymId == null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(
                          children: [
                            Icon(Icons.hourglass_empty,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text(
                              'Not assigned to a gym yet.\nAsk your gym owner for a Member Code.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._days.map(_dayCard),
                ],
              ),
            ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // WIDGETS
  // ──────────────────────────────────────────────────────────────

  Widget _infoCard() {
    final hasTrainer = _trainerId != null;
    final assignedDays = _workoutPlan.values
        .where((v) => v != null && v.isNotEmpty)
        .length;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gym name
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _gymName ?? '—',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // Trainer
            Row(
              children: [
                Icon(
                  hasTrainer ? Icons.person : Icons.person_off,
                  color: hasTrainer ? Colors.orange : Colors.grey,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasTrainer
                        ? 'Trainer: ${_trainerEmail ?? '...'}'
                        : 'No trainer assigned yet',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasTrainer ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$assignedDays / 7 days planned',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  assignedDays == 7
                      ? '💪 Full week!'
                      : assignedDays == 0
                          ? 'Waiting for trainer…'
                          : '${7 - assignedDays} day${7 - assignedDays == 1 ? '' : 's'} remaining',
                  style: TextStyle(
                    color:
                        assignedDays == 7 ? Colors.green : Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: assignedDays / 7,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                color: assignedDays == 7
                    ? Colors.green
                    : Colors.blue.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCard(String day) {
    final workout = _workoutPlan[day];
    final hasWorkout = workout != null && workout.isNotEmpty;
    final today = _days[DateTime.now().weekday - 1];
    final isToday = day == today;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isToday ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isToday
            ? BorderSide(color: Colors.blue.shade600, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day.substring(0, 3).toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isToday
                          ? Colors.blue.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('TODAY',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey.shade200,
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            Expanded(
              child: hasWorkout
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.fitness_center,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(workout,
                              style: const TextStyle(fontSize: 14)),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(Icons.hotel,
                            size: 16, color: Colors.grey.shade400),
                        const SizedBox(width: 8),
                        Text('Rest day',
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontStyle: FontStyle.italic)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}