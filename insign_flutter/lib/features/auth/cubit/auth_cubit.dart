// lib/features/auth/cubit/auth_cubit.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:insign/data/auth_repository.dart';
import 'package:insign/data/services/google_auth_service.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/data/services/terms_agreement_service.dart';
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

      // 약관 동의가 필요한 경우 (임시 토큰)
      final needsTermsAgreement = response.user.agreedToTerms != true ||
                                  response.user.agreedToPrivacy != true ||
                                  response.user.agreedToSensitive != true;

      if (needsTermsAgreement) {
        // 임시 토큰만 저장, 로그인 상태는 false 유지
        await SessionService.saveSession(
          accessToken: response.accessToken,
          user: response.user,
          expiresIn: response.expiresIn,
        );

        // 로그인 상태는 false로 유지 (약관 동의 필요)
        emit(AuthState(
          isLoggedIn: false,
          user: response.user,
          isSessionChecked: true,
        ));

        return true;
      }

      // 약관 동의 완료된 경우 - 정상 로그인
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
      // 약관 동의는 사용자별로 저장되므로 로그아웃 시 초기화하지 않음
      // await TermsAgreementService.clearAgreement();
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
    await TermsAgreementService.clearAgreement();
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

  /// 이메일 인증
  Future<String> verifyEmail(String token) async {
    try {
      final result = await _authRepository.verifyEmail(token);
      return result['message'] ?? '이메일 인증이 완료되었습니다.';
    } catch (e) {
      print('Email verification error: $e');
      rethrow;
    }
  }

  /// 인증 메일 재발송
  Future<String> resendVerificationEmail(String email) async {
    try {
      final result = await _authRepository.resendVerificationEmail(email);
      return result['message'] ?? '인증 메일을 재발송했습니다.';
    } catch (e) {
      print('Resend verification error: $e');
      rethrow;
    }
  }

  /// 약관 동의 완료 (회원가입 마무리)
  Future<AuthResponse> completeRegistration({
    required String tempToken,
    required bool agreedToTerms,
    required bool agreedToPrivacy,
    required bool agreedToSensitive,
    required bool agreedToMarketing,
  }) async {
    try {
      final response = await _authRepository.completeRegistration(
        token: tempToken,
        agreedToTerms: agreedToTerms,
        agreedToPrivacy: agreedToPrivacy,
        agreedToSensitive: agreedToSensitive,
        agreedToMarketing: agreedToMarketing,
      );

      // 정식 토큰으로 세션 저장
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
      print('Complete registration error: $e');
      rethrow;
    }
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
