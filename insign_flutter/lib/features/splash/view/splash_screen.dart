import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/features/auth/cubit/auth_cubit.dart';
import 'package:insign/features/onboarding/cubit/onboarding_cubit.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigationScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleNavigation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor,
              softBlue,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Static decorative stars
              Positioned(top: 60, left: 80, child: _Star(size: 8)),
              Positioned(top: 120, right: 100, child: _Cross(size: 12)),
              Positioned(top: 200, left: 120, child: _Cross(size: 10)),
              Positioned(top: 280, right: 60, child: _Star(size: 6)),
              Positioned(bottom: 200, left: 50, child: _Star(size: 8)),
              Positioned(bottom: 120, right: 120, child: _Cross(size: 10)),
              Positioned(bottom: 300, right: 200, child: _Star(size: 6)),
              Positioned(top: 340, left: 40, child: _Star(size: 7)),

              // Main content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: Image.asset(
                          'assets/images/splash_main_new.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),

              // Bottom text
              Positioned(
                bottom: 120,
                left: 0,
                right: 0,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 60),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF30186D),
                  ),
                  child: const Text(
                    '디지털 계약서 관리 및\n전자서명 솔루션',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scheduleNavigation() async {
    if (_navigationScheduled) return;
    _navigationScheduled = true;
    await Future.delayed(const Duration(seconds: 2));
    final navigator = Navigator.of(context);
    if (!navigator.mounted) return;

    final onboardingCubit = navigator.context.read<OnboardingCubit>();
    var onboardingState = onboardingCubit.state;
    if (!onboardingState.isChecked) {
      onboardingState = await onboardingCubit.stream.firstWhere((state) => state.isChecked);
      if (!navigator.mounted) return;
    }

    if (!onboardingState.isCompleted) {
      navigator.context.go('/onboarding');
      return;
    }

    final authCubit = navigator.context.read<AuthCubit>();
    var authState = authCubit.state;
    if (!authState.isSessionChecked) {
      authState = await authCubit.stream.firstWhere((state) => state.isSessionChecked);
      if (!navigator.mounted) return;
    }

    navigator.context.go(authState.isLoggedIn ? '/home' : '/auth/login');
  }
}

class _Star extends StatelessWidget {
  final double size;

  const _Star({required this.size});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _Cross extends StatelessWidget {
  final double size;

  const _Cross({required this.size});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CrossPainter(),
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
