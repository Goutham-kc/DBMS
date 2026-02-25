import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemberDashboard extends StatefulWidget {
  const MemberDashboard({super.key});

  @override
  State<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends State<MemberDashboard> {
  final supabase = Supabase.instance.client;

  Future<void> _logout() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // Soft reset role to 'none' but keep gym_id for history
        await supabase
            .from('profiles')
            .update({'role': 'none'})
            .eq('id', user.id);
      }
      
      await supabase.auth.signOut();
      
      if (mounted) {
        // Wipe the navigation stack to ensure they land on the Auth Router
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Logout Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    // 1. SAFE GUARD: Ensure user exists before trying to fetch data
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Member Hub"),
        backgroundColor: Colors.blue.shade800, // Blue theme for members
        actions: [
          IconButton(
            icon: const Icon(Icons.logout), 
            onPressed: _logout,
            tooltip: "Logout & Switch Role",
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: supabase
            .from('profiles')
            .select('gym_id, gyms(gym_name)')
            .eq('id', user.id)
            .single(),
        builder: (context, snapshot) {
          // 2. HANDLE ERROR STATE
          if (snapshot.hasError) {
            return Center(child: Text("Error fetching gym: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          final String? gymId = data?['gym_id'];
          final String gymName = data?['gyms']?['gym_name'] ?? "Your Gym";

          // 3. GYM ID CHECK
          if (gymId == null) {
            return const Center(child: Text("You are not assigned to a gym yet."));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Training at $gymName", 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Divider(),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    "Welcome back! Check your workout plan or book a session with your trainer.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                // Add more member-specific UI components here later
              ],
            ),
          );
        },
      ),
    );
  }
}