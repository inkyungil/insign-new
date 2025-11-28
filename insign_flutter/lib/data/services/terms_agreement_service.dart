// lib/data/services/terms_agreement_service.dart

import 'package:shared_preferences/shared_preferences.dart';

/// 약관동의 상태를 저장하고 관리하는 서비스
class TermsAgreementService {
  static const String _termsAgreedKey = 'insign.terms_agreed';
  static const String _agreedDateKey = 'insign.terms_agreed_date';
  static const String _serviceTermsKey = 'insign.service_terms_agreed';
  static const String _privacyPolicyKey = 'insign.privacy_policy_agreed';
  static const String _sensitiveInfoKey = 'insign.sensitive_info_agreed';
  static const String _marketingKey = 'insign.marketing_agreed';

  /// 사용자별 약관 동의 완료 여부 확인
  static Future<bool> hasAgreedToTerms({String? userEmail}) async {
    final prefs = await SharedPreferences.getInstance();
    if (userEmail != null && userEmail.isNotEmpty) {
      // 사용자별 약관 동의 상태 확인
      return prefs.getBool('$_termsAgreedKey.$userEmail') ?? false;
    }
    // 전역 약관 동의 상태 확인 (하위 호환성)
    return prefs.getBool(_termsAgreedKey) ?? false;
  }

  /// 약관 동의 저장 (사용자별)
  static Future<void> saveAgreement({
    required bool serviceTerms,
    required bool privacyPolicy,
    required bool sensitiveInfo,
    bool marketing = false,
    String? userEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 필수 약관이 모두 동의되어야 저장
    if (serviceTerms && privacyPolicy && sensitiveInfo) {
      if (userEmail != null && userEmail.isNotEmpty) {
        // 사용자별로 저장
        await prefs.setBool('$_termsAgreedKey.$userEmail', true);
        await prefs.setString('$_agreedDateKey.$userEmail', DateTime.now().toIso8601String());
        await prefs.setBool('$_serviceTermsKey.$userEmail', serviceTerms);
        await prefs.setBool('$_privacyPolicyKey.$userEmail', privacyPolicy);
        await prefs.setBool('$_sensitiveInfoKey.$userEmail', sensitiveInfo);
        await prefs.setBool('$_marketingKey.$userEmail', marketing);
      } else {
        // 전역으로 저장 (하위 호환성)
        await prefs.setBool(_termsAgreedKey, true);
        await prefs.setString(_agreedDateKey, DateTime.now().toIso8601String());
        await prefs.setBool(_serviceTermsKey, serviceTerms);
        await prefs.setBool(_privacyPolicyKey, privacyPolicy);
        await prefs.setBool(_sensitiveInfoKey, sensitiveInfo);
        await prefs.setBool(_marketingKey, marketing);
      }
    }
  }

  /// 개별 약관 동의 상태 조회
  static Future<Map<String, bool>> getAgreementDetails() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'serviceTerms': prefs.getBool(_serviceTermsKey) ?? false,
      'privacyPolicy': prefs.getBool(_privacyPolicyKey) ?? false,
      'sensitiveInfo': prefs.getBool(_sensitiveInfoKey) ?? false,
      'marketing': prefs.getBool(_marketingKey) ?? false,
    };
  }

  /// 약관 동의 날짜 조회
  static Future<DateTime?> getAgreementDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_agreedDateKey);
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  /// 약관 동의 초기화 (로그아웃 시 사용)
  static Future<void> clearAgreement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_termsAgreedKey);
    await prefs.remove(_agreedDateKey);
    await prefs.remove(_serviceTermsKey);
    await prefs.remove(_privacyPolicyKey);
    await prefs.remove(_sensitiveInfoKey);
    await prefs.remove(_marketingKey);
  }

  /// 마케팅 동의만 업데이트 (선택 약관)
  static Future<void> updateMarketingConsent(bool agreed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_marketingKey, agreed);
  }
}
