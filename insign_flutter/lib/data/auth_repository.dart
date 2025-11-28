// lib/data/auth_repository.dart

import 'package:insign/core/config/api_config.dart';
import 'package:insign/data/services/api_client.dart';
import 'package:insign/models/user.dart';

class AuthRepository {
  // 회원가입
  Future<AuthResponse> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final body = {
      'email': email,
      'password': password,
      if (displayName != null) 'displayName': displayName,
    };

    return await ApiClient.request<AuthResponse>(
      path: ApiConfig.authRegister,
      method: 'POST',
      body: body,
      fromJson: (json) => AuthResponse.fromJson(json),
    );
  }

  // 로그인
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final body = {
      'email': email,
      'password': password,
    };

    return await ApiClient.request<AuthResponse>(
      path: ApiConfig.authLogin,
      method: 'POST',
      body: body,
      fromJson: (json) => AuthResponse.fromJson(json),
    );
  }

  // Google 로그인
  Future<AuthResponse> loginWithGoogle(String idToken) async {
    final body = {
      'idToken': idToken,
    };

    return await ApiClient.request<AuthResponse>(
      path: ApiConfig.authGoogle,
      method: 'POST',
      body: body,
      fromJson: (json) => AuthResponse.fromJson(json),
    );
  }

  // 로그아웃
  Future<void> logout(String? token) async {
    await ApiClient.requestVoid(
      path: ApiConfig.authLogout,
      method: 'POST',
      token: token,
    );
  }

  // 회원 탈퇴
  Future<void> deleteAccount({
    required String token,
    String? password,
  }) async {
    await ApiClient.requestVoid(
      path: ApiConfig.authDeleteAccount,
      method: 'POST',
      token: token,
      body: {
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
  }

  // 비밀번호 변경
  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    await ApiClient.requestVoid(
      path: ApiConfig.authChangePassword,
      method: 'POST',
      token: token,
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  // 이메일 인증
  Future<Map<String, dynamic>> verifyEmail(String token) async {
    return await ApiClient.request<Map<String, dynamic>>(
      path: ApiConfig.authVerifyEmail,
      method: 'POST',
      body: {'token': token},
      fromJson: (json) => json as Map<String, dynamic>,
    );
  }

  // 인증 메일 재발송
  Future<Map<String, dynamic>> resendVerificationEmail(String email) async {
    return await ApiClient.request<Map<String, dynamic>>(
      path: ApiConfig.authResendVerification,
      method: 'POST',
      body: {'email': email},
      fromJson: (json) => json as Map<String, dynamic>,
    );
  }

  // 약관 동의 완료 (회원가입 마무리)
  Future<AuthResponse> completeRegistration({
    required String token,
    required bool agreedToTerms,
    required bool agreedToPrivacy,
    required bool agreedToSensitive,
    required bool agreedToMarketing,
  }) async {
    return await ApiClient.request<AuthResponse>(
      path: ApiConfig.authCompleteRegistration,
      method: 'POST',
      token: token,
      body: {
        'agreedToTerms': agreedToTerms,
        'agreedToPrivacy': agreedToPrivacy,
        'agreedToSensitive': agreedToSensitive,
        'agreedToMarketing': agreedToMarketing,
      },
      fromJson: (json) => AuthResponse.fromJson(json),
    );
  }

  // 사용자 통계 조회 (구독, 포인트, 사용량)
  Future<User> getUserStats(String token) async {
    return await ApiClient.request<User>(
      path: ApiConfig.authStats,
      method: 'POST',
      token: token,
      fromJson: (json) => User.fromJson(json),
    );
  }

  // 출석 체크
  Future<Map<String, dynamic>> checkIn(String token) async {
    return await ApiClient.request<Map<String, dynamic>>(
      path: ApiConfig.authCheckIn,
      method: 'POST',
      token: token,
      fromJson: (json) => json as Map<String, dynamic>,
    );
  }

  // 광고 시청 포인트 적립
  Future<Map<String, dynamic>> addPointsFromAd({
    required String token,
    int points = 1,
  }) async {
    return await ApiClient.request<Map<String, dynamic>>(
      path: ApiConfig.authAddPointsFromAd,
      method: 'POST',
      token: token,
      body: {'points': points},
      fromJson: (json) => json as Map<String, dynamic>,
    );
  }
}
