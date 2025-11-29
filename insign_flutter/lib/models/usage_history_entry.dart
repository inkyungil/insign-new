import 'package:intl/intl.dart';

enum UsageHistoryType { contract, points }

class UsageHistoryEntry {
  final UsageHistoryType type;
  final DateTime createdAt;

  // Contract fields
  final int? contractId;
  final String? contractName;
  final String? contractStatus;
  final bool? usedPointsForCreation;
  final int? pointsSpentForCreation;
  final int? contractsUsedBefore;
  final int? contractLimitAtCreation;

  // Points ledger fields
  final int? ledgerId;
  final String? transactionType;
  final int? amount;
  final int? balanceAfter;
  final String? description;
  final String? referenceType;
  final int? referenceId;

  UsageHistoryEntry({
    required this.type,
    required this.createdAt,
    this.contractId,
    this.contractName,
    this.contractStatus,
    this.usedPointsForCreation,
    this.pointsSpentForCreation,
    this.contractsUsedBefore,
    this.contractLimitAtCreation,
    this.ledgerId,
    this.transactionType,
    this.amount,
    this.balanceAfter,
    this.description,
    this.referenceType,
    this.referenceId,
  });

  factory UsageHistoryEntry.fromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String? ?? 'contract';
    final type = typeString == 'points'
        ? UsageHistoryType.points
        : UsageHistoryType.contract;

    return UsageHistoryEntry(
      type: type,
      createdAt: DateTime.parse(json['createdAt'] as String),
      contractId: json['contractId'] as int?,
      contractName: json['name'] as String?,
      contractStatus: json['status'] as String?,
      usedPointsForCreation: json['usedPointsForCreation'] as bool?,
      pointsSpentForCreation: json['pointsSpentForCreation'] as int?,
      contractsUsedBefore: json['contractsUsedBeforeCreation'] as int?,
      contractLimitAtCreation: json['contractLimitAtCreation'] as int?,
      ledgerId: (json['ledgerId'] as num?)?.toInt(),
      transactionType: json['transactionType'] as String?,
      amount: (json['amount'] as num?)?.toInt(),
      balanceAfter: (json['balanceAfter'] as num?)?.toInt(),
      description: json['description'] as String?,
      referenceType: json['referenceType'] as String?,
      referenceId: (json['referenceId'] as num?)?.toInt(),
    );
  }

  bool get isContract => type == UsageHistoryType.contract;
  bool get isPoints => type == UsageHistoryType.points;

  String get formattedDate {
    final formatter = DateFormat('yyyy.MM.dd HH:mm');
    return formatter.format(createdAt);
  }

  int? get usedCountAfterCreation {
    if (contractsUsedBefore == null) {
      return null;
    }
    return contractsUsedBefore! + 1;
  }

  bool get isUnlimitedPlan => (contractLimitAtCreation ?? -1) < 0;

  String get contractUsageLabel {
    if (usedPointsForCreation == true) {
      final pointValue = pointsSpentForCreation ?? 0;
      return '포인트 ${pointValue.abs()}P 사용';
    }
    return '무료 티켓 사용';
  }

  String get pointsAmountLabel {
    if (!isPoints || amount == null) {
      return '';
    }
    final sign = amount! >= 0 ? '+' : '-';
    return '$sign${amount!.abs()}P';
  }

  bool get isPointEarn => amount != null && amount! > 0;
  bool get isPointSpend => amount != null && amount! < 0;

  String get transactionLabel {
    switch (transactionType) {
      case 'earn_checkin':
        return '출석 체크';
      case 'earn_signup':
        return '가입 보너스';
      case 'earn_referral':
        return '추천 보너스';
      case 'earn_ad':
        return '광고 시청';
      case 'earn_admin':
        return '관리자 지급';
      case 'spend_contract':
        return '계약서 작성';
      case 'spend_template':
        return '템플릿 사용';
      case 'expire':
        return '포인트 만료';
      case 'refund':
        return '환불';
      default:
        return '포인트 거래';
    }
  }
}
