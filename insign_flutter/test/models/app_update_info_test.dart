import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insign/models/app_update_info.dart';

void main() {
  group('AppUpdateInfo', () {
    final json = {
      'android': {
        'minimumSupportedVersion': '1.0.0',
        'latestVersion': '1.2.0',
        'storeUrl': 'https://play.google.com',
      },
      'ios': {
        'minimumSupportedVersion': '1.1.0',
        'latestVersion': '1.3.0',
        'storeUrl': 'https://apps.apple.com',
      },
      'message': '업데이트가 필요합니다.',
    };

    test('parses from JSON', () {
      final info = AppUpdateInfo.fromJson(json);
      expect(info.message, equals('업데이트가 필요합니다.'));
      expect(info.android.latestVersion, equals('1.2.0'));
      expect(info.ios.storeUrl, equals('https://apps.apple.com'));
    });

    test('selects platform specific info', () {
      final info = AppUpdateInfo.fromJson(json);
      expect(info.forPlatform(TargetPlatform.iOS), equals(info.ios));
      expect(info.forPlatform(TargetPlatform.android), equals(info.android));
    });

    test('platform info detects force update need', () {
      final info = AppUpdateInfo.fromJson(json);
      expect(info.android.requiresForceUpdate('0.9.0'), isTrue);
      expect(info.android.requiresForceUpdate('1.0.0'), isFalse);
    });
  });
}
