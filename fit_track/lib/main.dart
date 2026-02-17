import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';

void main() async {
  // Ensures Flutter framework is ready for platform-level communication
  WidgetsFlutterBinding.ensureInitialized();

  // FIX: Check if Firebase is already initialized to prevent [core/duplicate-app]
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Firebase app already initialized, ignore
  }

  runApp(const FitTrackApp());
}

class FitTrackApp extends StatelessWidget {
  const FitTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fit-Track',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // Starts the app at the Login Screen [cite: 1, 2, 4, 11, 16]
      home: const LoginScreen(),
    );
  }
}