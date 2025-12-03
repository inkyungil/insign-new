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
  static const String _iosClientId =
      '723715287873-nrqen0g7j7m679h6196i215308441539.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const [
      'email',
      'profile',
    ],
    clientId: kIsWeb
        ? _webClientId
        : (defaultTargetPlatform == TargetPlatform.iOS ? _iosClientId : null),
    // serverClientId is unsupported on web; only set for mobile.
    serverClientId: kIsWeb ? null : _webClientId,
  );

  static Stream<GoogleSignInAccount?> get userChanges =>
      _googleSignIn.onCurrentUserChanged;

  static Future<void>? _initFuture;

  static Future<void> ensureInitialized() async {
    if (!kIsWeb) return;
    _initFuture ??= _initWeb();
    await _initFuture;
    print('[GAuth] web init complete');
    return _initFuture!;
  }

  static Future<void> _initWeb() async {
    // Must be called before any other google_sign_in_web APIs (e.g., renderButton)
    await GoogleSignInPlatform.instance.initWithParams(
      const SignInInitParameters(
        clientId: _webClientId,
        scopes: ['email', 'profile'],
      ),
    );
    try {
      await _googleSignIn.signInSilently();
    } catch (_) {
      // Silent sign-in may fail when there is no existing session; ignore.
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

  /// Silent sign-in only (no popup)
  static Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (error) {
      print('Google Silent Sign-In error: $error');
      return null;
    }
  }

  static Future<String?> getIdToken(
    GoogleSignInAccount account, {
    bool forceRefresh = false,
  }) async {
    try {
      if (kIsWeb) {
        print('[GAuth] getIdToken (web) for ${account.email}, forceRefresh=$forceRefresh');
        final GoogleSignInTokenData tokens =
            await GoogleSignInPlatform.instance.getTokens(
          email: account.email,
          shouldRecoverAuth: forceRefresh,
        );
        print('[GAuth] web tokens: idToken len=${tokens.idToken?.length ?? 0}');
        if (tokens.idToken != null && tokens.idToken!.isNotEmpty) {
          return tokens.idToken;
        }

        final GoogleSignInUserData? userData =
            await GoogleSignInPlatform.instance.signInSilently();
        if (userData?.idToken != null && userData!.idToken!.isNotEmpty) {
          print('[GAuth] web signInSilently returned idToken len=${userData.idToken?.length}');
          return userData.idToken;
        }

        return null;
      }

      print('[GAuth] getIdToken (mobile) for ${account.email}');
      final GoogleSignInAuthentication auth = await account.authentication;
      print('[GAuth] mobile idToken len=${auth.idToken?.length ?? 0}');
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
