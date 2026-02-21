import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured yet.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  // Values mapped directly from your new google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCaWFIl24E3qJlMaCO_j0Ij_LjB0EJpjL8',
    appId: '1:877108633393:android:8b1cd9cc460d3313ce1a10',
    messagingSenderId: '877108633393',
    projectId: 'fit-track-21730',
    storageBucket: 'fit-track-21730.firebasestorage.app',
  );
}