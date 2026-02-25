import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssignWorkoutScreen extends StatefulWidget {
  final String memberId;
  final String gymId;

  const AssignWorkoutScreen({
    super.key,
    required this.memberId,
    required this.gymId,
  });

  @override
  State<AssignWorkoutScreen> createState() =>
      _AssignWorkoutScreenState();
}

class _AssignWorkoutScreenState
    extends State<AssignWorkoutScreen> {
  final supabase = Supabase.instance.client;

  final List<String> days = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  final Map<String, TextEditingController> controllers =
      {};

  @override
  void initState() {
    super.initState();

    for (var day in days) {
      controllers[day] = TextEditingController();
    }

    _loadExistingWorkout();
  }

  // ================= LOAD EXISTING =================

  Future<void> _loadExistingWorkout() async {
    final data = await supabase
        .from('workouts')
        .select()
        .eq('member_id', widget.memberId);

    for (var w in data) {
      controllers[w['day_of_week']]?.text =
          w['workout'];
    }

    setState(() {});
  }

  // ================= SAVE =================

  Future<void> _saveWorkout() async {
    final trainer =
        supabase.auth.currentUser;

    for (var day in days) {
      final workout =
          controllers[day]!.text.trim();

      if (workout.isEmpty) continue;

      await supabase.from('workouts').upsert({
        "member_id": widget.memberId,
        "trainer_id": trainer!.id,
        "gym_id": widget.gymId,
        "day_of_week": day,
        "workout": workout,
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Workout Assigned")),
      );

      Navigator.pop(context);
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text("Assign Workout")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...days.map(
            (day) => Padding(
              padding:
                  const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: controllers[day],
                decoration: InputDecoration(
                  labelText: day,
                  border:
                      const OutlineInputBorder(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _saveWorkout,
            child: const Text("Save Workout"),
          ),
        ],
      ),
    );
  }
}