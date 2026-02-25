import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrainerDashboard extends StatefulWidget {
  const TrainerDashboard({super.key});

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  final supabase = Supabase.instance.client;

  Future<void> _logout() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // 1. Update DB role
        await supabase
            .from('profiles')
            .update({'role': 'none'})
            .eq('id', user.id);
      }
      
      // 2. Sign out
      await supabase.auth.signOut();
      
      if (mounted) {
        // 3. WIPE THE STACK: Ensures a clean slate
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Logout Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    // 1. SAFE GUARD: If there's no user, show a simple loading screen instead of crashing
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trainer Hub"),
        backgroundColor: Colors.orange.shade800,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: supabase
            .from('profiles')
            .select('gym_id')
            .eq('id', user.id) // Removed the '!' for safety
            .single(),
        builder: (context, snapshot) {
          // 2. HANDLE ERROR STATE (e.g., Network issues or record not found)
          if (snapshot.hasError) {
            return Center(child: Text("Error fetching gym: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          final String? gymId = data?['gym_id'];
          final String gymName = "Gym";

          // 3. GYM ID CHECK: If trainer hasn't joined a gym yet
          if (gymId == null) {
            return const Center(child: Text("You are not assigned to a gym yet."));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Coaching at $gymName", 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Divider(),
                const SizedBox(height: 10),
                const Text("Active Members", 
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 10),

                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: supabase
                        .from('profiles')
                        .stream(primaryKey: ['id'])
                        .eq('gym_id', gymId)
                        .order('email'),
                    builder: (context, memberSnapshot) {
                      if (memberSnapshot.hasError) {
                        return Center(child: Text("Stream Error: ${memberSnapshot.error}"));
                      }
                      
                      if (!memberSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final members = memberSnapshot.data!
                          .where((m) => m['role'] == 'member')
                          .toList();

                      if (members.isEmpty) {
                        return const Center(
                          child: Text("No members in this gym yet."),
                        );
                      }

                      return ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(member['email'] ?? "Member"),
                              subtitle: const Text("Status: Active"),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Viewing ${member['email']}")),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}