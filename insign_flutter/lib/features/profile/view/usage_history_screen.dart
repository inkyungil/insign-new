import 'package:flutter/material.dart';
import 'package:insign/data/auth_repository.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/models/usage_history_entry.dart';

class UsageHistoryScreen extends StatefulWidget {
  const UsageHistoryScreen({super.key});

  @override
  State<UsageHistoryScreen> createState() => _UsageHistoryScreenState();
}

class _UsageHistoryScreenState extends State<UsageHistoryScreen> {
  final AuthRepository _authRepository = AuthRepository();
  bool _loading = true;
  String? _error;
  List<UsageHistoryEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _loadUsageHistory();
  }

  Future<void> _loadUsageHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await SessionService.getAccessToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다.');
      }
      final data = await _authRepository.getUsageHistory(token: token, limit: 50);
      if (!mounted) return;
      setState(() {
        _entries = data;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용 내역'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsageHistory,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, size: 36, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadUsageHistory,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_entries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                '아직 사용 내역이 없습니다.',
                style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _UsageHistoryTile(entry: entry);
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: _entries.length,
    );
  }
}

class _UsageHistoryTile extends StatelessWidget {
  final UsageHistoryEntry entry;

  const _UsageHistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    if (entry.isContract) {
      return _buildContractTile(context);
    }
    return _buildPointsTile(context);
  }

  Widget _buildContractTile(BuildContext context) {
    final usedCount = entry.usedCountAfterCreation;
    final limit = entry.contractLimitAtCreation;
    final limitLabel = entry.isUnlimitedPlan
        ? '프리미엄 (무제한)'
        : (limit != null && usedCount != null
            ? '이번 달 ${usedCount}/${limit}개'
            : null);

    return _HistoryCard(
      icon: entry.usedPointsForCreation == true
          ? Icons.monetization_on_outlined
          : Icons.confirmation_number_outlined,
      iconColor: entry.usedPointsForCreation == true
          ? const Color(0xFF6A4C93)
          : const Color(0xFF2563EB),
      title: entry.contractName ?? '계약서',
      subtitle: entry.formattedDate,
      chips: [
        _HistoryChip(
          label: entry.contractUsageLabel,
          backgroundColor: entry.usedPointsForCreation == true
              ? const Color(0xFFF3E8FF)
              : const Color(0xFFE0F2FE),
          textColor: entry.usedPointsForCreation == true
              ? const Color(0xFF6A4C93)
              : const Color(0xFF1D4ED8),
        ),
        if (limitLabel != null)
          _HistoryChip(
            label: limitLabel,
            backgroundColor: const Color(0xFFF8FAFC),
            textColor: const Color(0xFF6B7280),
          ),
      ],
      description: entry.usedPointsForCreation == true
          ? '포인트 잔액이 감소했습니다.'
          : '월 무료 티켓을 1개 사용했습니다.',
    );
  }

  Widget _buildPointsTile(BuildContext context) {
    final isEarn = entry.isPointEarn;
    final icon = isEarn ? Icons.add_circle_outline : Icons.remove_circle_outline;
    final color = isEarn ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final amountLabel = entry.pointsAmountLabel;
    final balance = entry.balanceAfter != null
        ? '잔액 ${entry.balanceAfter}P'
        : null;

    return _HistoryCard(
      icon: icon,
      iconColor: color,
      title: entry.transactionLabel,
      subtitle: entry.formattedDate,
      chips: [
        if (amountLabel.isNotEmpty)
          _HistoryChip(
            label: amountLabel,
            backgroundColor: isEarn
                ? const Color(0xFFE7F9EF)
                : const Color(0xFFFFE4E6),
            textColor: color,
          ),
        if (balance != null)
          _HistoryChip(
            label: balance,
            backgroundColor: const Color(0xFFF3F4F6),
            textColor: const Color(0xFF4B5563),
          ),
      ],
      description: entry.description ?? '포인트 거래가 발생했습니다.',
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<_HistoryChip> chips;
  final String description;

  const _HistoryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x14111827), blurRadius: 12, offset: Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: chips,
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _HistoryChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }
}
