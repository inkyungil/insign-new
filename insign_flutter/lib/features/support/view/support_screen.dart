import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:insign/features/support/cubit/support_cubit.dart';
import 'package:insign/features/support/cubit/support_state.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SupportCubit(),
      child: const _SupportScreenContent(),
    );
  }
}

class _SupportScreenContent extends StatefulWidget {
  const _SupportScreenContent({Key? key}) : super(key: key);

  @override
  State<_SupportScreenContent> createState() => _SupportScreenContentState();
}

class _SupportScreenContentState extends State<_SupportScreenContent> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedCategory = 'other';

  @override
  void dispose() {
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
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
        appBar: AppBar(
          title: const Text('고객센터'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              final router = GoRouter.of(context);
              if (router.canPop()) {
                router.pop();
              } else {
                router.go('/home');
              }
            },
          ),
        ),
      body: BlocConsumer<SupportCubit, SupportState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
            context.read<SupportCubit>().clearMessages();
          }
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: Colors.green,
              ),
            );
            context.read<SupportCubit>().clearMessages();

            // Clear form
            _subjectController.clear();
            _contentController.clear();
            setState(() {
              _selectedCategory = 'other';
            });
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '문의하기',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '궁금하신 사항을 남겨주세요. 확인 후 이메일로 답변드리겠습니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 카테고리 선택
                  const Text(
                    '문의 유형',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'contract', child: Text('계약 관련')),
                      DropdownMenuItem(value: 'payment', child: Text('결제/포인트')),
                      DropdownMenuItem(value: 'account', child: Text('계정/로그인')),
                      DropdownMenuItem(value: 'technical', child: Text('기술 지원')),
                      DropdownMenuItem(value: 'other', child: Text('기타')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // 제목
                  const Text(
                    '제목',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      hintText: '문의 제목을 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '제목을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // 내용
                  const Text(
                    '문의 내용',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _contentController,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: '문의 내용을 자세히 입력해주세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '문의 내용을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // 안내 메시지
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '답변은 등록하신 이메일로 발송됩니다.\n영업일 기준 1-2일 내 답변드립니다.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 제출 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: state.isSubmitting
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                context.read<SupportCubit>().submitInquiry(
                                  category: _selectedCategory,
                                  subject: _subjectController.text.trim(),
                                  content: _contentController.text.trim(),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: state.isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '문의하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}
