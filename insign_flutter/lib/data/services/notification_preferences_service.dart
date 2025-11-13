import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  final bool appNotifications;
  final bool contractUpdates;
  final bool marketingConsent;

  const NotificationPreferences({
    required this.appNotifications,
    required this.contractUpdates,
    required this.marketingConsent,
  });

  NotificationPreferences copyWith({
    bool? appNotifications,
    bool? contractUpdates,
    bool? marketingConsent,
  }) {
    return NotificationPreferences(
      appNotifications: appNotifications ?? this.appNotifications,
      contractUpdates: contractUpdates ?? this.contractUpdates,
      marketingConsent: marketingConsent ?? this.marketingConsent,
    );
  }
}

class NotificationPreferencesService {
  static const String _appNotificationsKey = 'notifications.app';
  static const String _contractUpdatesKey = 'notifications.contractUpdates';
  static const String _marketingConsentKey = 'notifications.marketing';

  static Future<NotificationPreferences> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final appNotifications = prefs.getBool(_appNotificationsKey) ?? true;
    final contractUpdates = prefs.getBool(_contractUpdatesKey) ?? true;
    final marketingConsent = prefs.getBool(_marketingConsentKey) ?? false;

    return NotificationPreferences(
      appNotifications: appNotifications,
      contractUpdates: contractUpdates,
      marketingConsent: marketingConsent,
    );
  }

  static Future<void> setAppNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appNotificationsKey, enabled);
  }

  static Future<void> setContractUpdates(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_contractUpdatesKey, enabled);
  }

  static Future<void> setMarketingConsent(bool consented) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_marketingConsentKey, consented);
  }

  static Future<void> setAppAndContract(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appNotificationsKey, enabled);
    await prefs.setBool(_contractUpdatesKey, enabled);
  }
}
