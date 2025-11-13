import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

class BackButtonService {
  static const MethodChannel _channel = MethodChannel('app.back_button');
  static GoRouter? _router;
  
  static void initialize(GoRouter router) {
    _router = router;
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onBackPressed':
        return await _handleBackPressed();
      default:
        return false;
    }
  }
  
  static Future<bool> _handleBackPressed() async {
    if (_router == null) return false;
    
    final currentLocation = _router!.routerDelegate.currentConfiguration.uri.toString();
    print('🔍 Native Back pressed - Current location: $currentLocation');
    
    // 메인 탭들 정의
    final mainTabs = ['/home', '/contracts', '/templates', '/inbox', '/profile'];
    final isMainTab = mainTabs.any((tab) => currentLocation.startsWith(tab));

    // 메인 탭에서의 처리
    if (isMainTab) {
      if (currentLocation.startsWith('/home')) {
        // 홈에서는 네이티브에서 더블탭 처리하도록 false 반환
        return false;
      } else {
        // 다른 메인 탭에서는 홈으로 이동
        _router!.go('/home');
        return true; // Flutter에서 처리했음을 알림
      }
    }
    
    // 특별한 경로들
    if (currentLocation == '/terms-of-service' || currentLocation == '/privacy-policy') {
      _router!.go('/profile');
      return true;
    }
    
    if (currentLocation == '/inbox') {
      _router!.go('/home');
      return true;
    }
    
    // 기타 모든 페이지에서는 이전 페이지로 이동
    if (_router!.canPop()) {
      _router!.pop();
      return true;
    } else {
      // 뒤로 갈 수 없으면 홈으로 이동
      _router!.go('/home');
      return true;
    }
  }
}
