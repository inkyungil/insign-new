import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/data/template_repository.dart';
import 'package:insign/models/template.dart';
import 'package:insign/models/template_form.dart';
import 'package:printing/printing.dart';

Future<void> showTemplatePreviewModal(BuildContext context, Template template) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) {
      return _TemplatePreviewModalContent(template: template);
    },
  );
}

class _TemplatePreviewModalContent extends StatefulWidget {
  final Template template;

  const _TemplatePreviewModalContent({required this.template});

  @override
  State<_TemplatePreviewModalContent> createState() => _TemplatePreviewModalContentState();
}

class _TemplatePreviewModalContentState extends State<_TemplatePreviewModalContent> {
  static final RegExp _placeholderPattern = RegExp(r'{{\s*([^}]+)\s*}}');
  static final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');

  final TemplateRepository _repository = TemplateRepository();

  Uint8List? _pdfBytes;
  bool _loadingPdf = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _loadingPdf = true;
      _errorMessage = null;
    });

    try {
      final token = await SessionService.getAccessToken();
      final bytes = await _repository.previewTemplatePdf(
        id: widget.template.id,
        token: token,
      );

      if (!mounted) return;
      setState(() {
        _pdfBytes = bytes;
        _loadingPdf = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _loadingPdf = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final template = widget.template;
    final formattedUpdatedAt = _formatUpdatedAt(template.lastUpdatedAt);
    final schemaSummary = _SchemaSummary.fromTemplate(template);
    final renderedHtml = _renderTemplateHtml(template);
    final hasRenderedHtml = renderedHtml != null && renderedHtml.trim().isNotEmpty;

    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: mediaQuery.viewInsets.bottom + 12,
        ),
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: mediaQuery.size.height * 0.85,
          ),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${template.category} · 업데이트 $formattedUpdatedAt',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Color(0xFF475569)),
                        tooltip: '닫기',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: _buildBody(
                    hasRenderedHtml: hasRenderedHtml,
                    renderedHtml: renderedHtml,
                    schemaSummary: schemaSummary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('닫기'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required bool hasRenderedHtml,
    required String? renderedHtml,
    required _SchemaSummary schemaSummary,
  }) {
    if (_loadingPdf) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    if (_pdfBytes != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PdfPreview(
                build: (format) => _pdfBytes!,
                allowPrinting: false,
                allowSharing: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
              ),
            ),
            if (schemaSummary.available) ...[
              const SizedBox(height: 16),
              _SchemaDetails(summary: schemaSummary),
            ],
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PDF 미리보기를 불러오지 못했습니다.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loadPdf,
                      child: const Text(
                        '다시 시도',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hasRenderedHtml && renderedHtml != null)
            HtmlWidget(
              renderedHtml,
              textStyle: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Color(0xFF1F2937),
              ),
              renderMode: RenderMode.column,
              customStylesBuilder: (element) {
                if (element.localName == 'table') {
                  return {'width': '100%', 'table-layout': 'fixed'};
                }
                if (element.localName == 'th' || element.localName == 'td') {
                  return {'word-wrap': 'break-word'};
                }
                return null;
              },
            )
          else
            const Text(
              '템플릿 본문이 등록되지 않았습니다.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF1F2937)),
            ),
          if (schemaSummary.available) ...[
            const SizedBox(height: 24),
            _SchemaDetails(summary: schemaSummary),
          ],
        ],
      ),
    );
  }

  String _formatUpdatedAt(DateTime? date) {
    if (date == null) {
      return '업데이트 예정';
    }
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  String? _renderTemplateHtml(Template template) {
    final raw = template.content;
    if (raw.trim().isEmpty) {
      return null;
    }

    final values = _buildPlaceholderValues(template);
    final replaced = _replacePlaceholders(raw, values);
    return replaced.trim();
  }

  Map<String, String> _buildPlaceholderValues(Template template) {
    final result = <String, String>{};

    void assign(String key, dynamic value) {
      if (key.isEmpty) {
        return;
      }
      final normalized = _normalizePlaceholderValue(value);
      if (normalized == null || normalized.isEmpty) {
        return;
      }
      result[key] = normalized;
    }

    final sample = template.samplePayload;
    if (sample != null) {
      sample.forEach((key, value) {
        assign(key.toString(), value);
      });
    }

    final schema = TemplateFormSchema.tryParse(template.formSchema);
    if (schema != null) {
      for (final section in schema.sections) {
        for (final field in section.fields) {
          if (!result.containsKey(field.id) && field.defaultValue != null) {
            assign(field.id, field.defaultValue);
          }
        }
      }
    }

    result.putIfAbsent('templateName', () => template.name);
    return result;
  }

  String _replacePlaceholders(String html, Map<String, String> values) {
    return html.replaceAllMapped(_placeholderPattern, (match) {
      final key = match.group(1)?.trim();
      if (key == null || key.isEmpty) {
        return '';
      }
      return values[key] ?? '';
    });
  }

  String? _normalizePlaceholderValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is DateTime) {
      return _dateFormatter.format(value);
    }
    if (value is bool) {
      return value ? '예' : '아니오';
    }
    if (value is num) {
      return value.toString();
    }
    if (value is List) {
      final parts = value
          .map((item) => _normalizePlaceholderValue(item))
          .where((item) => item != null && item!.isNotEmpty)
          .cast<String>()
          .toList();
      if (parts.isEmpty) {
        return null;
      }
      return parts.join(', ');
    }
    if (value is Map) {
      final parts = value.values
          .map((item) => _normalizePlaceholderValue(item))
          .where((item) => item != null && item!.isNotEmpty)
          .cast<String>()
          .toList();
      if (parts.isEmpty) {
        return null;
      }
      return parts.join(', ');
    }
    return value.toString();
  }
}

class _SchemaSummary {
  final bool available;
  final String? version;
  final String? title;
  final String? description;
  final int sectionCount;
  final int fieldCount;

  const _SchemaSummary({
    required this.available,
    this.version,
    this.title,
    this.description,
    this.sectionCount = 0,
    this.fieldCount = 0,
  });

  factory _SchemaSummary.fromTemplate(Template template) {
    final schema = template.formSchema;
    if (schema == null || schema.isEmpty) {
      return const _SchemaSummary(available: false);
    }

    final sections = schema['sections'];
    int sectionCount = 0;
    int fieldCount = 0;

    if (sections is List) {
      sectionCount = sections.length;
      for (final section in sections) {
        final fields = section is Map<String, dynamic> ? section['fields'] : null;
        if (fields is List) {
          fieldCount += fields.length;
        }
      }
    }

    final version = schema['version']?.toString();
    final title = schema['title']?.toString();
    final description = schema['description']?.toString();

    return _SchemaSummary(
      available: true,
      version: version?.isNotEmpty == true ? version : null,
      title: title?.isNotEmpty == true ? title : null,
      description: description?.isNotEmpty == true ? description : null,
      sectionCount: sectionCount,
      fieldCount: fieldCount,
    );
  }
}

class _SchemaDetails extends StatelessWidget {
  final _SchemaSummary summary;

  const _SchemaDetails({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '양식 정보',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1B4B),
            ),
          ),
          if (summary.version != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '버전 ${summary.version}${summary.title != null ? ' · ${summary.title}' : ''}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF3730A3)),
              ),
            ),
          if (summary.description != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                summary.description!,
                style: const TextStyle(fontSize: 13, color: Color(0xFF312E81), height: 1.4),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '섹션 ${summary.sectionCount}개 · 필드 ${summary.fieldCount}개 정의됨',
              style: const TextStyle(fontSize: 12, color: Color(0xFF4338CA)),
            ),
          ),
        ],
      ),
    );
  }
}
