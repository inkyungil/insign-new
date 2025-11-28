// lib/models/app_update_info.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:insign/core/utils/version_utils.dart';

class PlatformUpdateInfo extends Equatable {
  const PlatformUpdateInfo({
    required this.minimumSupportedVersion,
    required this.latestVersion,
    required this.storeUrl,
  });

  final String minimumSupportedVersion;
  final String latestVersion;
  final String storeUrl;

  factory PlatformUpdateInfo.fromJson(Map<String, dynamic> json) {
    return PlatformUpdateInfo(
      minimumSupportedVersion: json['minimumSupportedVersion'] as String? ?? '1.0.0',
      latestVersion: json['latestVersion'] as String? ?? '1.0.0',
      storeUrl: json['storeUrl'] as String? ?? '',
    );
  }

  bool requiresForceUpdate(String currentVersion) {
    return VersionUtils.compareSemanticVersions(
          currentVersion,
          minimumSupportedVersion,
        ) <
        0;
  }

  bool hasNewerVersion(String currentVersion) {
    return VersionUtils.compareSemanticVersions(currentVersion, latestVersion) < 0;
  }

  @override
  List<Object?> get props => [minimumSupportedVersion, latestVersion, storeUrl];
}

class AppUpdateInfo extends Equatable {
  const AppUpdateInfo({
    required this.android,
    required this.ios,
    required this.message,
  });

  final PlatformUpdateInfo android;
  final PlatformUpdateInfo ios;
  final String message;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      android: PlatformUpdateInfo.fromJson(
        json['android'] as Map<String, dynamic>? ?? const {},
      ),
      ios: PlatformUpdateInfo.fromJson(
        json['ios'] as Map<String, dynamic>? ?? const {},
      ),
      message: json['message'] as String? ?? '새 버전을 설치해 주세요.',
    );
  }

  PlatformUpdateInfo forPlatform(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      default:
        return android;
    }
  }

  @override
  List<Object?> get props => [android, ios, message];
}
