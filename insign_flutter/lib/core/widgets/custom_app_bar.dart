import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final bool showBackButton;
  final bool showCloseButton;
  final bool showTitle;

  const CustomAppBar({
    super.key,
    required this.title,
    this.onBackPressed,
    this.actions,
    this.showBackButton = true,
    this.showCloseButton = false,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: showTitle
          ? Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            )
          : null,
      centerTitle: showTitle,
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: Colors.black87,
      leading: showCloseButton
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.pop(),
            )
          : showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: onBackPressed ?? () => _handleBackNavigation(context),
                )
              : null,
      actions: actions,
    );
  }

  void _handleBackNavigation(BuildContext context) {
    // 현재 라우트 위치 확인
    final currentLocation = GoRouterState.of(context).uri.toString();
    
    // 현재 위치에 따른 뒤로 가기 로직
    switch (currentLocation) {
      case '/privacy-policy':
        // 개인정보 처리 방침에서 뒤로 가기 → 마이 페이지로 이동
        context.go('/profile');
        break;
      case '/terms-of-service':
        // 이용약관에서 뒤로 가기 → 마이 페이지로 이동
        context.go('/profile');
        break;
      case '/broker-account-register':
        // 증권사 계좌 등록에서 뒤로 가기 → 계좌 등록으로 이동
        context.go('/account-register');
        break;
      case '/coin-exchange-select':
        // 코인 거래소 선택에서 뒤로 가기 → 계좌 등록으로 이동
        context.go('/account-register');
        break;
      case '/coin-account-register':
        // 코인 계좌 등록에서 뒤로 가기 → 코인 거래소 선택으로 이동
        context.go('/coin-exchange-select');
        break;
      case '/survey':
        // 설문조사에서 뒤로 가기 → 홈으로 이동
        context.go('/home');
        break;
      case '/ai-analysis':
        // AI 분석에서 뒤로 가기 → 설문조사로 이동
        context.go('/survey');
        break;
      case '/investment-report':
        // 투자 보고서에서 뒤로 가기 → AI 분석으로 이동
        context.go('/ai-analysis');
        break;
      case '/auto-trading':
        // 자동매매에서 뒤로 가기 → 투자 보고서로 이동
        context.go('/investment-report');
        break;
      case '/settings':
        // 설정에서 뒤로 가기 → 홈으로 이동
        context.go('/home');
        break;
      default:
        // 기본적으로 홈으로 이동
        context.go('/home');
        break;
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
