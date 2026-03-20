import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  final _supabase = Supabase.instance.client;
  final _service = SupabaseService();
  late final Stream<List<Map<String, dynamic>>> _gymStream;

  @override
  void initState() {
    super.initState();
    final user = _supabase.auth.currentUser!;
    _gymStream = _supabase
        .from('gyms')
        .stream(primaryKey: ['id'])
        .eq('owner_id', user.id);
  }

  // ──────────────────────────────────────────────────────────────
  // LOGOUT
  // ──────────────────────────────────────────────────────────────

  Future<void> _handleLogout() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('profiles').update({
          'role': 'none',
          'app_role': 'none',
        }).eq('id', user.id);
      }
      await _supabase.auth.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Logout Error: $e')));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────
  // EDIT GYM NAME
  // ──────────────────────────────────────────────────────────────

  void _showEditGymNameDialog(String gymId, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Gym Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Gym Name',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              final ok = await _service.updateGymName(
                  gymId: gymId, newName: newName);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      ok ? 'Gym name updated!' : 'Failed to update name.'),
                  backgroundColor: ok ? Colors.green : Colors.red,
                ));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // MEMBERS MANAGEMENT SHEET
  // ──────────────────────────────────────────────────────────────

  void _showMembersSheet(String gymId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _MembersManagementSheet(gymId: gymId, service: _service),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        actions: [
          IconButton(
              icon: const Icon(Icons.logout), onPressed: _handleLogout),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _gymStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Gym record not found.'));
          }

          final gymData = snapshot.data!.first;
          final gymName = gymData['gym_name'] as String? ?? 'Unnamed Gym';
          final gymId = gymData['id']?.toString() ?? '';
          final trainerCode =
              gymData['trainer_code'] as String? ?? '—';
          final memberCode =
              gymData['member_code'] as String? ?? '—';

          if (gymId.isEmpty) {
            return const Center(
                child: Text('Gym ID missing. Contact support.'));
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildGymCard(
                  gymId, gymName, trainerCode, memberCode),
              const SizedBox(height: 28),
              const Text('Management',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _actionTile(Icons.group, 'Manage Staff & Members',
                  () => _showMembersSheet(gymId)),
              _actionTile(
                  Icons.drive_file_rename_outline,
                  'Edit Gym Name',
                  () => _showEditGymNameDialog(gymId, gymName)),
              _actionTile(Icons.bar_chart, 'Gym Analytics', () {}),
            ],
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // WIDGETS
  // ──────────────────────────────────────────────────────────────

  Widget _buildGymCard(String id, String name,
      String trainerCode, String memberCode) {
    return Card(
      elevation: 4,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gym name row
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const Icon(Icons.business, color: Colors.blue),
              ],
            ),

            const Divider(height: 24),

            // Trainer code
            _codeRow(
              label: 'Trainer Code',
              code: trainerCode,
              color: Colors.orange,
              icon: Icons.fitness_center,
              hint: 'Share only with trainers',
            ),

            const SizedBox(height: 12),

            // Member code
            _codeRow(
              label: 'Member Code',
              code: memberCode,
              color: Colors.blue,
              icon: Icons.person,
              hint: 'Share only with members',
            ),
          ],
        ),
      ),
    );
  }

  Widget _codeRow({
    required String label,
    required String code,
    required Color color,
    required IconData icon,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                SelectableText(
                  code,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 2),
                ),
                Text(hint,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          // Copy button
          IconButton(
            icon: Icon(Icons.copy, color: color, size: 18),
            tooltip: 'Copy $label',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied!'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: color,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, VoidCallback tap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: tap,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// MEMBERS MANAGEMENT SHEET
// ══════════════════════════════════════════════════════════════════════════

class _MembersManagementSheet extends StatelessWidget {
  final String gymId;
  final SupabaseService service;

  const _MembersManagementSheet(
      {required this.gymId, required this.service});

  Future<void> _assignTrainer(
    BuildContext context,
    String memberId,
    String memberEmail,
    List<Map<String, dynamic>> trainersWithCount,
    String? currentTrainerId,
  ) async {
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Assign trainer for\n$memberEmail',
            style: const TextStyle(fontSize: 15)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '__unassign__'),
            child: const Row(
              children: [
                Icon(Icons.person_off, color: Colors.red, size: 20),
                SizedBox(width: 10),
                Text('Unassign trainer',
                    style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          const Divider(),
          ...trainersWithCount.map((t) {
            final isCurrent = t['id'] == currentTrainerId;
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t['id'] as String),
              child: Row(
                children: [
                  Icon(
                    isCurrent ? Icons.check_circle : Icons.person,
                    color: isCurrent ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t['email'] as String? ?? 'Trainer',
                      style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${t['_memberCount']} members',
                      style: TextStyle(
                          fontSize: 11, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    if (result == null) return;
    final newTrainerId = result == '__unassign__' ? null : result;

    final ok = await service.assignTrainerToMember(
        memberId: memberId, trainerId: newTrainerId);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? newTrainerId == null
                ? 'Trainer unassigned.'
                : 'Trainer assigned!'
            : 'Failed to update trainer.'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Staff & Member Management',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase
                  .from('profiles')
                  .stream(primaryKey: ['id'])
                  .eq('gym_id', gymId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                final all = snapshot.data!;
                final trainers = all
                    .where((p) => p['membership_role'] == 'trainer')
                    .toList();
                final members = all
                    .where((p) => p['membership_role'] == 'member')
                    .toList();

                // Count members per trainer
                final counts = <String, int>{
                  for (final t in trainers) t['id'] as String: 0
                };
                for (final m in members) {
                  final tid = m['trainer_id'] as String?;
                  if (tid != null && counts.containsKey(tid)) {
                    counts[tid] = counts[tid]! + 1;
                  }
                }
                final trainersWithCount = trainers
                    .map((t) => {
                          ...t,
                          '_memberCount': counts[t['id']] ?? 0,
                        })
                    .toList();

                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── TRAINERS ──────────────────────────────
                    _sectionHeader('Trainers (${trainers.length})',
                        Icons.fitness_center, Colors.orange),
                    if (trainers.isEmpty)
                      _emptyHint('No trainers yet.'),
                    ...trainers.map((t) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.shade100,
                              child: const Icon(Icons.star,
                                  color: Colors.orange, size: 18),
                            ),
                            title: Text(
                                t['email'] as String? ?? 'Trainer'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${counts[t['id']] ?? 0} members',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        )),

                    const Divider(height: 32),

                    // ── MEMBERS ───────────────────────────────
                    _sectionHeader('Members (${members.length})',
                        Icons.people, Colors.blue),
                    if (members.isEmpty)
                      _emptyHint('No members yet.'),
                    ...members.map((m) {
                      final currentTrainerId =
                          m['trainer_id'] as String?;
                      final assignedTrainer =
                          trainersWithCount.firstWhere(
                        (t) => t['id'] == currentTrainerId,
                        orElse: () => {},
                      );
                      final trainerEmail =
                          assignedTrainer['email'] as String?;
                      final hasTrainer = trainerEmail != null;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              (m['email'] as String? ?? 'M')[0]
                                  .toUpperCase(),
                              style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                              m['email'] as String? ?? 'Member'),
                          subtitle: Row(
                            children: [
                              Icon(
                                hasTrainer
                                    ? Icons.check_circle
                                    : Icons.warning_amber,
                                size: 13,
                                color: hasTrainer
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  hasTrainer
                                      ? trainerEmail
                                      : 'No trainer assigned',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: hasTrainer
                                          ? Colors.black87
                                          : Colors.orange),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.swap_horiz,
                                color: Colors.blue.shade600),
                            tooltip: 'Assign / Reassign Trainer',
                            onPressed: () => _assignTrainer(
                              context,
                              m['id'] as String,
                              m['email'] as String? ?? 'Member',
                              trainersWithCount,
                              currentTrainerId,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 16)),
        ],
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text,
          style: const TextStyle(
              fontStyle: FontStyle.italic, color: Colors.grey)),
    );
  }
}