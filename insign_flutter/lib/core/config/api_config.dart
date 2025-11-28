// lib/core/config/api_config.dart

class ApiConfig {
  // API Base URL - 실제 서버 주소로 변경하세요
  static const String baseUrl = 'https://in-sign.shop';
  static const String apiEndpoint = '$baseUrl/api';

  // API Endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authGoogle = '/auth/google';
  static const String authLogout = '/auth/logout';
  static const String authDeleteAccount = '/auth/delete-account';
  static const String authChangePassword = '/auth/change-password';
  static const String authVerifyEmail = '/auth/verify-email';
  static const String authResendVerification = '/auth/resend-verification';
  static const String authCompleteRegistration = '/auth/complete-registration';
  static const String authStats = '/auth/stats';
  static const String authCheckIn = '/auth/check-in';
  static const String checkInHistory = '/auth/check-in-history';
  static const String authAddPointsFromAd = '/auth/add-points-from-ad';
  static const String pushTokenRegister = '/push-tokens';
  static const String pushTokenRemove = '/push-tokens/remove';
  static const String policyPrivacy = '/policies/privacy-policy';
  static const String policyTerms = '/policies/terms-of-service';
  static const String contracts = '/contracts';
  static const String templates = '/templates';
  static const String inbox = '/inbox';
  static const String events = '/events';
  static const String appUpdateInfo = '/app/update-info';
}
