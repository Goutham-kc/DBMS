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
    
    // Check SQL tables for the logged-in email
    bool isOwner = await dbHelper.isOwner(user.email!);
    
    if (!mounted) return;

    if (isOwner) {
      // If team member (Goutham, Vaishnav, etc.), go to Trainer/Admin portal
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const TrainerPortal())
      );
    } else {
      // If regular user, go to Member dashboard
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => MemberDashboard(
          userName: user.displayName ?? "User", 
          userEmail: user.email!
        ))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}