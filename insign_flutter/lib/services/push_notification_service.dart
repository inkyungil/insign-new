import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:insign/core/config/api_config.dart';
import 'package:insign/data/services/api_client.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/data/services/notification_preferences_service.dart';
import 'package:insign/firebase_options.dart';
import 'package:insign/services/local_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (error) {
      debugPrint('Background Firebase init failed: $error');
      return;
    }
  }
  debugPrint('Background message received: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;
  static bool _syncInProgress = false;
  static String? _cachedToken;

  static const String _tokenStorageKey = 'notifications.fcmToken';
  static const String _registeredTokenKey = 'notifications.fcmToken.registered';

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (kIsWeb) {
      debugPrint('FCM 웹 초기화는 별도 구성 필요. 현재는 건너뜁니다.');
      _initialized = true;
      return;
    }

    FirebaseOptions? options;
    try {
      options = DefaultFirebaseOptions.currentPlatform;
      debugPrint('Loaded Firebase options for ${defaultTargetPlatform.name}');
    } catch (error) {
      debugPrint('FirebaseOptions not provided for this platform: $error');
    }

    try {
      if (Firebase.apps.isEmpty) {
        if (options != null) {
          debugPrint('Initializing Firebase with explicit options.');
          await Firebase.initializeApp(options: options);
        } else {
          debugPrint('Initializing Firebase with default options.');
          await Firebase.initializeApp();
        }
      } else {
        debugPrint('Firebase already initialized with ${Firebase.apps.length} app(s).');
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (error, stackTrace) {
      debugPrint('Firebase init failed: $error');
      debugPrint('$stackTrace');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    final target = defaultTargetPlatform;

    late final NotificationSettings settings;
    if (target == TargetPlatform.iOS || target == TargetPlatform.macOS) {
      settings = await messaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    } else {
      settings = await messaging.requestPermission();
    }

    await _syncAuthorizationStatus(settings.authorizationStatus);

    await messaging.setAutoInitEnabled(true);

    await LocalNotificationService.initialize();

    final token = await messaging.getToken();
    if (token != null) {
      await _handleNewToken(token);
    }

    FirebaseMessaging.onMessage.listen((message) async {
      debugPrint('Foreground message: ${message.messageId}, data: ${message.data}');

      final preferences = await NotificationPreferencesService.loadPreferences();
      if (!preferences.appNotifications) {
        debugPrint('Foreground notification suppressed: app notifications disabled.');
        return;
      }

      final category = (message.data['category'] ?? '').toString();
      if (category == 'contract' && !preferences.contractUpdates) {
        debugPrint('Foreground notification suppressed: contract updates disabled.');
        return;
      }

      await LocalNotificationService.showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification opened app: ${message.messageId}');
    });

    messaging.onTokenRefresh.listen((newToken) async {
      await _handleNewToken(newToken);
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from terminated state via notification: ${initialMessage.messageId}');
    }

    _initialized = true;
  }

  static Future<void> syncTokenWithServer({String? accessToken}) async {
    if (kIsWeb) {
      return;
    }

    if (_syncInProgress) {
      return;
    }

    final token = _cachedToken ?? await _loadStoredToken();
    if (token == null || token.isEmpty) {
      return;
    }

    final providedToken = accessToken ?? await SessionService.getAccessToken();
    if (providedToken == null || providedToken.isEmpty) {
      debugPrint('Skip FCM token sync: no session token.');
      return;
    }

    final platform = _resolvePlatform();

    try {
      _syncInProgress = true;
      final prefs = await SharedPreferences.getInstance();
      final registered = prefs.getString(_registeredTokenKey);
      final marker = '$token|$platform';
      if (registered == marker) {
        debugPrint('FCM token already synced.');
        return;
      }

      await ApiClient.requestVoid(
        path: ApiConfig.pushTokenRegister,
        method: 'POST',
        token: providedToken,
        body: {
          'token': token,
          'platform': platform,
        },
      );

      await prefs.setString(_registeredTokenKey, marker);
      debugPrint('Synced FCM token with server.');
    } catch (error, stackTrace) {
      debugPrint('Failed to sync FCM token: $error');
      debugPrint('$stackTrace');
    } finally {
      _syncInProgress = false;
    }
  }

  static Future<void> unregisterToken({String? accessToken}) async {
    if (kIsWeb) {
      return;
    }

    final token = _cachedToken ?? await _loadStoredToken();
    if (token == null || token.isEmpty) {
      return;
    }

    final providedToken = accessToken ?? await SessionService.getAccessToken();
    if (providedToken == null || providedToken.isEmpty) {
      return;
    }

    try {
      await ApiClient.requestVoid(
        path: ApiConfig.pushTokenRemove,
        method: 'POST',
        token: providedToken,
        body: {
          'token': token,
        },
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_registeredTokenKey);
      debugPrint('Unregistered FCM token on server.');
    } catch (error, stackTrace) {
      debugPrint('Failed to unregister FCM token: $error');
      debugPrint('$stackTrace');
    }
  }

  static String _resolvePlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static Future<void> _handleNewToken(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      return;
    }
    _cachedToken = normalized;
    await _storeToken(normalized);
    await syncTokenWithServer();
    debugPrint('FCM token: $normalized');
  }

  static Future<void> _storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenStorageKey, token);
  }

  static Future<String?> _loadStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenStorageKey);
  }
}

Future<void> _syncAuthorizationStatus(AuthorizationStatus status) async {
  final shouldEnable = status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  await NotificationPreferencesService.setAppAndContract(shouldEnable);
}
