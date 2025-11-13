// lib/features/auth/cubit/auth_cubit.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:insign/data/auth_repository.dart';
import 'package:insign/data/services/google_auth_service.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/models/user.dart';
import 'package:insign/services/push_notification_service.dart';

/// Manages authentication state and user information.
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository(),
        super(const AuthState());

  /// 앱 시작 시 세션 확인
  Future<void> checkSession() async {
    try {
      final session = await SessionService.loadSession();
      if (session != null) {
        emit(AuthState(
          isLoggedIn: true,
          user: session.user,
          isSessionChecked: true,
        ));
        await PushNotificationService.syncTokenWithServer(
          accessToken: session.accessToken,
        );
      } else {
        emit(const AuthState(isSessionChecked: true));
      }
    } catch (e) {
      print('Session check error: $e');
      emit(const AuthState(isSessionChecked: true));
    }
  }

  /// 직접 로그인 (이메일/비밀번호)
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _authRepository.login(
        email: email,
        password: password,
      );

      await SessionService.saveSession(
        accessToken: response.accessToken,
        user: response.user,
        expiresIn: response.expiresIn,
      );

      await PushNotificationService.syncTokenWithServer(
        accessToken: response.accessToken,
      );

      emit(AuthState(
        isLoggedIn: true,
        user: response.user,
        isSessionChecked: true,
      ));

      return response;
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  /// 회원가입
  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      await _authRepository.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      return true;
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }

  /// Google 로그인
  Future<bool> loginWithGoogle({GoogleSignInAccount? account}) async {
    try {
      final GoogleSignInAccount? resolvedAccount =
          account ?? await GoogleAuthService.signIn();
      if (resolvedAccount == null) {
        return false;
      }

      final String? idToken = await GoogleAuthService.getIdToken(
        resolvedAccount,
        forceRefresh: kIsWeb,
      );

      if (idToken == null) {
        print('Google ID token is null');
        return false;
      }

      final response = await _authRepository.loginWithGoogle(idToken);

      await SessionService.saveSession(
        accessToken: response.accessToken,
        user: response.user,
        expiresIn: response.expiresIn,
      );

      await PushNotificationService.syncTokenWithServer(
        accessToken: response.accessToken,
      );

      emit(AuthState(
        isLoggedIn: true,
        user: response.user,
        isSessionChecked: true,
      ));

      return true;
    } catch (e) {
      print('Google login error: $e');
      return false;
    }
  }

  /// 로그아웃
  Future<void> logout() async {
    String? accessToken;
    try {
      accessToken = await SessionService.getAccessToken();
      await _authRepository.logout(accessToken);
    } catch (e) {
      print('Logout API error: $e');
    } finally {
      if (accessToken != null && accessToken.isNotEmpty) {
        await PushNotificationService.unregisterToken(accessToken: accessToken);
      }
      await GoogleAuthService.signOut();
      await SessionService.clearSession();
      emit(const AuthState(isSessionChecked: true));
    }
  }

  /// 회원 탈퇴
  Future<void> deleteAccount({String? password}) async {
    final accessToken = await SessionService.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('로그인 세션이 만료되었습니다. 다시 로그인해 주세요.');
    }

    await _authRepository.deleteAccount(
      token: accessToken,
      password: password,
    );

    try {
      await PushNotificationService.unregisterToken(accessToken: accessToken);
    } catch (error) {
      print('Push token unregister failed after deletion: $error');
    }
    await GoogleAuthService.signOut();
    await SessionService.clearSession();
    emit(const AuthState(isSessionChecked: true));
  }

  /// 비밀번호 변경
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final accessToken = await SessionService.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('로그인 세션이 만료되었습니다. 다시 로그인해 주세요.');
    }

    await _authRepository.changePassword(
      token: accessToken,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Get current user
  User? get currentUser => state.user;
}

/// Authentication state containing login status and user information
class AuthState {
  final bool isLoggedIn;
  final User? user;
  final bool isSessionChecked;

  const AuthState({
    this.isLoggedIn = false,
    this.user,
    this.isSessionChecked = false,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    User? user,
    bool? isSessionChecked,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
      isSessionChecked: isSessionChecked ?? this.isSessionChecked,
    );
  }
}
