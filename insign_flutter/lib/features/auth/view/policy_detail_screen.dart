// lib/features/auth/view/policy_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:insign/data/policy_repository.dart';
import 'package:insign/models/policy.dart';

class PolicyDetailScreen extends StatefulWidget {
  final String policyType;

  const PolicyDetailScreen({super.key, required this.policyType});

  @override
  State<PolicyDetailScreen> createState() => _PolicyDetailScreenState();
}

class _PolicyDetailScreenState extends State<PolicyDetailScreen> {
  final PolicyRepository _policyRepository = PolicyRepository();
  bool _isLoading = true;
  Policy? _policy;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Policy? policy;
      switch (widget.policyType) {
        case 'terms':
          policy = await _policyRepository.fetchTermsOfService();
          break;
        case 'privacy':
          policy = await _policyRepository.fetchPrivacyPolicy();
          break;
        case 'sensitive':
          policy = await _policyRepository.fetchSensitiveInfo();
          break;
        case 'marketing':
          policy = await _policyRepository.fetchMarketing();
          break;
      }

      if (!mounted) return;

      setState(() {
        _policy = policy;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String get _title {
    switch (widget.policyType) {
      case 'terms':
        return '서비스 이용 약관';
      case 'privacy':
        return '개인정보 수집 이용';
      case 'sensitive':
        return '민감정보 수집 이용';
      case 'marketing':
        return '마케팅 활용 동의';
      default:
        return '약관';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF111827)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _title,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text(
                '약관을 불러올 수 없습니다',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadPolicy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A4C93),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  '다시 시도',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_policy == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.description_outlined, size: 64, color: Color(0xFF94A3B8)),
              const SizedBox(height: 16),
              const Text(
                '약관이 없습니다',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '관리자에게 문의해주세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Text(
            _policy!.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),

          // 버전 정보
          if (_policy!.version != null)
            Text(
              '버전: ${_policy!.version}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          const SizedBox(height: 24),

          // 내용
          HtmlWidget(
            _policy!.content,
            textStyle: const TextStyle(
              fontSize: 14,
              color: Color(0xFF374151),
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
