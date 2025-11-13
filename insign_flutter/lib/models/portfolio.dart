// lib/models/portfolio.dart

import 'package:equatable/equatable.dart';

class Portfolio extends Equatable {
  final double totalValue;
  final double totalReturn;
  final double returnRate;
  final List<Holding> holdings;

  const Portfolio({
    required this.totalValue,
    required this.totalReturn,
    required this.returnRate,
    required this.holdings,
  });

  @override
  List<Object?> get props => [totalValue, totalReturn, returnRate, holdings];
}

class Holding extends Equatable {
  final String symbol;
  final String name;
  final double currentPrice;
  final double returnAmount;
  final double returnRate;
  final double weight; // 비중 (0.0 - 1.0)

  const Holding({
    required this.symbol,
    required this.name,
    required this.currentPrice,
    required this.returnAmount,
    required this.returnRate,
    required this.weight,
  });

  @override
  List<Object?> get props => [symbol, name, currentPrice, returnAmount, returnRate, weight];
}

class AIRecommendation extends Equatable {
  final String title;
  final String description;
  final String action; // '매수', '매도', '보유'

  const AIRecommendation({
    required this.title,
    required this.description,
    required this.action,
  });

  @override
  List<Object?> get props => [title, description, action];
}
