import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('FirebaseOptions for web is not configured.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'FirebaseOptions are not set up for this platform. Configure Firebase for ${defaultTargetPlatform.name}.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCf-OeR8ZELw8Qk7q8TAhjO2_ZQY-3S3f0',
    appId: '1:723715287873:android:fb8ef99723bda07b5d8fc0',
    messagingSenderId: '723715287873',
    projectId: 'insign-69997',
    storageBucket: 'insign-69997.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA7OQqZZNKaXNIxJlzKWEJXGugd89UlBS8',
    appId: '1:723715287873:ios:6bc355a5313ac2655d8fc0',
    messagingSenderId: '723715287873',
    projectId: 'insign-69997',
    storageBucket: 'insign-69997.firebasestorage.app',
    iosBundleId: 'app.insign',
  );
}
