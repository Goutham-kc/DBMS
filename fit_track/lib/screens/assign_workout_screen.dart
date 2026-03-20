import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssignWorkoutScreen extends StatefulWidget {
  final String memberId;
  final String memberEmail;
  final String gymId;

  const AssignWorkoutScreen({
    super.key,
    required this.memberId,
    required this.memberEmail,
    required this.gymId,
  });

  @override
  State<AssignWorkoutScreen> createState() =>
      _AssignWorkoutScreenState();
}

class _AssignWorkoutScreenState extends State<AssignWorkoutScreen> {
  final _supabase = Supabase.instance.client;

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final day in _days) {
      _controllers[day] = TextEditingController();
    }
    _loadExistingWorkout();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  // LOAD
  // ──────────────────────────────────────────────────────────────

  Future<void> _loadExistingWorkout() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _supabase
          .from('workouts')
          .select()
          .eq('member_id', widget.memberId);

      for (final w in data) {
        _controllers[w['day_of_week'] as String]?.text =
            (w['workout'] as String? ?? '');
      }
    } catch (e) {
      // FIX: Surface load errors to the user instead of silently failing.
      setState(() => _error = 'Failed to load workouts: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // SAVE
  // ──────────────────────────────────────────────────────────────

  Future<void> _saveWorkout() async {
    // FIX: Capture user reference once; don't rely on repeated auth
    // calls that could return null mid-operation.
    final trainer = _supabase.auth.currentUser;
    if (trainer == null) return;

    setState(() => _saving = true);

    try {
      for (final day in _days) {
        final workout = _controllers[day]!.text.trim();

        if (workout.isEmpty) {
          // FIX: If the field was cleared, DELETE the existing row so
          // old data doesn't silently persist in the database.
          await _supabase
              .from('workouts')
              .delete()
              .eq('member_id', widget.memberId)
              .eq('day_of_week', day);
        } else {
          // FIX: Specify onConflict so Supabase knows which columns
          // to use for conflict resolution. Without this, upsert can
          // insert duplicates instead of updating.
          // Ensure your 'workouts' table has a UNIQUE constraint on
          // (member_id, day_of_week).
          await _supabase.from('workouts').upsert(
            {
              'member_id': widget.memberId,
              'trainer_id': trainer.id,
              'gym_id': widget.gymId,
              'day_of_week': day,
              'workout': workout,
            },
            onConflict: 'member_id,day_of_week',
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // return true = did save
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Workout for ${widget.memberEmail}'),
        backgroundColor: Colors.orange,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadExistingWorkout,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Day cards ──
                    ..._days.map((day) => _dayCard(day)),

                    const SizedBox(height: 16),

                    // ── Save button ──
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _saveWorkout,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving…' : 'Save Workout'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _dayCard(String day) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: TextField(
          controller: _controllers[day],
          maxLines: null,
          decoration: InputDecoration(
            labelText: day,
            hintText: 'e.g. Chest press 3×10, Squats 4×8',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.fitness_center, size: 20),
          ),
        ),
      ),
    );
  }
}