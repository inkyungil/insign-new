import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/data/template_repository.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/features/templates/view/template_pdf_view_screen.dart';
import 'package:insign/features/templates/widgets/template_preview_modal.dart';
import 'package:insign/models/template.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final TemplateRepository _repository = TemplateRepository();

  List<Template> _templates = const [];
  bool _loading = true;
  bool _refreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      if (isRefresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
    });

    try {
      final token = await SessionService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('템플릿을 확인하려면 로그인 후 이용해 주세요.');
      }
      final templates = await _repository.fetchTemplates(token: token);
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _errorMessage = null;
      });
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;
      setState(() {
        _errorMessage = message.isEmpty ? '템플릿을 불러오지 못했습니다.' : message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!), duration: const Duration(seconds: 2)),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  String _subtitleText() {
    if (_loading) {
      return '템플릿을 불러오는 중입니다...';
    }
    if (_templates.isEmpty) {
      return '아직 등록된 템플릿이 없습니다.';
    }
    return '총 ${_templates.length}개의 템플릿을 이용할 수 있어요.';
  }

  String _formatUpdatedAt(DateTime? date) {
    if (date == null) {
      return '업데이트 예정';
    }
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _handlePreview(Template template) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemplatePdfViewScreen(templateId: template.id),
      ),
    );
  }

  void _handleStartWithTemplate(Template template) {
    context.push('/create-contract?templateId=${template.id}');
  }

  @override
  Widget build(BuildContext context) {
    final slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              const Text(
                '템플릿',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => context.push('/inbox'),
                icon: const Icon(Icons.notifications_outlined),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        sliver: SliverToBoxAdapter(
          child: Text(
            _subtitleText(),
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ),
      ),
    ];

    if (_errorMessage != null) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ErrorBanner(message: _errorMessage!, onRetry: () => _loadTemplates()),
          ),
        ),
      );
    }

    if (_loading && _templates.isEmpty) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator(color: primaryColor)),
          ),
        ),
      );
    } else if (_templates.isEmpty) {
      slivers.add(const SliverToBoxAdapter(child: _EmptyState()));
    } else {
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final template = _templates[index];
              return _TemplateCard(
                template: template,
                formattedUpdatedAt: _formatUpdatedAt(template.lastUpdatedAt),
                onPreview: () => _handlePreview(template),
                onCreateWithTemplate: () => _handleStartWithTemplate(template),
              );
            },
            childCount: _templates.length,
          ),
        ),
      );
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 120)));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: primaryColor,
          onRefresh: () => _loadTemplates(isRefresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: slivers,
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final Template template;
  final String formattedUpdatedAt;
  final VoidCallback onPreview;
  final VoidCallback onCreateWithTemplate;

  const _TemplateCard({
    required this.template,
    required this.formattedUpdatedAt,
    required this.onPreview,
    required this.onCreateWithTemplate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14111827),
              blurRadius: 12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x1F4F46E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    template.category,
                    style: const TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '업데이트 $formattedUpdatedAt',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              template.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 8),
            Text(
              template.description,
              style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.4),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;

                final previewButton = SizedBox(
                  width: isNarrow ? double.infinity : null,
                  child: OutlinedButton.icon(
                    onPressed: onPreview,
                    icon: const Icon(Icons.visibility_outlined, color: primaryColor, size: 18),
                    label: const Text('미리보기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: const BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                );

                final createButton = SizedBox(
                  width: isNarrow ? double.infinity : null,
                  child: ElevatedButton.icon(
                    onPressed: onCreateWithTemplate,
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('템플릿으로 작성'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      previewButton,
                      const SizedBox(height: 12),
                      createButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    previewButton,
                    const SizedBox(width: 12),
                    Expanded(child: createButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: const [
          Icon(Icons.description_outlined, size: 32, color: Color(0xFF9CA3AF)),
          SizedBox(height: 8),
          Text(
            '템플릿이 없습니다',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
          ),
          SizedBox(height: 4),
          Text(
            '관리자에게 템플릿 등록을 요청해 보세요.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '템플릿 정보를 불러오지 못했습니다.',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('다시 시도'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFDC2626)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
