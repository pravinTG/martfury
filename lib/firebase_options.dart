// File generated using FlutterFire CLI.
// For more information, see: https://firebase.flutter.dev/docs/cli

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: 'YOUR_WEB_APP_ID',
    messagingSenderId: '253730405721',
    projectId: 'goodiesworld-cae77',
    authDomain: 'goodiesworld-cae77.firebaseapp.com',
    storageBucket: 'goodiesworld-cae77.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAvBPJQouMdXGZ9ZQyc4q7DgQmVV0Haw04',
    appId: '1:253730405721:android:b0be849449cb396c6e6048',
    messagingSenderId: '253730405721',
    projectId: 'goodiesworld-cae77',
    storageBucket: 'goodiesworld-cae77.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: '253730405721',
    projectId: 'goodiesworld-cae77',
    storageBucket: 'goodiesworld-cae77.firebasestorage.app',
    iosBundleId: 'in.techgigs.goodiesworld',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: '253730405721',
    projectId: 'goodiesworld-cae77',
    storageBucket: 'goodiesworld-cae77.firebasestorage.app',
    iosBundleId: 'in.techgigs.goodiesworld',
  );
}

