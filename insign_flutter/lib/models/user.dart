// lib/models/user.dart

class User {
  final int id;
  final String email;
  final String? displayName;
  final String? lastLoginAt;
  final String? provider;
  final String? avatarUrl;
  final bool? agreedToTerms;
  final bool? agreedToPrivacy;
  final bool? agreedToSensitive;
  final bool? agreedToMarketing;

  // 구독 및 포인트 시스템
  final String subscriptionTier; // 'free' or 'premium'
  final int monthlyContractLimit; // 월 계약서 작성 제한
  final int contractsUsedThisMonth; // 이번 달 사용한 계약서 수
  final String? lastResetDate; // 마지막 리셋 날짜
  final int points; // 현재 포인트
  final int monthlyPointsLimit; // 월 포인트 적립 제한
  final int pointsEarnedThisMonth; // 이번 달 적립한 포인트
  final String? lastCheckInDate; // 마지막 출석 체크 날짜

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.lastLoginAt,
    this.provider,
    this.avatarUrl,
    this.agreedToTerms,
    this.agreedToPrivacy,
    this.agreedToSensitive,
    this.agreedToMarketing,
    this.subscriptionTier = 'free',
    this.monthlyContractLimit = 4,
    this.contractsUsedThisMonth = 0,
    this.lastResetDate,
    this.points = 12,
    this.monthlyPointsLimit = 12,
    this.pointsEarnedThisMonth = 0,
    this.lastCheckInDate,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Helper function to convert int or bool to bool
    bool? _toBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is int) return value != 0;
      return null;
    }

    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      lastLoginAt: json['lastLoginAt'] as String?,
      provider: json['provider'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      agreedToTerms: _toBool(json['agreedToTerms']),
      agreedToPrivacy: _toBool(json['agreedToPrivacy']),
      agreedToSensitive: _toBool(json['agreedToSensitive']),
      agreedToMarketing: _toBool(json['agreedToMarketing']),
      subscriptionTier: json['subscriptionTier'] as String? ?? 'free',
      monthlyContractLimit: json['monthlyContractLimit'] as int? ?? 4,
      contractsUsedThisMonth: json['contractsUsedThisMonth'] as int? ?? 0,
      lastResetDate: json['lastResetDate'] as String?,
      points: json['points'] as int? ?? 12,
      monthlyPointsLimit: json['monthlyPointsLimit'] as int? ?? 12,
      pointsEarnedThisMonth: json['pointsEarnedThisMonth'] as int? ?? 0,
      lastCheckInDate: json['lastCheckInDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'lastLoginAt': lastLoginAt,
      'provider': provider,
      'avatarUrl': avatarUrl,
      'agreedToTerms': agreedToTerms,
      'agreedToPrivacy': agreedToPrivacy,
      'agreedToSensitive': agreedToSensitive,
      'agreedToMarketing': agreedToMarketing,
      'subscriptionTier': subscriptionTier,
      'monthlyContractLimit': monthlyContractLimit,
      'contractsUsedThisMonth': contractsUsedThisMonth,
      'lastResetDate': lastResetDate,
      'points': points,
      'monthlyPointsLimit': monthlyPointsLimit,
      'pointsEarnedThisMonth': pointsEarnedThisMonth,
      'lastCheckInDate': lastCheckInDate,
    };
  }

  // Helper methods
  bool get isPremium => subscriptionTier == 'premium';
  bool get isFree => subscriptionTier == 'free';

  // 계약서 작성 가능 여부
  bool get canCreateContract {
    if (isPremium) return true; // 프리미엄은 무제한
    return contractsUsedThisMonth < monthlyContractLimit || points >= 3;
  }

  // 남은 무료 계약서 수
  int get remainingFreeContracts {
    if (isPremium) return -1; // 무제한
    final remaining = monthlyContractLimit - contractsUsedThisMonth;
    return remaining > 0 ? remaining : 0;
  }

  // 오늘 출석 체크 가능 여부
  bool get canCheckInToday {
    if (lastCheckInDate == null) return true;
    final today = DateTime.now();
    final lastCheckIn = DateTime.parse(lastCheckInDate!);
    return !_isSameDay(today, lastCheckIn);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class AuthResponse {
  final User user;
  final String accessToken;
  final int expiresIn;
  final bool? requiresTermsAgreement;

  const AuthResponse({
    required this.user,
    required this.accessToken,
    required this.expiresIn,
    this.requiresTermsAgreement,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String,
      expiresIn: json['expiresIn'] as int,
      requiresTermsAgreement: json['requiresTermsAgreement'] as bool?,
    );
  }
}
