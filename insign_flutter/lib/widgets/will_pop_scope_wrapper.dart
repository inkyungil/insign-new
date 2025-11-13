import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';

class WillPopScopeWrapper extends StatefulWidget {
  final Widget child;
  final Duration doubleTapDuration;
  final String exitMessage;

  const WillPopScopeWrapper({
    super.key,
    required this.child,
    this.doubleTapDuration = const Duration(seconds: 2),
    this.exitMessage = '뒤로가기를 한 번 더 누르면 종료됩니다',
  });

  @override
  State<WillPopScopeWrapper> createState() => _WillPopScopeWrapperState();
}

class _WillPopScopeWrapperState extends State<WillPopScopeWrapper> {
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _handleBackButton(context),
      child: widget.child,
    );
  }

  Future<bool> _handleBackButton(BuildContext context) async {
    final router = GoRouter.of(context);
    final currentLocation = router.routerDelegate.currentConfiguration.uri.toString();
    
    print('🔍 Back pressed - Current location: $currentLocation');
    
    // 메인 탭들 정의
    final mainTabs = ['/home', '/contracts', '/templates', '/inbox', '/profile'];
    final isMainTab = mainTabs.any((tab) => currentLocation.startsWith(tab));

    // 메인 탭에서의 처리
    if (isMainTab) {
      if (currentLocation.startsWith('/home')) {
        // 홈에서는 더블탭으로 앱 종료
        return await _handleDoubleBackPress();
      } else {
        // 다른 메인 탭에서는 홈으로 이동하고 백버튼 동작 차단
        router.go('/home');
        return false;
      }
    }
    
    // 특별한 경로들
    if (currentLocation == '/terms-of-service' || currentLocation == '/privacy-policy') {
      router.go('/profile');
      return false;
    }
    
    if (currentLocation == '/inbox') {
      router.go('/home');
      return false;
    }
    
    // 기타 모든 페이지에서는 이전 페이지로 이동
    if (router.canPop()) {
      router.pop();
      return false;
    } else {
      // 뒤로 갈 수 없으면 홈으로 이동
      router.go('/home');
      return false;
    }
  }

  Future<bool> _handleDoubleBackPress() async {
    final now = DateTime.now();
    
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > widget.doubleTapDuration) {
      // 첫 번째 백버튼 클릭
      _lastBackPressTime = now;
      
      // 토스트 메시지 표시
      Fluttertoast.showToast(
        msg: widget.exitMessage,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      
      return false; // 앱 종료 방지
    } else {
      // 두 번째 백버튼 클릭 (2초 이내) - 앱 종료 허용
      return true;
    }
  }
}
