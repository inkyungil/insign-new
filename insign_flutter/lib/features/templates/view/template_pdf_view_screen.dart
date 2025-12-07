import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import 'package:insign/data/services/session_service.dart';
import 'package:insign/data/template_repository.dart';
import 'package:insign/models/template.dart';

class TemplatePdfViewScreen extends StatefulWidget {
  final int templateId;

  const TemplatePdfViewScreen({
    super.key,
    required this.templateId,
  });

  @override
  State<TemplatePdfViewScreen> createState() => _TemplatePdfViewScreenState();
}

class _TemplatePdfViewScreenState extends State<TemplatePdfViewScreen> {
  final TemplateRepository _templateRepository = TemplateRepository();

  Uint8List? _pdfBytes;
  Template? _template;
  String? _userName;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await SessionService.getAccessToken();

      // Load user info, template details, and PDF in parallel
      final results = await Future.wait([
        SessionService.loadSession(),
        _templateRepository.fetchTemplate(widget.templateId, token: token),
        _templateRepository.previewTemplatePdf(
          id: widget.templateId,
          token: token,
        ),
      ]);

      final session = results[0] as StoredSession?;
      final template = results[1] as Template;
      final bytes = results[2] as Uint8List;

      if (!mounted) return;
      setState(() {
        _userName = session?.user.displayName ?? '사용자';
        _template = template;
        _pdfBytes = bytes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _generateFileName() {
    final userName = _userName ?? '사용자';
    final templateName = _template?.name ?? '템플릿';
    final date = DateFormat('yyyyMMdd').format(DateTime.now());

    // Sanitize filename by removing special characters
    final sanitizedUserName = userName.replaceAll(RegExp(r'[^\w가-힣]'), '_');
    final sanitizedTemplateName = templateName.replaceAll(RegExp(r'[^\w가-힣]'), '_');

    return '${sanitizedUserName}_${sanitizedTemplateName}_미리보기_$date.pdf';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('템플릿 PDF 미리보기'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 40,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPdf,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfBytes == null) {
      return const Center(
        child: Text(
          'PDF 데이터를 불러오지 못했습니다.',
          style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
        ),
      );
    }

    return PdfPreview(
      build: (format) => _pdfBytes!,
      pdfFileName: _generateFileName(),
      allowSharing: true,
      allowPrinting: true,
      canChangePageFormat: false,
      canChangeOrientation: false,
    );
  }
}

