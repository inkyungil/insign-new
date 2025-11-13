// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:insign/app.dart';
import 'package:insign/features/auth/cubit/auth_cubit.dart';
import 'package:insign/features/auth/view/login_screen.dart';
import 'package:insign/features/auth/view/register_screen.dart';
import 'package:insign/features/home/view/home_screen.dart';
import 'package:insign/features/contracts/view/contracts_screen.dart';
import 'package:insign/features/contracts/view/create_contract_screen.dart';
import 'package:insign/features/contracts/view/contract_detail_screen.dart';
import 'package:insign/features/contracts/view/contract_sign_screen.dart';
import 'package:insign/features/podcast/view/now_playing_screen.dart';
import 'package:insign/features/templates/view/templates_screen.dart';
import 'package:insign/features/profile/view/profile_screen.dart';
import 'package:insign/features/profile/view/member_info_screen.dart';
import 'package:insign/features/settings/view/settings_screen.dart';
import 'package:insign/features/settings/view/inbox_screen.dart';
import 'package:insign/features/settings/view/notification_settings_screen.dart';
import 'package:insign/features/settings/view/privacy_policy_screen.dart';
import 'package:insign/features/settings/view/terms_of_service_screen.dart';
import 'package:insign/features/splash/view/splash_screen.dart';
import 'package:insign/features/onboarding/view/onboarding_screen.dart';
import 'package:insign/features/onboarding/cubit/onboarding_cubit.dart';

// private navigators
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  initialLocation: '/splash', // Start with splash screen
  navigatorKey: _rootNavigatorKey,
  redirect: (context, state) {
    final authState = context.read<AuthCubit>().state;
    if (!authState.isSessionChecked) {
      return null;
    }

    final onboardingState = context.read<OnboardingCubit>().state;
    if (!onboardingState.isChecked) {
      return null;
    }

    final isLoggedIn = authState.isLoggedIn;
    final currentPath = state.uri.path;

    // 인증이 필요 없는 페이지 목록
    final publicPaths = [
      '/splash',
      '/auth/login',
      '/auth/register',
      '/privacy-policy',
      '/terms-of-service',
      '/sign',
      '/onboarding',
    ];

    // 현재 경로가 공개 페이지인지 확인
    final isPublicPath = publicPaths.any(
      (path) => currentPath == path || currentPath.startsWith('$path/'),
    );

    final onboardingCompleted = onboardingState.isCompleted;
    final isSignPath = currentPath.startsWith('/sign');

    if (!onboardingCompleted && currentPath != '/onboarding' && !isSignPath) {
      return '/onboarding';
    }

    if (onboardingCompleted && currentPath == '/onboarding') {
      return isLoggedIn ? '/home' : '/auth/login';
    }

    // 로그인 안 되어 있고, 공개 페이지가 아니면 로그인 페이지로 리다이렉트
    if (!isLoggedIn && !isPublicPath) {
      return '/auth/login?from=${Uri.encodeComponent(currentPath)}';
    }

    // 로그인 되어 있는데 로그인/회원가입 페이지에 있으면 홈으로 리다이렉트
    if (isLoggedIn && (currentPath == '/auth/login' || currentPath == '/auth/register')) {
      return '/home';
    }

    return null; // 리다이렉트 없음
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return AppShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/contracts',
          pageBuilder: (context, state) => const NoTransitionPage(child: ContractsScreen()),
        ),
        GoRoute(
          path: '/templates',
          pageBuilder: (context, state) => const NoTransitionPage(child: TemplatesScreen()),
        ),
        GoRoute(
          path: '/inbox',
          pageBuilder: (context, state) => const NoTransitionPage(child: InboxScreen()),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/now_playing',
      pageBuilder: (context, state) {
        return const MaterialPage(
          fullscreenDialog: true,
          child: NowPlayingScreen(),
        );
      },
    ),
    GoRoute(
      path: '/create-contract',
      builder: (context, state) {
        final templateIdParam = state.uri.queryParameters['templateId'];
        final templateId = templateIdParam != null ? int.tryParse(templateIdParam) : null;
        return CreateContractScreen(templateId: templateId);
      },
    ),
    GoRoute(
      path: '/contracts/:id',
      builder: (context, state) {
        final idParam = state.pathParameters['id'];
        final contractId = idParam != null ? int.tryParse(idParam) : null;
        if (contractId == null) {
          return const Scaffold(
            body: Center(child: Text('잘못된 계약 번호입니다.')),
          );
        }
        return ContractDetailScreen(contractId: contractId);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/notifications',
      builder: (context, state) => const NotificationSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/member-info',
      builder: (context, state) => const MemberInfoScreen(),
    ),
    GoRoute(
      path: '/auth/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/auth/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/sign/:token',
      builder: (context, state) {
        final token = state.pathParameters['token'];
        if (token == null || token.trim().isEmpty) {
          return const Scaffold(
            body: Center(child: Text('유효하지 않은 서명 링크입니다.')),
          );
        }
        return ContractSignScreen(signatureToken: token);
      },
    ),
    GoRoute(
      path: '/privacy-policy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/terms-of-service',
      builder: (context, state) => const TermsOfServiceScreen(),
    ),
  ],
);
