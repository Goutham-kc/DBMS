import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'role_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Listen for Auth changes (helps if the redirect happens automatically)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => RoleRouter()),
        );
      }
    });
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      
      // SQL/Supabase OAuth Sign-In
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        // The redirectTo must match your Supabase URL Configuration
        redirectTo: 'fit-track://login-callback',
      );

    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Auth Error: ${e.message}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF448AFF), Color(0xFF2196F3)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center, size: 100, color: Colors.white),
            const SizedBox(height: 20),
            const Text(
              "FIT-TRACK",
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const Text(
              "DBMS RELATIONAL EDITION",
              style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1),
            ),
            const SizedBox(height: 60),
            _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                    onPressed: _handleGoogleSignIn,
                    icon: const Icon(Icons.login),
                    label: const Text(
                      "Sign in with Google",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}