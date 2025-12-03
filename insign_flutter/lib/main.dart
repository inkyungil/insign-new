// main.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:insign/core/router/app_router.dart';
import 'package:insign/core/theme/app_theme.dart';
import 'package:insign/data/services/kakao_auth_service.dart';
import 'package:insign/data/services/google_auth_service.dart';
import 'package:insign/features/auth/cubit/auth_cubit.dart';
import 'package:insign/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:insign/services/back_button_service.dart';
import 'package:insign/services/push_notification_service.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'firebase_options.dart';

void main() async {
  // Flutter binding 초기화
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    try {
      usePathUrlStrategy();
    } catch (_) {
      // 이미 설정된 경우 (웹 핫리로드 등) 무시
    }
    // Google Sign-In for Web SDK 초기화
    await GoogleAuthService.ensureInitialized();
  }

  // 카카오 SDK 초기화
  KakaoAuthService.initialize();

  // 백버튼 서비스 초기화
  BackButtonService.initialize(appRouter);

  // Firebase Core 기본 초기화 (안드로이드 값 직접 주입)
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (error) {
    debugPrint('Firebase default init skipped: $error');
  }

  // Firebase Push 초기화
  await PushNotificationService.initialize();
  
  // 개발용 키 해시 출력 (배포 시 제거)
  /// KakaoAuthService.printKeyHash();
  /// KeyHashConverter.printBase64Hash();
  
  // 상태 표시줄 스타일 설정 (흰색 배경에 어두운 아이콘)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(const InsignApp());
}

class InsignApp extends StatelessWidget {
  const InsignApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => OnboardingCubit()..checkStatus()),
        BlocProvider(create: (context) => AuthCubit()..checkSession()),
      ],
      child: MaterialApp.router(
          title: '인싸인',
          theme: AppTheme.lightTheme,
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
          locale: const Locale('ko', 'KR'),
          supportedLocales: const [
            Locale('ko', 'KR'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
    );
  }
}
