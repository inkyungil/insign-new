import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import 'package:insign/data/contract_repository.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/models/contract.dart';

class ContractPdfViewScreen extends StatefulWidget {
  final int contractId;
  final bool autoLoad;

  const ContractPdfViewScreen({
    super.key,
    required this.contractId,
    this.autoLoad = true,
  });

  @override
  State<ContractPdfViewScreen> createState() => _ContractPdfViewScreenState();
}

class _ContractPdfViewScreenState extends State<ContractPdfViewScreen> {
  final ContractRepository _contractRepository = ContractRepository();

  Uint8List? _pdfBytes;
  Contract? _contract;
  String? _userName;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      _loadPdf();
    }
  }

  Future<void> _loadPdf() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await SessionService.getAccessToken();

      // Load user info and contract details in parallel
      final results = await Future.wait([
        SessionService.loadSession(),
        _contractRepository.fetchContractDetail(
          id: widget.contractId,
          token: token,
        ),
        _contractRepository.viewContractPdfInline(
          id: widget.contractId,
          token: token,
        ),
      ]);

      final session = results[0] as StoredSession?;
      final contract = results[1] as Contract;
      final bytes = results[2] as Uint8List;

      if (!mounted) return;
      setState(() {
        _userName = session?.user.displayName ?? '사용자';
        _contract = contract;
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
    final contractName = _contract?.name ?? '계약서';
    final date = DateFormat('yyyyMMdd').format(DateTime.now());

    // Sanitize filename by removing special characters
    final sanitizedUserName = userName.replaceAll(RegExp(r'[^\w가-힣]'), '_');
    final sanitizedContractName = contractName.replaceAll(RegExp(r'[^\w가-힣]'), '_');

    return '${sanitizedUserName}_${sanitizedContractName}_$date.pdf';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('계약서 PDF'),
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
