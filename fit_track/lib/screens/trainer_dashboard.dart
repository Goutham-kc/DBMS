import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'assign_workout_screen.dart';

class TrainerDashboard extends StatefulWidget {
  const TrainerDashboard({super.key});

  @override
  State<TrainerDashboard> createState() =>
      _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  final supabase = Supabase.instance.client;

  // ================= LOGOUT =================

  Future<void> _logout() async {
    final user = supabase.auth.currentUser;

    if (user != null) {
      await supabase
          .from('profiles')
          .update({'role': 'none'})
          .eq('id', user.id);
    }

    await supabase.auth.signOut();

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/', (route) => false);
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final trainer = supabase.auth.currentUser;

    if (trainer == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trainer Hub"),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),

      // ================= STREAM =================

      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('profiles')
            .stream(primaryKey: ['id']),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator());
          }

          // ✅ FILTER LOCALLY
          final members = snapshot.data!
              .where((profile) =>
                  profile['trainer_id'] ==
                      trainer.id &&
                  profile['membership_role'] ==
                      'member')
              .toList();

          if (members.isEmpty) {
            return const Center(
              child:
                  Text("No members assigned to you."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title:
                      Text(member['email'] ?? "Member"),
                  subtitle: const Text(
                      "Tap to assign workout"),
                  trailing:
                      const Icon(Icons.arrow_forward),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AssignWorkoutScreen(
                          memberId: member['id'],
                          gymId: member['gym_id'],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}