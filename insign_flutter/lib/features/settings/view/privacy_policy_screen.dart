import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:insign/core/widgets/custom_app_bar.dart';
import 'package:insign/data/policy_repository.dart';
import 'package:insign/models/policy.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final PolicyRepository _repository = PolicyRepository();
  late Future<Policy?> _future;
  final DateFormat _dateFormat = DateFormat('yyyy년 MM월 dd일');

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchPrivacyPolicy();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _repository.fetchPrivacyPolicy();
    });
  }

  String _formatDate(DateTime? timestamp) {
    if (timestamp == null) {
      return '-';
    }
    return _dateFormat.format(timestamp.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/home');
        }
        return false;
      },
      child: Scaffold(
        appBar: const CustomAppBar(
          title: '개인정보 처리 방침',
        ),
        body: FutureBuilder<Policy?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _ErrorView(
                message: '개인정보 처리방침을 불러오는 중 오류가 발생했습니다.',
                onRetry: _reload,
              );
            }

            final policy = snapshot.data;
            if (policy == null) {
              return _ErrorView(
                message: '등록된 개인정보 처리방침이 없습니다.',
                onRetry: _reload,
              );
            }

            final content = policy.content;
            final isHtml = _looksLikeHtml(content);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    policy.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _MetaChip(label: '업데이트', value: _formatDate(policy.updatedAt)),
                      if (policy.version != null && policy.version!.trim().isNotEmpty)
                        _MetaChip(label: '버전', value: policy.version!),
                    ],
                  ),
                  const SizedBox(height: 24),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: isHtml
                          ? HtmlWidget(
                              content,
                              textStyle: const TextStyle(
                                fontSize: 16,
                                height: 1.6,
                                color: Colors.black87,
                              ),
                            )
                          : SelectableText(
                              content,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.6,
                                color: Colors.black87,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: Colors.grey, size: 32),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetaChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 13,
          color: Colors.blueGrey.shade700,
        ),
      ),
    );
  }
}

bool _looksLikeHtml(String value) {
  return RegExp(r'<[a-z][\s\S]*>', caseSensitive: false).hasMatch(value);
}
