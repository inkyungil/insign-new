import 'package:equatable/equatable.dart';

class Stock extends Equatable {
  final String code;
  final String name;
  final String market; // KOSPI, KOSDAQ, COIN
  final int? currentPrice;
  final int? changeAmount;
  final double? changeRate;
  final int? marketCap; // 숫자로 변경
  final int? volume;
  final DateTime? updatedAt;
  final int? stockId; // DB의 stock_id

  const Stock({
    required this.code,
    required this.name,
    required this.market,
    this.currentPrice,
    this.changeAmount,
    this.changeRate,
    this.marketCap,
    this.volume,
    this.updatedAt,
    this.stockId,
  });

  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      code: json['code'] ?? json['ticker'] ?? '',
      name: json['name'] ?? '',
      market: json['market'] ?? '',
      currentPrice: _parseToInt(json['price']),
      changeAmount: _parseToInt(json['change_amount']),
      changeRate: _parseToDouble(json['change_rate']),
      marketCap: _parseToInt(json['market_cap']),
      volume: _parseToInt(json['volume']),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      stockId: _parseToInt(json['stock_id']),
    );
  }

  // 관심종목 목록 API 응답용
  factory Stock.fromFavoriteJson(Map<String, dynamic> json) {
    return Stock(
      code: json['ticker'] ?? '',
      name: json['company_name'] ?? '',
      market: json['market_type'] ?? '',
      currentPrice: _parseToInt(json['current_price']),
      changeAmount: _parseToInt(json['change_amount']),
      changeRate: _parseToDouble(json['change_rate']),
      marketCap: null, // 관심종목 API에서는 시가총액 없음
      volume: _parseToInt(json['volume']),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      stockId: _parseToInt(json['stock_id']),
    );
  }

  // 문자열이나 숫자를 int로 변환하는 헬퍼 함수
  static int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final doubleValue = double.tryParse(value);
      return doubleValue?.toInt();
    }
    return null;
  }

  // 문자열이나 숫자를 double로 변환하는 헬퍼 함수
  static double? _parseToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'market': market,
      'current_price': currentPrice,
      'change_amount': changeAmount,
      'change_rate': changeRate,
      'market_cap': marketCap,
      'volume': volume,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  String get formattedPrice {
    if (currentPrice == null) return '-';
    return '${currentPrice.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]},',
    )}';
  }

  String get formattedChange {
    if (changeRate == null) return '-';
    final sign = changeRate! >= 0 ? '+' : '';
    return '$sign${changeRate!.toStringAsFixed(2)}%';
  }

  String get formattedMarketCap {
    if (marketCap == null) return '-';
    
    // 억 단위로 변환 (API에서 오는 값이 억 원 단위인 것으로 보임)
    if (marketCap! >= 10000) {
      final trillion = (marketCap! / 10000).toStringAsFixed(1);
      return '${trillion}조';
    } else if (marketCap! >= 100) {
      final hundreds = (marketCap! / 100).toStringAsFixed(0);
      return '${hundreds}조';
    } else {
      return '${marketCap!}억';
    }
  }

  String get formattedVolume {
    if (volume == null) return '-';
    
    // 거래량을 단위별로 포맷팅
    if (volume! >= 100000000) {
      final billion = (volume! / 100000000).toStringAsFixed(1);
      return '${billion}억';
    } else if (volume! >= 10000) {
      final ten_thousand = (volume! / 10000).toStringAsFixed(1);
      return '${ten_thousand}만';
    } else if (volume! >= 1000) {
      final thousand = (volume! / 1000).toStringAsFixed(1);
      return '${thousand}천';
    } else {
      return volume.toString();
    }
  }

  String get changeType {
    if (changeRate == null || changeRate == 0) return 'flat';
    return changeRate! > 0 ? 'up' : 'down';
  }

  @override
  List<Object?> get props => [
    code,
    name,
    market,
    currentPrice,
    changeAmount,
    changeRate,
    marketCap,
    volume,
    updatedAt,
    stockId,
  ];
}