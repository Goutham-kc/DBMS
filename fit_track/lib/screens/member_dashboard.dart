import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MemberDashboard extends StatelessWidget {
  final String userName;
  final String userEmail;

  const MemberDashboard({super.key, required this.userName, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("FIT-TRACK"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            }
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Welcome back, $userName!", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Eat. Sleep. Gym. Repeat.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            
            _buildStatusCard("Membership", "Active - 15 Days Left", Icons.timer, Colors.orange),
            _buildStatusCard("Goal", "Muscle Gain", Icons.track_changes, Colors.green),
            
            const SizedBox(height: 30),
            const Text("Your Assigned Workouts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Card(
              child: ListTile(
                leading: Icon(Icons.fitness_center),
                title: Text("Full Body Routine"),
                subtitle: Text("Targets: Chest, Back, Legs"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        leading: Icon(icon, color: color, size: 40),
        title: Text(title),
        subtitle: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}