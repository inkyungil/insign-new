// lib/data/services/google_auth_service.dart

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

class GoogleAuthService {
  // Google OAuth Client IDs
  static const String _webClientId =
      '723715287873-8jp38k93ksspp7jkeljv4v0jr2eobcb7.apps.googleusercontent.com';
  static const String _androidClientId =
      '723715287873-04874jd2a3533h1nqc76anaj7hu5q0ni.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const [
      'email',
      'profile',
    ],
    clientId: kIsWeb ? _webClientId : null,
    serverClientId: kIsWeb ? null : _webClientId,
  );

  static Stream<GoogleSignInAccount?> get userChanges =>
      _googleSignIn.onCurrentUserChanged;

  static Future<void> ensureInitialized() async {
    if (kIsWeb) {
      try {
        await _googleSignIn.signInSilently();
      } catch (error) {
        // Silent sign-in failures are expected when no previous session exists.
      }
    }
  }

  static Future<GoogleSignInAccount?> signIn() async {
    try {
      if (kIsWeb) {
        final GoogleSignInAccount? current = _googleSignIn.currentUser;
        if (current != null) {
          return current;
        }

        final GoogleSignInAccount? silent = await _googleSignIn.signInSilently();
        if (silent != null) {
          return silent;
        }
      }

      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      return account;
    } catch (error) {
      print('Google Sign-In error: $error');
      return null;
    }
  }

  static Future<String?> getIdToken(
    GoogleSignInAccount account, {
    bool forceRefresh = false,
  }) async {
    try {
      if (kIsWeb) {
        final GoogleSignInTokenData tokens =
            await GoogleSignInPlatform.instance.getTokens(
          email: account.email,
          shouldRecoverAuth: forceRefresh,
        );
        if (tokens.idToken != null && tokens.idToken!.isNotEmpty) {
          return tokens.idToken;
        }

        final GoogleSignInUserData? userData =
            await GoogleSignInPlatform.instance.signInSilently();
        if (userData?.idToken != null && userData!.idToken!.isNotEmpty) {
          return userData.idToken;
        }

        return null;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      return auth.idToken;
    } catch (error) {
      print('Google token fetch error: $error');
      return null;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  static Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  static GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
}
