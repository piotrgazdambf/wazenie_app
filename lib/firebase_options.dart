// PLACEHOLDER — wygeneruj ten plik komendą:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=TWOJ_FIREBASE_PROJECT_ID
//
// Plik zostanie automatycznie nadpisany poprawnymi wartościami.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD5W-xlWcczg7vKgy6_ZgcipYKw3w4nmac',
    appId: '1:70138421421:web:fa798be6f39bd353eb6624',
    messagingSenderId: '70138421421',
    projectId: 'mbf-przyjecia',
    authDomain: 'mbf-przyjecia.firebaseapp.com',
    storageBucket: 'mbf-przyjecia.firebasestorage.app',
    measurementId: 'G-TG0W58D7PD',
  );

  // TODO: zastąp wartościami z Firebase Console

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyANlymu3eDlOiEjC1GYITCTmN66rsd4vvw',
    appId: '1:70138421421:android:c977e0d1365af7b5eb6624',
    messagingSenderId: '70138421421',
    projectId: 'mbf-przyjecia',
    storageBucket: 'mbf-przyjecia.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCGqbyJYB7GlPUMEIhq--t_7jFA0eAlhkQ',
    appId: '1:70138421421:ios:a4422121caba1982eb6624',
    messagingSenderId: '70138421421',
    projectId: 'mbf-przyjecia',
    storageBucket: 'mbf-przyjecia.firebasestorage.app',
    iosBundleId: 'pl.gazda.wazenie.wazenieapp',
  );

}