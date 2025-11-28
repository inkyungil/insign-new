// lib/features/auth/view/login_screen.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/data/services/google_auth_service.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/data/services/terms_agreement_service.dart';
import 'package:insign/features/auth/cubit/auth_cubit.dart';
import 'package:insign/features/auth/widgets/google_web_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _isGoogleLoading = false;
  StreamSubscription<GoogleSignInAccount?>? _googleSignInSubscription;

  @override
  void initState() {
    super.initState();
    // Check if redirected from protected page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = GoRouterState.of(context).uri;
      final fromPath = uri.queryParameters['from'];
      if (fromPath != null && fromPath.isNotEmpty) {
        _showToast('로그인이 필요한 서비스입니다.', isError: true);
      }
    });

    if (kIsWeb) {
      unawaited(GoogleAuthService.ensureInitialized());
      _googleSignInSubscription =
          GoogleAuthService.userChanges.listen(_onGoogleAccountChanged);
    }
  }

  @override
  void dispose() {
    _googleSignInSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.red : const Color(0xFF4A148C),
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  void _showEmailVerificationDialog(BuildContext context, String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이메일 인증 필요'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('이메일 인증이 완료되지 않았습니다.'),
            const SizedBox(height: 12),
            Text(
              '가입 시 $email로 인증 메일이 발송되었습니다.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '메일함을 확인하거나, 인증 메일을 다시 받으시려면 아래 버튼을 눌러주세요.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resendVerificationEmail(email);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
            ),
            child: const Text(
              '인증 메일 재발송',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerificationEmail(String email) async {
    try {
      final message = await context.read<AuthCubit>().resendVerificationEmail(email);
      if (!mounted) return;
      _showToast(message);
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      _showToast(message.isEmpty ? '재발송에 실패했습니다.' : message, isError: true);
    }
  }

  Future<void> _onGoogleAccountChanged(
      GoogleSignInAccount? account) async {
    if (!kIsWeb || account == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (_isGoogleLoading || context.read<AuthCubit>().state.isLoggedIn) {
      return;
    }

    setState(() {
      _isGoogleLoading = true;
    });

    try {
      // Google 로그인 시도
      final success =
          await context.read<AuthCubit>().loginWithGoogle(account: account);

      if (!mounted) {
        return;
      }

      setState(() {
        _isGoogleLoading = false;
      });

      if (!success) {
        _showToast('Google 로그인에 실패했습니다.', isError: true);
        await GoogleAuthService.signOut();
        return;
      }

      final authState = context.read<AuthCubit>().state;
      final user = authState.user;

      // 서버에서 약관 동의가 필요하다고 표시한 경우
      final needsTermsAgreement = user?.agreedToTerms != true ||
                                  user?.agreedToPrivacy != true ||
                                  user?.agreedToSensitive != true;

      if (needsTermsAgreement && user?.email != null) {
        // 약관 동의 필요 - 약관 동의 화면으로 이동
        if (!mounted) return;

        // 현재 임시 토큰을 가져와서 전달
        final tempToken = await SessionService.getAccessToken();

        context.go('/auth/terms-agreement', extra: {
          'nextRoute': '/home',
          'userEmail': user!.email,
          'tempToken': tempToken,
        });
        return;
      }

      // 약관 동의 완료 - 홈으로 이동
      final nickname = user?.displayName ?? user?.email ?? '사용자';
      _showToast('$nickname님, 반갑습니다!');
      context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
      _showToast('Google 로그인에 실패했습니다.', isError: true);
      await GoogleAuthService.signOut();
    }
  }

  Future<void> _handleEmailLogin(BuildContext context) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showToast('이메일과 비밀번호를 모두 입력해주세요.', isError: true);
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await context.read<AuthCubit>().login(
            email: email,
            password: password,
          );

      final displayName = response.user.displayName ?? response.user.email;
      _showToast('$displayName님, 반갑습니다!');

      if (!mounted) {
        return;
      }
      context.go('/home');
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');

      // 이메일 미인증 에러 체크
      if (message.contains('이메일 인증이 필요합니다') || message.contains('이메일 인증')) {
        if (!mounted) return;
        _showEmailVerificationDialog(context, email);
      } else {
        _showToast(message.isEmpty ? '로그인에 실패했습니다.' : message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handleGoogleLogin(BuildContext context) async {
    if (_isGoogleLoading) {
      return;
    }

    setState(() {
      _isGoogleLoading = true;
    });

    try {
      // Google 로그인 시도
      final success = await context.read<AuthCubit>().loginWithGoogle();

      if (!mounted) {
        return;
      }

      setState(() {
        _isGoogleLoading = false;
      });

      if (!success) {
        _showToast('Google 로그인에 실패했습니다.', isError: true);
        return;
      }

      final authState = context.read<AuthCubit>().state;
      final user = authState.user;

      // 서버에서 약관 동의가 필요하다고 표시한 경우
      // (백엔드 응답을 직접 확인할 수 없으므로, user 정보로 판단)
      final needsTermsAgreement = user?.agreedToTerms != true ||
                                  user?.agreedToPrivacy != true ||
                                  user?.agreedToSensitive != true;

      if (needsTermsAgreement && user?.email != null) {
        // 약관 동의 필요 - 약관 동의 화면으로 이동
        if (!mounted) return;

        // 현재 임시 토큰을 가져와서 전달
        final tempToken = await SessionService.getAccessToken();

        context.go('/auth/terms-agreement', extra: {
          'nextRoute': '/home',
          'userEmail': user!.email,
          'tempToken': tempToken,
        });
        return;
      }

      // 약관 동의 완료 - 홈으로 이동
      final nickname = user?.displayName ?? user?.email ?? '사용자';
      _showToast('$nickname님, 반갑습니다!');
      context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
      _showToast('Google 로그인에 실패했습니다.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6A4C93),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A4C93),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.description,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  const Text(
                    '인싸인',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Subtitle
                  const Text(
                    '간편한 전자계약 플랫폼',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '이메일',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'your@email.com',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF6A4C93)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '비밀번호',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        onSubmitted: (_) => _handleEmailLogin(context),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF6A4C93)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : () => _handleEmailLogin(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A4C93),
                        disabledBackgroundColor: const Color(0xFF6A4C93).withOpacity(0.7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              '로그인 하기',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Register link
                  Center(
                    child: TextButton(
                      onPressed: () {
                        context.go('/auth/terms-agreement');
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: RichText(
                        text: const TextSpan(
                          text: '계정이 없으신가요? ',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                          children: [
                            TextSpan(
                              text: '회원가입',
                              style: TextStyle(
                                color: Color(0xFF6A4C93),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '또는',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Google login button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: kIsWeb
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              IgnorePointer(
                                ignoring: _isGoogleLoading,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: googleWebSignInButton(),
                                ),
                              ),
                              if (_isGoogleLoading)
                                const Positioned.fill(
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : OutlinedButton(
                            onPressed: _isGoogleLoading
                                ? null
                                : () => _handleGoogleLogin(context),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isGoogleLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF1F2937),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.g_mobiledata,
                                        size: 24,
                                        color: Colors.red.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Google로 계속하기',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
