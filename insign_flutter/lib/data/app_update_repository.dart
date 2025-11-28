// lib/data/app_update_repository.dart

import 'package:insign/core/config/api_config.dart';
import 'package:insign/data/services/api_client.dart';
import 'package:insign/models/app_update_info.dart';

typedef AppUpdateFetcher = Future<AppUpdateInfo> Function();

class AppUpdateRepository {
  const AppUpdateRepository({AppUpdateFetcher? fetcher})
      : _fetcher = fetcher ?? _defaultFetcher;

  final AppUpdateFetcher _fetcher;

  static Future<AppUpdateInfo> _defaultFetcher() {
    return ApiClient.request(
      path: ApiConfig.appUpdateInfo,
      method: 'GET',
      fromJson: AppUpdateInfo.fromJson,
    );
  }

  Future<AppUpdateInfo> fetchUpdateInfo() {
    return _fetcher();
  }
}
