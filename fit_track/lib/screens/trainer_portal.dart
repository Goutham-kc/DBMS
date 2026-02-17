import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrainerPortal extends StatelessWidget {
  const TrainerPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trainer Portal"),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // Returns to login screen
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Manage Your Members",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _buildMemberTile("Vaishnav V Bishoy", "TKM24CS141"),
                  _buildMemberTile("Navyasree A J", "TKM24CS099"),
                  _buildMemberTile("Akash AS", "TKM24CS021"),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {}, 
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMemberTile(String name, String id) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person),
        title: Text(name),
        subtitle: Text("ID: $id"),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}