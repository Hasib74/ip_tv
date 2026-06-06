import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBJdRhUmzzODG3Fui4MyZOzcARJWbk-eEk',
    appId: '1:781909343868:android:88cbcbc63c0a9e060953f9',
    messagingSenderId: '781909343868',
    projectId: 'iptv-e14c0',
    storageBucket: 'iptv-e14c0.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAylZ2Ga2tCu7L5t33c1Sy_ir4pOvtA_TA',
    appId: '1:781909343868:ios:e38e2550b20e7ea00953f9',
    messagingSenderId: '781909343868',
    projectId: 'iptv-e14c0',
    storageBucket: 'iptv-e14c0.firebasestorage.app',
    iosBundleId: 'com.app.ipTv',
  );
}
