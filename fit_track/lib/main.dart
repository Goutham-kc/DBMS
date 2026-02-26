import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';

void main() async {
  // 1. Ensure Flutter is ready
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Supabase
  // Note: Replace with your actual project details from Supabase Dashboard
  await Supabase.initialize(
    url: 'https://edywumickfnjctymacpn.supabase.co',
    anonKey: 'sb_publishable_KBDvkiGp1wOHt1XCUtGfsQ_XB851AON',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // Secure flow for mobile/web
    ),
  );

  runApp(const FitTrackApp());
}

class FitTrackApp extends StatelessWidget {
  const FitTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(                                                             
      title: 'Fit-Track DBMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.light,
        ),
      ),
      // Entry point of the application
      home: const LoginScreen(),
    );
  }
}