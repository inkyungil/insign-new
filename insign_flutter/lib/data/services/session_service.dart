// lib/data/services/session_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:insign/models/user.dart';

class StoredSession {
  final String accessToken;
  final User user;
  final int? expiresAt;

  const StoredSession({
    required this.accessToken,
    required this.user,
    this.expiresAt,
  });

  factory StoredSession.fromJson(Map<String, dynamic> json) {
    return StoredSession(
      accessToken: json['accessToken'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      expiresAt: json['expiresAt'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'user': user.toJson(),
      'expiresAt': expiresAt,
    };
  }
}

class SessionService {
  static const String _sessionKey = 'insign.session';

  // 세션 저장
  static Future<void> saveSession({
    required String accessToken,
    required User user,
    int? expiresIn,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final expiresAt =
        expiresIn != null ? DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000) : null;

    final session = StoredSession(
      accessToken: accessToken,
      user: user,
      expiresAt: expiresAt,
    );

    await prefs.setString(_sessionKey, json.encode(session.toJson()));
  }

  // 세션 로드
  static Future<StoredSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);

    if (raw == null) {
      return null;
    }

    try {
      final Map<String, dynamic> jsonData = json.decode(raw);
      final session = StoredSession.fromJson(jsonData);

      // 토큰이나 사용자 정보가 없으면 null 반환
      if (session.accessToken.isEmpty) {
        return null;
      }

      if (session.expiresAt != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (session.expiresAt! <= now) {
          await clearSession();
          return null;
        }
      }

      return session;
    } catch (e) {
      print('[session] Failed to parse stored session: $e');
      await clearSession();
      return null;
    }
  }

  // 액세스 토큰 가져오기
  static Future<String?> getAccessToken() async {
    final session = await loadSession();
    return session?.accessToken;
  }

  // 세션 삭제
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
