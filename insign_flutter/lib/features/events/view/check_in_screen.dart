import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/data/auth_repository.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/features/auth/cubit/auth_cubit.dart';
import 'package:insign/models/user.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final AuthRepository _authRepository = AuthRepository();
  User? _userStats;
  bool _loadingStats = false;
  bool _checkingIn = false;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
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

      if (!mounted) return;

      if (success) {
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    final userStats = _userStats ?? user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('출석 체크'),
        foregroundColor: const Color(0xFF111827),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadUserStats,
        color: primaryColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            _buildCalendar(userStats),
            const SizedBox(height: 24),
            _buildCheckInCard(userStats),
            const SizedBox(height: 24),
            _buildIntroSection(userStats),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroSection(User? user) {
    final bool canCheckInToday = user?.canCheckInToday ?? true;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x14111827), blurRadius: 12, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: canCheckInToday ? const Color(0xFFE0E7FF) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  canCheckInToday ? Icons.stars : Icons.check_circle,
                  color: canCheckInToday ? primaryColor : Colors.grey.shade500,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canCheckInToday ? '오늘도 출석하고 1포인트 받아가세요!' : '포인트 적립 완료! 내일도 도전하세요',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      canCheckInToday
                          ? '출석 시 즉시 포인트가 적립되고, 이번 달 히스토리에 표시됩니다.'
                          : '다음 출석 가능 시간은 자정 이후입니다. 아래 카드에서 포인트 현황을 확인하세요.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _IntroBullet(text: '하루 1회 출석 시 1포인트 자동 지급'),
                SizedBox(height: 8),
                _IntroBullet(text: '포인트는 계약서 작성 시 바로 사용 가능'),
                SizedBox(height: 8),
                _IntroBullet(text: '이번 달 달력에서 출석 히스토리를 확인'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInCard(User? user) {
    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Color(0x14111827), blurRadius: 12, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.lock_outline, size: 40, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text(
              '로그인이 필요합니다',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '출석 체크는 로그인 후 이용할 수 있어요.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final canCheckIn = user.canCheckInToday;
    final points = user.points;
    final monthlyPointsLimit = user.monthlyPointsLimit;
    final pointsEarnedThisMonth = user.pointsEarnedThisMonth;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryColor, Color(0xFF818CF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '오늘의 출석 체크',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      canCheckIn
                          ? '출석하고 포인트를 받으세요!'
                          : '출석은 완료되었어요. 내일 자정 이후 다시 참여할 수 있어요.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('보유 포인트', '$points P', Icons.emoji_events),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    _buildStatColumn(
                      '이번 달 적립',
                      '$pointsEarnedThisMonth/$monthlyPointsLimit P',
                      Icons.calendar_today,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_checkingIn || !canCheckIn || _loadingStats) ? null : _handleCheckIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryColor,
                      disabledBackgroundColor: Colors.white.withOpacity(0.3),
                      disabledForegroundColor: Colors.white.withOpacity(0.7),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _checkingIn
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                canCheckIn ? Icons.check_circle : Icons.check_circle_outline,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                canCheckIn ? '출석 체크 하기' : '오늘 출석 완료!',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                  ),
                ),
                if (!canCheckIn)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '내일 다시 출석해주세요 ✨',
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildCalendar(User? user) {
    final today = DateTime.now();
    final firstDay = DateTime(today.year, today.month, 1);
    final totalDays = DateUtils.getDaysInMonth(today.year, today.month);
    final leadingGap = (firstDay.weekday + 6) % 7; // Monday as first column
    final totalCells = ((leadingGap + totalDays + 6) ~/ 7) * 7;
    final lastCheckIn = user?.lastCheckInDate != null ? DateTime.tryParse(user!.lastCheckInDate!) : null;

    final cells = List<DateTime?>.generate(totalCells, (index) {
      if (index < leadingGap) return null;
      final day = index - leadingGap + 1;
      if (day > totalDays) return null;
      return DateTime(today.year, today.month, day);
    });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x14111827), blurRadius: 12, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '이번 달 출석 캘린더',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
              ),
              Text(
                '${today.year}.${today.month.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _WeekdayLabel('월'),
              _WeekdayLabel('화'),
              _WeekdayLabel('수'),
              _WeekdayLabel('목'),
              _WeekdayLabel('금'),
              _WeekdayLabel('토'),
              _WeekdayLabel('일'),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: cells.length,
            itemBuilder: (context, index) {
              return _CalendarCell(
                date: cells[index],
                today: today,
                lastCheckIn: lastCheckIn,
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: const [
              _LegendDot(color: primaryColor, label: '출석 완료'),
              _LegendDot(color: Color(0xFFE0E7FF), label: '오늘'),
              _LegendDot(color: Color(0xFFF3F4F6), label: '대기 중'),
            ],
          ),
          if (user?.lastCheckInDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '마지막 출석일: ${user!.lastCheckInDate!.split('T').first}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ),
        ],
      ),
    );
  }
}

class _IntroBullet extends StatelessWidget {
  final String text;

  const _IntroBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(color: Color(0xFFE0E7FF), shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 14, color: primaryColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
          ),
        ),
      ],
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String text;

  const _WeekdayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}

class _CalendarCell extends StatelessWidget {
  final DateTime? date;
  final DateTime today;
  final DateTime? lastCheckIn;

  const _CalendarCell({
    required this.date,
    required this.today,
    required this.lastCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return const SizedBox.shrink();
    }

    final bool isToday = DateUtils.isSameDay(date, today);
    final bool isCheckedIn = lastCheckIn != null && DateUtils.isSameDay(date, lastCheckIn);

    Color backgroundColor;
    Color textColor;
    FontWeight fontWeight = FontWeight.w600;

    if (isCheckedIn) {
      backgroundColor = primaryColor;
      textColor = Colors.white;
    } else if (isToday) {
      backgroundColor = const Color(0xFFE0E7FF);
      textColor = primaryColor;
    } else if (date!.isBefore(today)) {
      backgroundColor = const Color(0xFFF3F4F6);
      textColor = const Color(0xFF6B7280);
      fontWeight = FontWeight.w500;
    } else {
      backgroundColor = const Color(0xFFFFFFFF);
      textColor = const Color(0xFF94A3B8);
      fontWeight = FontWeight.w500;
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCheckedIn ? Colors.transparent : const Color(0xFFE2E8F0),
        ),
      ),
      child: Center(
        child: Text(
          date!.day.toString(),
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }
}
