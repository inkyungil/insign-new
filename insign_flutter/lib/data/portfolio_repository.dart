// lib/data/portfolio_repository.dart

import 'package:insign/models/portfolio.dart';

class PortfolioRepository {
  Future<Portfolio> fetchPortfolio() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    return const Portfolio(
      totalValue: 15420000,
      totalReturn: -3580000,
      returnRate: -23.0,
      holdings: [
        Holding(
          symbol: '005930',
          name: '삼성전자',
          currentPrice: 5680000,
          returnAmount: 420000,
          returnRate: 8.0,
          weight: 0.368,
        ),
        Holding(
          symbol: '131970',
          name: 'SK하이닉스',
          currentPrice: 3240000,
          returnAmount: -680000,
          returnRate: -17.4,
          weight: 0.210,
        ),
        Holding(
          symbol: '035420',
          name: 'NAVER',
          currentPrice: 2150000,
          returnAmount: 240000,
          returnRate: 12.6,
          weight: 0.139,
        ),
        Holding(
          symbol: '017670',
          name: '카카오',
          currentPrice: 1890000,
          returnAmount: -870000,
          returnRate: -31.5,
          weight: 0.123,
        ),
        Holding(
          symbol: '068270',
          name: '셀트리온',
          currentPrice: 2460000,
          returnAmount: 390000,
          returnRate: 18.8,
          weight: 0.160,
        ),
      ],
    );
  }

  Future<List<AIRecommendation>> fetchAIRecommendations() async {
    await Future.delayed(const Duration(milliseconds: 300));

    return const [
      AIRecommendation(
        title: '주식보다는 채권 투자를',
        description: '금리 인하로 인한 채권값 상승이 예상되니 주식 일부 비중을 줄이고 국채 비중을 늘려 보세요.',
        action: '매도',
      ),
      AIRecommendation(
        title: '현금 보유',
        description: '불확실한 증시 상황으로 현재까지는 매수 타이밍이 아닙니다.',
        action: '보유',
      ),
    ];
  }
}
