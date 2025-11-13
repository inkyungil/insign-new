import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
    'insign_default_channel',
    '일반 알림',
    description: '앱 실행 중 수신하는 일반 알림 채널',
    importance: Importance.high,
    enableLights: true,
    enableVibration: true,
  );

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initializationSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_defaultChannel);
    }

    _initialized = true;
  }

  static Future<void> showForegroundNotification(RemoteMessage message) async {
    await initialize();

    final notification = message.notification;
    final android = notification?.android;

    final title = notification?.title ?? message.data['title'] ?? '새 알림';
    final body = notification?.body ?? message.data['body'] ?? '';
    final category = (message.data['category'] ?? '').toString();
    final categoryLabel = category == 'contract'
        ? '계약 진행'
        : category == 'general'
            ? '앱 알림'
            : null;

    final androidDetails = AndroidNotificationDetails(
      _defaultChannel.id,
      _defaultChannel.name,
      channelDescription: _defaultChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: android?.smallIcon ?? '@mipmap/ic_launcher',
      ticker: notification?.body,
      subText: categoryLabel,
      groupKey: category.isEmpty ? null : 'insign.$category',
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      message.hashCode,
      title,
      body,
      details,
      payload: message.data['payload'],
    );
  }
}
