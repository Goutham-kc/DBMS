import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_helper.dart';
import 'member_dashboard.dart';
import 'trainer_portal.dart';

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dbHelper = DatabaseHelper.instance;
    
    bool isOwner = await dbHelper.isOwner(user.email!);
    if (isOwner) {
      _navigate(const TrainerPortal()); 
      return;
    }

    bool isTrainer = await dbHelper.isTrainer(user.email!);
    if (isTrainer) {
      _navigate(const TrainerPortal());
      return;
    }

    _navigate(MemberDashboard(
      userName: user.displayName ?? "User", 
      userEmail: user.email!
    ));
  }

  void _navigate(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (context) => screen)
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            const Text("Syncing with Fit-Track Database..."),
          ],
        ),
      ),
    );
  }
}