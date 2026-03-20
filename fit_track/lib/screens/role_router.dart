import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';
import 'owner_dashboard.dart';
import 'trainer_dashboard.dart';
import 'member_dashboard.dart';

/// RoleRouter is the true entry point after app launch.
///
/// FIX: Previously always sent logged-in users to RoleSelectionScreen,
/// forcing role re-selection on every app open. Now it reads the
/// persisted [app_role] from the profile and navigates directly to
/// the correct dashboard. Role selection is only shown when app_role
/// is null / 'none'.
class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, authSnapshot) {
        final session = supabase.auth.currentSession;

        // Not logged in → Login screen
        if (session == null) return const LoginScreen();

        // Logged in → resolve role from DB
        return FutureBuilder<Map<String, dynamic>?>(
          future: supabase
              .from('profiles')
              .select('app_role')
              .eq('id', session.user.id)
              .maybeSingle(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (profileSnapshot.hasError) {
              return Scaffold(
                body: Center(
                    child: Text('Profile error: ${profileSnapshot.error}')),
              );
            }

            final role =
                profileSnapshot.data?['app_role'] as String? ?? 'none';

            // Route based on persisted role
            switch (role) {
              case 'owner':
                return const OwnerDashboard();
              case 'trainer':
                return const TrainerDashboard();
              case 'member':
                return const MemberDashboard();
              default:
                // No role set yet → let user pick
                return const RoleSelectionScreen();
            }
          },
        );
      },
    );
  }
}