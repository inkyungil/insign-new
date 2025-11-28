// lib/features/auth/view/terms_agreement_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:insign/data/services/terms_agreement_service.dart';
import 'package:insign/features/auth/cubit/auth_cubit.dart';

class TermsAgreementScreen extends StatefulWidget {
  final String? nextRoute; // 다음 이동할 경로
  final String? userEmail; // 사용자 이메일
  final String? tempToken; // 임시 토큰 (Google 로그인 시)

  const TermsAgreementScreen({
    super.key,
    this.nextRoute,
    this.userEmail,
    this.tempToken,
  });

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  bool _allAgreed = false;
  bool _serviceTerms = false;
  bool _privacyPolicy = false;
  bool _sensitiveInfo = false;
  bool _marketing = false;
  bool _isSubmitting = false;

  void _showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.red : const Color(0xFF6A4C93),
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  void _updateAllAgreed() {
    _allAgreed = _serviceTerms && _privacyPolicy && _sensitiveInfo && _marketing;
  }

  void _showTermsDetail(BuildContext context, String title, String type) {
    context.push('/auth/terms-detail', extra: {
      'title': title,
      'type': type,
    });
  }

  Future<void> _handleBackButton(BuildContext context) async {
    // Google 로그인 후 약관 동의 중 뒤로가기 시 로그아웃 처리
    if (widget.tempToken != null && widget.tempToken!.isNotEmpty) {
      await context.read<AuthCubit>().logout();
    }
    if (!mounted) return;
    context.go('/auth/login');
  }

  Future<void> _handleAgree() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Google 로그인 후 약관 동의인 경우 (tempToken이 있는 경우)
      if (widget.tempToken != null && widget.tempToken!.isNotEmpty) {
        // 서버에 약관 동의 정보 전송 및 정식 토큰 받기
        await context.read<AuthCubit>().completeRegistration(
          tempToken: widget.tempToken!,
          agreedToTerms: _serviceTerms,
          agreedToPrivacy: _privacyPolicy,
          agreedToSensitive: _sensitiveInfo,
          agreedToMarketing: _marketing,
        );

        if (!mounted) return;

        // 홈으로 이동
        _showToast('약관 동의가 완료되었습니다.');
        context.go('/home');
      } else {
        // 일반 회원가입 전 약관 동의 (로컬 저장만)
        await TermsAgreementService.saveAgreement(
          serviceTerms: _serviceTerms,
          privacyPolicy: _privacyPolicy,
          sensitiveInfo: _sensitiveInfo,
          marketing: _marketing,
          userEmail: widget.userEmail,
        );

        if (!mounted) return;

        // 회원가입 화면으로 이동
        if (widget.nextRoute != null) {
          context.go(widget.nextRoute!);
        } else {
          context.go('/auth/register');
        }
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      _showToast(message.isEmpty ? '약관 동의 처리에 실패했습니다.' : message, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = _serviceTerms && _privacyPolicy && _sensitiveInfo;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleBackButton(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF111827)),
          onPressed: () => _handleBackButton(context),
        ),
        title: const Text(
          '이용 동의',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 약관 전체 동의
                    _buildAllAgreementTile(),
                    const SizedBox(height: 8),

                    // 개별 약관 항목들
                    _buildTermsTile(
                      title: '[필수] 서비스 이용 약관 동의',
                      value: _serviceTerms,
                      onChanged: (value) {
                        setState(() {
                          _serviceTerms = value;
                          _updateAllAgreed();
                        });
                      },
                      onDetailTap: () => _showTermsDetail(
                        context,
                        '서비스 이용 약관',
                        'service_terms',
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildTermsTile(
                      title: '[필수] 개인정보 수집 이용 동의',
                      value: _privacyPolicy,
                      onChanged: (value) {
                        setState(() {
                          _privacyPolicy = value;
                          _updateAllAgreed();
                        });
                      },
                      onDetailTap: () => _showTermsDetail(
                        context,
                        '개인정보 수집 이용 동의',
                        'privacy_policy',
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildTermsTile(
                      title: '[필수] 민감정보 수집 이용 동의',
                      value: _sensitiveInfo,
                      onChanged: (value) {
                        setState(() {
                          _sensitiveInfo = value;
                          _updateAllAgreed();
                        });
                      },
                      onDetailTap: () => _showTermsDetail(
                        context,
                        '민감정보 수집 이용 동의',
                        'sensitive_info',
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildTermsTile(
                      title: '[선택] 마케팅 활용 동의',
                      value: _marketing,
                      onChanged: (value) {
                        setState(() {
                          _marketing = value;
                          _updateAllAgreed();
                        });
                      },
                      onDetailTap: () => _showTermsDetail(
                        context,
                        '마케팅 활용 동의',
                        'marketing',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 하단 동의 버튼
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (canProceed && !_isSubmitting) ? _handleAgree : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A4C93),
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
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
                      : Text(
                          '동의',
                          style: TextStyle(
                            color: canProceed ? Colors.white : const Color(0xFF94A3B8),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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

  Widget _buildAllAgreementTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _allAgreed = !_allAgreed;
                _serviceTerms = _allAgreed;
                _privacyPolicy = _allAgreed;
                _sensitiveInfo = _allAgreed;
                _marketing = _allAgreed;
              });
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _allAgreed ? const Color(0xFF6A4C93) : Colors.white,
                border: Border.all(
                  color: _allAgreed ? const Color(0xFF6A4C93) : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: _allAgreed
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '약관 전체 동의',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required VoidCallback onDetailTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onChanged(!value),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? const Color(0xFF6A4C93) : Colors.white,
                border: Border.all(
                  color: value ? const Color(0xFF6A4C93) : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF111827),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFF94A3B8),
            ),
            onPressed: onDetailTap,
          ),
        ],
      ),
    );
  }
}
