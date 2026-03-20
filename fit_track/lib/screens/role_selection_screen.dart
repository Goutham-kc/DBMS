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
    return Scaffold(
      appBar: AppBar(title: const Text('Select Your Role'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _roleCard(context, 'Gym Owner', 'Create and manage your own gym',
              Icons.business, Colors.purple, () => _handleOwner(context)),
          const SizedBox(height: 16),
          _roleCard(context, 'Trainer', 'Join a gym using the Trainer Code',
              Icons.fitness_center, Colors.orange,
              () => _showJoinDialog(context, 'trainer')),
          const SizedBox(height: 16),
          _roleCard(context, 'Member', 'Join a gym using the Member Code',
              Icons.person, Colors.blue,
              () => _showJoinDialog(context, 'member')),
          const SizedBox(height: 32),
          // Info box explaining the two codes
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    SizedBox(width: 6),
                    Text('About Join Codes',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gyms have two separate codes:\n'
                  '• Trainer Code — given to trainers only\n'
                  '• Member Code  — given to members only\n\n'
                  'Using the wrong code will show an error.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // OWNER
  // ──────────────────────────────────────────────────────────────

  Future<void> _handleOwner(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final service = SupabaseService();
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
          'role': 'owner',
          'membership_role': 'owner',
        }).eq('id', user.id);
      } else {
        await service.setupAsOwner(user.id);
      }

      if (!context.mounted) return;
      Navigator.pop(context);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OwnerDashboard()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _showError(context, 'Owner setup failed: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // TRAINER / MEMBER — join dialog
  // ──────────────────────────────────────────────────────────────

  void _showJoinDialog(BuildContext context, String role) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _JoinDialog(
        role: role,
        onJoin: (code) async {
          final service = SupabaseService();
          final result = await service.joinGym(code: code, role: role);

          if (!dialogContext.mounted) return;

          switch (result) {
            case JoinResult.success:
              Navigator.pop(dialogContext);
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => role == 'trainer'
                      ? const TrainerDashboard()
                      : const MemberDashboard(),
                ),
                (route) => false,
              );
            case JoinResult.wrongCode:
              // Code exists but belongs to the OTHER role
              final otherRole = role == 'trainer' ? 'Member' : 'Trainer';
              _showError(
                dialogContext,
                'That looks like a $otherRole Code, not a '
                '${role == 'trainer' ? 'Trainer' : 'Member'} Code. '
                'Ask your gym owner for the correct one.',
              );
            case JoinResult.notFound:
              _showError(dialogContext,
                  'Code not found. Double-check and try again.');
            case JoinResult.error:
              _showError(dialogContext, 'Something went wrong. Please retry.');
          }
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────

  Widget _roleCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                radius: 26,
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// JOIN DIALOG — extracted StatefulWidget to own its loading state
// ──────────────────────────────────────────────────────────────────────────

class _JoinDialog extends StatefulWidget {
  final String role;
  final Future<void> Function(String code) onJoin;

  const _JoinDialog({required this.role, required this.onJoin});

  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _codeLabel =>
      widget.role == 'trainer' ? 'Trainer Code' : 'Member Code';

  String get _hint =>
      widget.role == 'trainer' ? 'e.g. TRXK9Z2A' : 'e.g. MBR7Y4QP';

  Color get _color =>
      widget.role == 'trainer' ? Colors.orange : Colors.blue;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.role == 'trainer' ? Icons.fitness_center : Icons.person,
            color: _color,
          ),
          const SizedBox(width: 8),
          Text('Join as ${widget.role[0].toUpperCase()}${widget.role.substring(1)}'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the $_codeLabel provided by your gym owner.',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: _codeLabel,
              hintText: _hint,
              prefixIcon: Icon(Icons.vpn_key, color: _color),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _color,
              foregroundColor: Colors.white),
          onPressed: _loading
              ? null
              : () async {
                  final code = _controller.text.trim();
                  if (code.isEmpty) return;
                  setState(() => _loading = true);
                  await widget.onJoin(code);
                  if (mounted) setState(() => _loading = false);
                },
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Join'),
        ),
      ],
    );
  }
}