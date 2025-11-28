import 'package:flutter_test/flutter_test.dart';
import 'package:insign/data/app_update_repository.dart';
import 'package:insign/models/app_update_info.dart';

void main() {
  test('fetchUpdateInfo uses injected fetcher', () async {
    const stub = AppUpdateInfo(
      android: PlatformUpdateInfo(
        minimumSupportedVersion: '1.0.0',
        latestVersion: '1.2.0',
        storeUrl: 'https://play.google.com',
      ),
      ios: PlatformUpdateInfo(
        minimumSupportedVersion: '1.1.0',
        latestVersion: '1.3.0',
        storeUrl: 'https://apps.apple.com',
      ),
      message: '업데이트 필요',
    );

    final repository = AppUpdateRepository(fetcher: () async => stub);
    final result = await repository.fetchUpdateInfo();

    expect(result, equals(stub));
  });
}
