import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:insign/core/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideUpAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    ));

    _slideUpAnimation = Tween<double>(
      begin: 0.0,
      end: -400.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    ));

    _animationController.forward();

    // 4초 후 홈 화면으로 이동
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
              Color(0xFF6A4C93),
              Color(0xFF4A148C),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Background stars with twinkling animation
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Stack(
                    children: [
                      Positioned(top: 60, left: 80, child: _buildAnimatedStar(8, 0.2)),
                      Positioned(top: 120, right: 100, child: _buildAnimatedCross(12, 0.4)),
                      Positioned(top: 200, left: 120, child: _buildAnimatedCross(10, 0.6)),
                      Positioned(top: 280, right: 60, child: _buildAnimatedStar(6, 0.8)),
                      Positioned(bottom: 200, left: 50, child: _buildAnimatedStar(8, 0.3)),
                      Positioned(bottom: 120, right: 120, child: _buildAnimatedCross(10, 0.7)),
                      Positioned(bottom: 300, right: 200, child: _buildAnimatedStar(6, 0.5)),
                      Positioned(top: 340, left: 40, child: _buildAnimatedStar(7, 0.9)),
                    ],
                  );
                },
              ),

              // Main content
              Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: Transform.translate(
                        offset: Offset(0, _slideUpAnimation.value),
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Rocket illustration
                              SizedBox(
                                width: 200,
                                height: 280,
                                child: Image.asset(
                                  'assets/images/splash_main.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 60),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom text
              Positioned(
                bottom: 120,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
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
                          '"이거 지금 사도 될까?" 투자의\n결정적 순간, AI가 답하다',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildCross(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: CrossPainter(),
      ),
    );
  }

  Widget _buildAnimatedStar(double size, double delay) {
    final twinkleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(delay, delay + 0.5 > 1.0 ? 1.0 : delay + 0.5, curve: Curves.easeInOut),
    ));
    
    return AnimatedBuilder(
      animation: twinkleAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: twinkleAnimation.value,
          child: _buildStar(size),
        );
      },
    );
  }

  Widget _buildAnimatedCross(double size, double delay) {
    final twinkleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(delay, delay + 0.5 > 1.0 ? 1.0 : delay + 0.5, curve: Curves.easeInOut),
    ));
    
    return AnimatedBuilder(
      animation: twinkleAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: twinkleAnimation.value,
          child: _buildCross(size),
        );
      },
    );
  }
}

class CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    // Horizontal line
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      paint,
    );

    // Vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

