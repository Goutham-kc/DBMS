import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  final supabase = Supabase.instance.client;
  final service = SupabaseService();
  late final Stream<List<Map<String, dynamic>>> _gymStream;

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    _gymStream = supabase
        .from('gyms')
        .stream(primaryKey: ['id'])
        .eq('owner_id', user!.id);
  }

  Future<void> _handleLogout() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.from('profiles').update({'role': 'none'}).eq('id', user.id);
      }
      await supabase.auth.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Logout Error: $e")));
      }
    }
  }

  // --- TRAINER ASSIGNMENT LOGIC ---

  void _assignTrainer(String memberId, String trainerId) async {
    try {
      await supabase
          .from('profiles')
          .update({'trainer_id': trainerId})
          .eq('id', memberId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Trainer assigned successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

void _showMembersDialog(String gymId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Staff & Member Management"),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase.from('profiles').stream(primaryKey: ['id']).eq('gym_id', gymId),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final all = snapshot.data!;
              final trainers = all.where((p) => p['membership_role'] == 'trainer').toList();
              final members =all.where((p) => p['membership_role'] == 'member').toList();  

              return ListView(
                children: [
                  _sectionHeader("Trainers (${trainers.length})", Icons.fitness_center, Colors.orange),
                  if (trainers.isEmpty) 
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("No trainers available.", style: TextStyle(fontStyle: FontStyle.italic)),
                    ),
                  ...trainers.map((t) => ListTile(
                    title: Text(t['email'] ?? "Trainer"),
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange, 
                      child: Icon(Icons.star, color: Colors.white, size: 16)
                    ),
                  )),
                  
                  const Divider(height: 40),
                  
                  _sectionHeader("Members (${members.length})", Icons.people, Colors.blue),
                  ...members.map((m) {
                    final assignedTrainer = trainers.firstWhere(
                      (t) => t['id'] == m['trainer_id'], 
                      orElse: () => {'email': 'None Assigned'}
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(m['email'] ?? "Member"),
                        subtitle: Text("Assigned: ${assignedTrainer['email']}"),
                        // FIX: Explicitly typed PopupMenuButton and map return
                        trailing: trainers.isEmpty 
                          ? null 
                          : PopupMenuButton<String>(
                              icon: const Icon(Icons.person_add_alt_1, color: Colors.blue),
                              onSelected: (trainerId) => _assignTrainer(m['id'], trainerId),
                              itemBuilder: (context) => trainers.map<PopupMenuEntry<String>>((t) => PopupMenuItem<String>(
                                value: t['id'],
                                child: Text("Assign ${t['email']}"),
                              )).toList(),
                            ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  // --- UI BUILDERS ---

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Owner Dashboard"),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout)],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _gymStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Gym record not found."));

          final gymData = snapshot.data!.first;
          final gymName = gymData['gym_name'] ?? "Unnamed Gym";
          final gymId = gymData['id'];

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGymCard(gymId, gymName),
                const SizedBox(height: 30),
                const Text("Management", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _actionTile(Icons.group, "Manage Staff & Members", () => _showMembersDialog(gymId)),
                _actionTile(Icons.bar_chart, "Gym Analytics", () {}),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGymCard(String id, String name) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Icon(Icons.edit, color: Colors.blue),
              ],
            ),
            const Divider(height: 30),
            const Text("Gym Access ID", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            SelectableText(id, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, VoidCallback tap) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: tap,
      ),
    );
  }
}