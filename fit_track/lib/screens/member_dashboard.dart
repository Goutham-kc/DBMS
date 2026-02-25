import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemberDashboard extends StatefulWidget {
  const MemberDashboard({super.key});

  @override
  State<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends State<MemberDashboard> {
  final supabase = Supabase.instance.client;

  late final Stream<List<Map<String, dynamic>>> _profileStream;

  @override
  void initState() {
    super.initState();

    final user = supabase.auth.currentUser;

    // Stream current logged-in profile
    _profileStream = supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', user!.id);
  }

  // ================= LOGOUT =================

  Future<void> _logout() async {
    try {
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
          context,
          '/',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Logout Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Member Hub"),
        backgroundColor: Colors.blue.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: _logout,
          )
        ],
      ),

      // -------- PROFILE STREAM --------
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _profileStream,
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator());
          }

          if (!profileSnapshot.hasData ||
              profileSnapshot.data!.isEmpty) {
            return const Center(
                child: Text("Profile not found."));
          }

          final profile = profileSnapshot.data!.first;
          final String? gymId = profile['gym_id'];

          if (gymId == null) {
            return const Center(
              child: Text("You are not assigned to a gym yet."),
            );
          }

          return _buildMembersList(gymId);
        },
      ),
    );
  }

  // ================= MEMBERS STREAM =================

  Widget _buildMembersList(String gymId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('gym_id', gymId)
          .eq('role', 'member'),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text("No members found in this gym."),
          );
        }

        final members = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Gym Members (${members.length})",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),
              const Divider(),

              Expanded(
                child: ListView.separated(
                  itemCount: members.length,
                  separatorBuilder: (_, __) =>
                      const Divider(),
                  itemBuilder: (context, index) {
                    final member = members[index];

                    final name =
                        member['full_name'] ??
                            'Unnamed Member';

                    final avatar =
                        member['avatar_url'];

                    return ListTile(
                      leading: avatar != null &&
                              avatar.isNotEmpty
                          ? CircleAvatar(
                              backgroundImage:
                                  NetworkImage(
                                      avatar),
                            )
                          : CircleAvatar(
                              child: Text(
                                name.isNotEmpty
                                    ? name[0]
                                    : "?",
                              ),
                            ),
                      title: Text(name),
                      subtitle:
                          Text(member['role'] ?? ''),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}