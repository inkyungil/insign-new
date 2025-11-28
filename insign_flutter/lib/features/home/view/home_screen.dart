import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/data/auth_repository.dart';
import 'package:insign/data/contract_repository.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/features/auth/cubit/auth_cubit.dart';
import 'package:insign/models/contract.dart';
import 'package:insign/models/user.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ContractRepository _contractRepository = ContractRepository();
  final AuthRepository _authRepository = AuthRepository();
  final DateFormat _dateFormatter = DateFormat('yyyy.MM.dd');

  List<Contract> _contracts = const [];
  bool _loading = false;
  String? _errorMessage;
  DateTime? _lastBackPress;

  // 구독 통계
  User? _userStats;
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadContracts();
    _loadUserStats();
  }

  Future<void> _loadContracts({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      if (!isRefresh) {
        _loading = true;
      }
    });

    try {
      final token = await SessionService.getAccessToken();
      final contracts = await _contractRepository.fetchContracts(token: token);
      if (!mounted) return;
      setState(() {
        _contracts = contracts;
        _errorMessage = null;
      });
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;
      setState(() {
        _errorMessage = message.isEmpty ? '계약 정보를 불러오지 못했습니다.' : message;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadUserStats({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      if (!isRefresh) {
        _loadingStats = true;
      }
    });

    try {
      final token = await SessionService.getAccessToken();
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _loadingStats = false;
        });
        return;
      }

      final stats = await _authRepository.getUserStats(token);
      if (!mounted) return;
      setState(() {
        _userStats = stats;
      });

      // TODO: AuthCubit에 updateUserStats 메서드 추가 필요
      // final authCubit = context.read<AuthCubit>();
      // authCubit.updateUserStats(stats);
    } catch (error) {
      // 통계 로딩 실패는 무시 (중요하지 않음)
      debugPrint('사용자 통계 로딩 실패: $error');
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingStats = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadContracts(isRefresh: true),
      _loadUserStats(isRefresh: true),
    ]);
  }

  Future<bool> _handleBackPressed() async {
    final now = DateTime.now();
    if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('뒤로가기를 한 번 더 누르면 앱이 종료됩니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return false;
    }
    return true;
  }

  List<_ContractStat> _buildStats() {
    final total = _contracts.length;
    final drafts = _contracts.where((c) => c.status == 'draft').length;
    final active = _contracts.where((c) => c.status == 'active').length;
    final completed =
        _contracts.where((c) => c.status == 'signature_completed').length;
    final declined =
        _contracts.where((c) => c.status == 'signature_declined').length;

    return [
      _ContractStat(label: '진행 중', value: active),
      _ContractStat(label: '서명 완료', value: completed),
      _ContractStat(label: '서명 거절', value: declined),
      _ContractStat(label: '작성 중', value: drafts),
    ];
  }

  List<Contract> _recentContracts() {
    final sorted = List<Contract>.from(_contracts);
    sorted.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return sorted.take(5).toList();
  }

  String _mapStatusLabel(String? status) {
    switch (status) {
      case 'draft':
        return '작성 중';
      case 'signature_declined':
        return '서명 거절';
      case 'signature_completed':
        return '서명 완료';
      case 'active':
        return '진행 중';
      case null:
        return '상태 미정';
      default:
        return status;
    }
  }

  String _formatDisplayDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    return _dateFormatter.format(date);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _handleCreateContract() async {
    final result = await context.push('/create-contract');
    // 계약서 작성 후 돌아왔을 때 true가 반환되면 새로고침
    if (result == true && mounted) {
      _loadContracts(isRefresh: true);
    }
  }

  void _handleOpenContractList() {
    context.go('/contracts');
  }

  void _handleOpenContractDetail(int contractId) {
    context.push('/contracts/$contractId');
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final user = authState.user;

    final displayName = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.email?.split('@').first ?? '게스트');

    final welcomeSubtitle = user == null
        ? '로그인하고 계약을 시작해보세요.'
        : '오늘도 안전한 계약을 함께해요! 🎉';

    final email = user?.email;
    final stats = _buildStats();
    final recentContracts = _recentContracts();
    final showEmptyState = !_loading && _contracts.isEmpty;

    return WillPopScope(
      onWillPop: _handleBackPressed,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _refreshAll,
            color: primaryColor,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Text(
                        '인싸인',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => context.push('/inbox'),
                        icon: const Icon(Icons.notifications_outlined),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _HeaderCard(
                      displayName: displayName,
                      email: email,
                      subtitle: welcomeSubtitle,
                  ),
                ),
              ),
              // 구독 통계 위젯
              if (user != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _loadingStats
                        ? const _LoadingCard(message: '사용량 정보를 불러오는 중입니다...')
                        : _SubscriptionStatsCard(userStats: _userStats ?? user),
                  ),
                ),
              if (_errorMessage != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _ErrorCard(
                      message: _errorMessage!,
                      onRetry: () => _loadContracts(isRefresh: true),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _ActionButton(
                      label: '새 계약서 작성',
                      onPressed: _handleCreateContract,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _Section(
                      title: '계약 현황 요약',
                      child: _loading && _contracts.isEmpty
                          ? const _LoadingCard(message: '계약 현황을 불러오는 중입니다...')
                          : _StatsGrid(stats: stats),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _Section(
                      title: '최근 계약',
                      actionLabel: '전체보기',
                      onActionTap: _handleOpenContractList,
                      child: _loading && _contracts.isEmpty
                          ? const _LoadingCard(message: '최근 계약을 불러오는 중입니다...')
                          : showEmptyState
                              ? const _EmptyState()
                              : _ContractList(
                                  contracts: recentContracts,
                                  mapStatusLabel: _mapStatusLabel,
                                  formatDisplayDate: _formatDisplayDate,
                                  onTapContract: _handleOpenContractDetail,
                                ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String displayName;
  final String? email;
  final String subtitle;

  const _HeaderCard({
    required this.displayName,
    required this.email,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, softBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x331F2937),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '안녕하세요',
            style: TextStyle(color: Color(0xFFE0E7FF), fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '$displayName님, 반갑습니다!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (email != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                email!,
                style: const TextStyle(color: Color(0xFFEEF2FF), fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFFE0E7FF), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '계약 정보를 불러오지 못했습니다.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              '다시 시도',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0x3D4F46E5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_outline, color: primaryColor, size: 24),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const _Section({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
            ),
            if (actionLabel != null && onActionTap != null)
              TextButton(
                onPressed: onActionTap,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String message;

  const _LoadingCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1F4F46E5)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final List<_ContractStat> stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final rawWidth = (screenWidth - 40 - 12) / 2;
    final cardWidth = rawWidth.clamp(0.0, double.infinity).toDouble();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stats
          .map(
            (stat) => Container(
              width: cardWidth,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x1F4F46E5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${stat.value}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: primaryColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stat.label,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.description_outlined, size: 26, color: Color(0xFF9CA3AF)),
          SizedBox(height: 12),
          Text(
            '아직 등록된 계약이 없습니다.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
          ),
          SizedBox(height: 6),
          Text(
            '새 계약을 작성하면 이곳에서 최근 내역을 확인할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _ContractList extends StatelessWidget {
  final List<Contract> contracts;
  final String Function(String?) mapStatusLabel;
  final String Function(DateTime?) formatDisplayDate;
  final void Function(int id) onTapContract;

  const _ContractList({
    required this.contracts,
    required this.mapStatusLabel,
    required this.formatDisplayDate,
    required this.onTapContract,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: contracts
          .map(
            (contract) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => onTapContract(contract.id),
                borderRadius: BorderRadius.circular(24),
                child: Ink(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x140F172A),
                        blurRadius: 12,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0x1F4F46E5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.description_outlined, color: primaryColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contract.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatParties(contract),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  mapStatusLabel(contract.status),
                                  style: const TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  formatDisplayDate(contract.updatedAt ?? contract.createdAt),
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  static String _formatParties(Contract contract) {
    final performer = contract.performerName?.isNotEmpty == true ? contract.performerName! : '수행자 미정';
    return '${contract.clientName} ←→ $performer';
  }
}

class _ContractStat {
  final String label;
  final int value;

  const _ContractStat({required this.label, required this.value});
}

class _SubscriptionStatsCard extends StatelessWidget {
  final User userStats;

  const _SubscriptionStatsCard({required this.userStats});

  @override
  Widget build(BuildContext context) {
    final isPremium = userStats.isPremium;
    final contractsUsed = userStats.contractsUsedThisMonth;
    final contractsLimit = userStats.monthlyContractLimit;
    final points = userStats.points;
    final remaining = userStats.remainingFreeContracts;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1F4F46E5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPremium ? const Color(0xFFDCFCE7) : const Color(0xFFDEEBFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPremium ? Icons.star : Icons.account_circle_outlined,
                      size: 16,
                      color: isPremium ? const Color(0xFF16A34A) : primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPremium ? '프리미엄 플랜' : '무료 플랜',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isPremium ? const Color(0xFF16A34A) : primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.emoji_events_outlined,
                size: 20,
                color: points >= 10 ? const Color(0xFFFBBF24) : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 6),
              Text(
                '$points P',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: points >= 10 ? const Color(0xFFF59E0B) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: '이번 달 사용',
                  value: '$contractsUsed',
                  unit: isPremium ? '' : '/$contractsLimit개',
                  icon: Icons.description_outlined,
                  color: primaryColor,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: const Color(0xFFE5E7EB),
              ),
              Expanded(
                child: _StatItem(
                  label: '남은 무료',
                  value: isPremium ? '무제한' : '$remaining개',
                  unit: '',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          if (!isPremium && contractsUsed >= contractsLimit) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFF97316), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      points >= 3
                          ? '포인트 3개로 계약서 1개 더 작성 가능해요'
                          : '출석 체크로 포인트를 모아보세요!',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEA580C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            if (unit.isNotEmpty)
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
