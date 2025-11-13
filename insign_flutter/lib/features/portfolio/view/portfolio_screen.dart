// lib/features/portfolio/view/portfolio_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/data/portfolio_repository.dart';
import 'package:insign/models/portfolio.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  late Future<Portfolio> _portfolioFuture;
  late Future<List<AIRecommendation>> _recommendationsFuture;

  @override
  void initState() {
    super.initState();
    final repo = PortfolioRepository();
    _portfolioFuture = repo.fetchPortfolio();
    _recommendationsFuture = repo.fetchAIRecommendations();
  }

  String _formatMoney(double amount) {
    if (amount.abs() >= 1000000) {
      return '${(amount / 10000).toStringAsFixed(0)}만원';
    }
    return '${amount.toStringAsFixed(0)}원';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            final repo = PortfolioRepository();
            _portfolioFuture = repo.fetchPortfolio();
            _recommendationsFuture = repo.fetchAIRecommendations();
          });
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: FutureBuilder<Portfolio>(
                future: _portfolioFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('오류: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: Text('데이터가 없습니다.'));
                  }

                  final portfolio = snapshot.data!;
                  return _buildPortfolioHeader(portfolio);
                },
              ),
            ),
            SliverToBoxAdapter(
              child: FutureBuilder<Portfolio>(
                future: _portfolioFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final portfolio = snapshot.data!;
                  return _buildHoldingsList(portfolio.holdings);
                },
              ),
            ),
            SliverToBoxAdapter(
              child: FutureBuilder<List<AIRecommendation>>(
                future: _recommendationsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return _buildAIRecommendations(snapshot.data!);
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioHeader(Portfolio portfolio) {
    final theme = Theme.of(context);
    final isNegative = portfolio.returnRate < 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryColor, softBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatMoney(portfolio.totalValue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isNegative ? Icons.trending_down : Icons.trending_up,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '${isNegative ? '' : '+'}${portfolio.returnRate.toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(width: 12),
              Text(
                '총 수익률',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '자산 총액',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHoldingsList(List<Holding> holdings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.black54),
              SizedBox(width: 4),
              Text('보유 종목', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        ...holdings.map((holding) => _buildHoldingItem(holding)),
      ],
    );
  }

  Widget _buildHoldingItem(Holding holding) {
    final theme = Theme.of(context);
    final isPositive = holding.returnRate >= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                holding.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              Text(
                _formatMoney(holding.currentPrice),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                holding.symbol,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: isPositive ? Colors.red : Colors.blue,
                    size: 16,
                  ),
                  Text(
                    '${holding.returnRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: isPositive ? Colors.red : Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('비중', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.red.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPositive ? '상승' : '하락',
                  style: TextStyle(
                    color: isPositive ? Colors.red : Colors.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: holding.weight,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(
              isPositive ? Colors.red.shade300 : Colors.blue.shade300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIRecommendations(List<AIRecommendation> recommendations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: Colors.black54),
              SizedBox(width: 4),
              Text('AI 추천', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        ...recommendations.map((rec) => _buildRecommendationItem(rec)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('상세 분석'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('리포트 보기'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationItem(AIRecommendation rec) {
    Color actionColor;
    switch (rec.action) {
      case '매수':
        actionColor = Colors.red;
        break;
      case '매도':
        actionColor = Colors.blue;
        break;
      default:
        actionColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: actionColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  rec.action,
                  style: TextStyle(
                    color: actionColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rec.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rec.description,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}