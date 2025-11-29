import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/data/auth_repository.dart';
import 'package:insign/data/contract_repository.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/features/auth/cubit/auth_cubit.dart';
import 'package:insign/models/contract.dart';
import 'package:insign/models/user.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ContractRepository _contractRepository = ContractRepository();
  final AuthRepository _authRepository = AuthRepository();
  final DateFormat _dateFormatter = DateFormat('yyyy.MM.dd');

  List<Contract> _contracts = const [];
  bool _loadingContracts = true;
  bool _loggingOut = false;
  bool _isWithdrawing = false;
  String? _errorMessage;

  // 구독 통계
  User? _userStats;
  bool _loadingStats = false;
  bool _checkingIn = false;

  @override
  void initState() {
    super.initState();
    _loadContracts();
    _loadUserStats();
  }

  Future<void> _loadContracts() async {
    setState(() {
      _loadingContracts = true;
      _errorMessage = null;
    });

    try {
      final token = await SessionService.getAccessToken();
      final contracts = await _contractRepository.fetchContracts(token: token);
      if (!mounted) return;
      setState(() {
        _contracts = contracts;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _errorMessage = message.isEmpty ? '계약 정보를 불러오지 못했습니다.' : message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!), duration: const Duration(seconds: 2)),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingContracts = false;
      });
    }
  }

  int get _totalContracts => _contracts.length;

  int get _monthlyContracts {
    final now = DateTime.now();
    return _contracts.where((contract) {
      final created = contract.createdAt;
      if (created == null) {
        return false;
      }
      return created.year == now.year && created.month == now.month;
    }).length;
  }

  Future<void> _loadUserStats() async {
    setState(() {
      _loadingStats = true;
    });

    try {
      final token = await SessionService.getAccessToken();
      if (token == null) {
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
    } catch (error) {
      debugPrint('사용자 통계 로딩 실패: $error');
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingStats = false;
      });
    }
  }

  Future<void> _handleCheckIn() async {
    if (_checkingIn) return;

    setState(() {
      _checkingIn = true;
    });

    try {
      final token = await SessionService.getAccessToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final result = await _authRepository.checkIn(token);
      final success = result['success'] as bool? ?? false;
      final message = result['message'] as String? ?? '출석 체크 완료!';
      final points = result['points'] as int?;

      if (!mounted) return;

      if (success) {
        // 성공 시 통계 새로고침
        await _loadUserStats();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isEmpty ? '출석 체크 중 오류가 발생했습니다' : message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _checkingIn = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadContracts(),
      _loadUserStats(),
    ]);
  }

  void _handleSettingTap(String key) {
    switch (key) {
      case 'member':
        context.push('/settings/member-info');
        break;
      case 'notifications':
        context.push('/settings/notifications');
        break;
      case 'usage-history':
        context.push('/profile/usage-history');
        break;
      case 'privacy':
        context.go('/privacy-policy');
        break;
      case 'terms':
        context.go('/terms-of-service');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('해당 항목은 준비 중입니다.'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  Future<void> _handleWithdrawal() async {
    if (_isWithdrawing) {
      return;
    }

    final authState = context.read<AuthCubit>().state;
    final requiresPassword = authState.user?.provider == 'local';

    final dialogResult = await _showWithdrawalDialog(requiresPassword: requiresPassword);
    if (dialogResult == null) {
      return;
    }

    final password = requiresPassword ? dialogResult : null;

    setState(() {
      _isWithdrawing = true;
    });

    try {
      await context.read<AuthCubit>().deleteAccount(password: password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('회원 탈퇴가 완료되었습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isEmpty ? '회원 탈퇴 중 오류가 발생했습니다.' : message),
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {
        _isWithdrawing = false;
      });
    }
  }

  Future<String?> _showWithdrawalDialog({required bool requiresPassword}) {
    final passwordController = TextEditingController();
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('회원 탈퇴'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '계정을 완전히 삭제하시겠습니까? 되돌릴 수 없습니다.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              if (requiresPassword)
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '비밀번호 확인',
                    hintText: '비밀번호를 입력하세요',
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                if (requiresPassword && passwordController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('비밀번호를 입력해 주세요.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(passwordController.text.trim());
              },
              child: const Text(
                '탈퇴',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x14111827), blurRadius: 12, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('내 정보'),
          _buildSettingTile(
            title: '회원 정보',
            onTap: () => _handleSettingTap('member'),
          ),
          _buildInnerDivider(),
          _buildSettingTile(
            title: '알림 설정',
            onTap: () => _handleSettingTap('notifications'),
          ),
          const SizedBox(height: 12),
          _buildSectionHeader('사용 내역'),
          _buildSettingTile(
            title: '계약 · 포인트 사용 내역',
            onTap: () => _handleSettingTap('usage-history'),
          ),
          const SizedBox(height: 12),
          _buildSectionHeader('서비스'),
          _buildSettingTile(
            title: '개인정보 처리 방침',
            onTap: () => _handleSettingTap('privacy'),
          ),
          _buildInnerDivider(),
          _buildSettingTile(
            title: '이용약관',
            onTap: () => _handleSettingTap('terms'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF9CA3AF),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      trailing: trailing ?? Icon(
        Icons.chevron_right,
        color: Colors.grey.shade300,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _buildInnerDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade200,
      indent: 20,
      endIndent: 20,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;

    final slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              const Text(
                '마이',
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        sliver: SliverToBoxAdapter(
          child: const Text(
            '내 정보와 설정을 관리할 수 있어요.',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileCard(user?.displayName ?? '-', user?.email ?? '-'),
              const SizedBox(height: 20),
              _buildStatsCard(),
              const SizedBox(height: 20),
              if (user != null) _buildSubscriptionCard(user),
              if (user != null) const SizedBox(height: 20),
              _buildSettingsCard(),
              const SizedBox(height: 20),
              _buildDangerZone(),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: primaryColor,
          onRefresh: _refreshAll,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: slivers,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(String name, String email) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x14111827), blurRadius: 12, offset: Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified_user, color: primaryColor, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x14111827), blurRadius: 12, offset: Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '계약 현황',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('총 계약', _totalContracts.toString()),
              _buildStatItem('이번 달 계약', _monthlyContracts.toString()),
            ],
          ),
          if (_loadingContracts)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSubscriptionCard(User user) {
    final userStats = _userStats ?? user;
    final isPremium = userStats.isPremium;
    final contractsUsed = userStats.contractsUsedThisMonth;
    final contractsLimit = userStats.monthlyContractLimit;
    final points = userStats.points;
    final remaining = userStats.remainingFreeContracts;
    final canCheckIn = userStats.canCheckInToday;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x14111827), blurRadius: 12, offset: Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '구독 정보',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isPremium ? const Color(0xFFDCFCE7) : const Color(0xFFDEEBFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isPremium ? '프리미엄' : '무료',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPremium ? const Color(0xFF16A34A) : primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow('이번 달 사용', '$contractsUsed / $contractsLimit개'),
          const SizedBox(height: 12),
          _buildInfoRow('남은 무료', isPremium ? '무제한' : '$remaining개'),
          const SizedBox(height: 12),
          _buildInfoRow('보유 포인트', '$points P'),
          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                '출석 체크',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: (_checkingIn || !canCheckIn || _loadingStats) ? null : _handleCheckIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canCheckIn ? primaryColor : Colors.grey.shade300,
                  foregroundColor: canCheckIn ? Colors.white : Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _checkingIn
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        canCheckIn ? '출석 체크' : '완료',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
          if (!canCheckIn)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '오늘은 이미 출석했습니다 ✅',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          if (canCheckIn)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '매일 출석하면 1포인트를 받을 수 있어요!',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x14111827), blurRadius: 12, offset: Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '계정 관리',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loggingOut
                ? null
                : () async {
                    setState(() {
                      _loggingOut = true;
                    });
                    await context.read<AuthCubit>().logout();
                    if (!mounted) return;
                    setState(() {
                      _loggingOut = false;
                    });
                    context.go('/login');
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _loggingOut
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    '로그아웃',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isWithdrawing ? null : _handleWithdrawal,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isWithdrawing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '회원 탈퇴',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }
}
