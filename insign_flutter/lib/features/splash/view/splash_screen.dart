import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/data/app_update_repository.dart';
import 'package:insign/features/auth/cubit/auth_cubit.dart';
import 'package:insign/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:insign/models/app_update_info.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AppUpdateRepository _appUpdateRepository = const AppUpdateRepository();
  _ForceUpdateData? _forceUpdateData;
  bool _navigationScheduled = false;

  @override
  void initState() {
    super.initState();
    _checkForceUpdate();
  }

  @override
  Widget build(BuildContext context) {
    if (_forceUpdateData != null) {
      return _ForceUpdateView(data: _forceUpdateData!);
    }

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
    await Future.delayed(const Duration(seconds: 4));
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

  Future<void> _checkForceUpdate() async {
    try {
      final updateInfo = await _appUpdateRepository.fetchUpdateInfo();
      final targetPlatform = defaultTargetPlatform;
      final platformInfo = updateInfo.forPlatform(targetPlatform);
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final needsForceUpdate =
          platformInfo.requiresForceUpdate(currentVersion.trim());

      if (needsForceUpdate) {
        if (!mounted) return;
        setState(() {
          _forceUpdateData = _ForceUpdateData(
            platformInfo: platformInfo,
            message: updateInfo.message,
            currentVersion: currentVersion,
          );
        });
        return;
      }
    } catch (error) {
      debugPrint('앱 업데이트 확인 중 오류 발생: $error');
    }

    if (!mounted) return;
    await _scheduleNavigation();
  }
}

class _ForceUpdateData {
  const _ForceUpdateData({
    required this.platformInfo,
    required this.message,
    required this.currentVersion,
  });

  final PlatformUpdateInfo platformInfo;
  final String message;
  final String currentVersion;
}

class _ForceUpdateView extends StatelessWidget {
  const _ForceUpdateView({required this.data});

  final _ForceUpdateData data;

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final storeLabel = platform == TargetPlatform.iOS ? 'App Store' : 'Play 스토어';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.system_update_alt,
                size: 72,
                color: primaryColor,
              ),
              const SizedBox(height: 16),
              const Text(
                '최신 버전 업데이트 필요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                data.message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              _VersionInfoRow(
                label: '현재 버전',
                value: data.currentVersion,
              ),
              _VersionInfoRow(
                label: '최소 지원 버전',
                value: data.platformInfo.minimumSupportedVersion,
              ),
              _VersionInfoRow(
                label: '최신 버전',
                value: data.platformInfo.latestVersion,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => _openStore(context, data.platformInfo.storeUrl),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: primaryColor,
                ),
                child: Text('$storeLabel 로 이동'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStore(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showError(context, '스토어 링크가 올바르지 않습니다.');
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      _showError(context, '스토어를 열 수 없습니다. 브라우저에서 직접 업데이트해 주세요.');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _VersionInfoRow extends StatelessWidget {
  const _VersionInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
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
