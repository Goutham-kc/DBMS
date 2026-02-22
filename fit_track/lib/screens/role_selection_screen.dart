import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'owner_dashboard.dart';
import 'member_dashboard.dart';
import 'trainer_dashboard.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();
    final supabase = Supabase.instance.client;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Your Role"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _roleCard(
            "Gym Owner",
            "Create and manage your own gym",
            Icons.business,
            () async {
              final user = supabase.auth.currentUser;
              if (user == null) return;

              _showLoading(context);

              try {
                final profile = await supabase
                    .from('profiles')
                    .select('gym_id')
                    .eq('id', user.id)
                    .single();

                if (profile['gym_id'] != null) {
                  await supabase.from('profiles').update({
                    'app_role': 'owner',
                    'role': 'owner'
                  }).eq('id', user.id);
                } else {
                  await service.setupAsOwner(user.id);
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const OwnerDashboard()),
                    (route) => false,
                  );
                }
              } catch (_) {
                if (context.mounted) Navigator.pop(context);
                _showError(context, "Owner setup failed.");
              }
            },
          ),
          const SizedBox(height: 20),
          _roleCard(
            "Trainer",
            "Join a gym to manage clients",
            Icons.fitness_center,
            () => _showJoinDialog(context, "trainer"),
          ),
          _roleCard(
            "Member",
            "Join a gym to track workouts",
            Icons.person,
            () => _showJoinDialog(context, "member"),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog(BuildContext context, String role) {
    final controller = TextEditingController();
    final service = SupabaseService();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("Join as ${role.toUpperCase()}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter a valid Gym ID."),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Gym ID",
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final gymId = controller.text.trim();
              if (gymId.isEmpty) return;

              final success =
                  await service.joinGym(gymId: gymId, role: role);

              if (!success) {
                _showError(context,
                    "Invalid Gym ID or update failed.");
                return;
              }

              if (ctx.mounted) Navigator.pop(ctx);

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => role == "trainer"
                      ? const TrainerDashboard()
                      : const MemberDashboard(),
                ),
                (route) => false,
              );
            },
            child: const Text("Join"),
          ),
        ],
      ),
    );
  }

  Widget _roleCard(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(icon, color: Colors.blue),
        ),
        title: Text(title,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }

  void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator()),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}