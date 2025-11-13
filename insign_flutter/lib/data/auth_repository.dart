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
}
