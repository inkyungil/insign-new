import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart' as io;
import 'package:url_launcher/url_launcher.dart';
import 'package:insign/core/config/api_config.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/data/contract_repository.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/data/template_repository.dart';
import 'package:insign/features/contracts/utils/html_layout_utils.dart';
import 'package:insign/models/blockchain_verification_result.dart';
import 'package:insign/models/contract.dart';
import 'package:insign/models/template_form.dart';

class ContractDetailScreen extends StatefulWidget {
  final int contractId;

  const ContractDetailScreen({super.key, required this.contractId});

  @override
  State<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends State<ContractDetailScreen> {
  final ContractRepository _contractRepository = ContractRepository();
  final TemplateRepository _templateRepository = TemplateRepository();
  final DateFormat _dateFormatter = DateFormat('yyyy.MM.dd');
  final DateFormat _dateTimeFormatter = DateFormat('yyyy.MM.dd HH:mm');
  static final RegExp _placeholderPattern = RegExp(r'{{\s*([^}]+)\s*}}');

  Contract? _contract;
  TemplateFormSchema? _templateSchema;
  String? _templateContent;
  Map<String, dynamic> _templateFormValues = const {};
  Uint8List? _authorSignatureBytes;
  String? _authorSignatureUrl;
  String? _clientSignatureUrl;
  String? _clientSignedAt;
  String? _performerSignedAt;

  bool _loading = true;
  bool _refreshing = false;
  bool _resending = false;
  bool _exportingPdf = false;
  bool _verifyingPdf = false;
  String? _errorMessage;
  BlockchainVerificationResult? _verificationResult;
  String? _verificationError;

  @override
  void initState() {
    super.initState();
    _loadContract();
  }

  Future<void> _loadContract({bool isRefresh = false}) async {
    setState(() {
      if (isRefresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _errorMessage = null;
    });

    try {
      final token = await SessionService.getAccessToken();
      final contract = await _contractRepository.fetchContractDetail(
        id: widget.contractId,
        token: token,
      );

      TemplateFormSchema? schema;
      String? templateContent = _metadataTemplateContent(contract.metadata);

      if ((templateContent == null || templateContent.trim().isEmpty) &&
          contract.templateId != null &&
          token != null &&
          token.isNotEmpty) {
        try {
          final template = await _templateRepository.fetchTemplate(
            contract.templateId!,
            token: token,
          );
          templateContent = template.content;
          schema = TemplateFormSchema.tryParse(template.formSchema);
        } catch (_) {
          schema = null;
        }
      }

      final metadata = contract.metadata;
      schema ??= _metadataTemplateSchema(metadata);
      final formValues = _metadataTemplateValues(metadata);

      final authorUrl = _resolveSignatureUrl(
        metadata?['authorSignatureImage'] ??
            metadata?['authorSignature'] ??
            metadata?['employerSignatureImage'] ??
            metadata?['employerSignature'] ??
            metadata?['clientSignatureImage'] ??
            metadata?['clientSignature'],
      );

      final performerUrl = _resolveSignatureUrl(
        metadata?['employeeSignatureImage'] ??
            metadata?['employeeSignature'] ??
            metadata?['performerSignatureImage'] ??
            metadata?['performerSignature'] ??
            metadata?['borrowerSignatureImage'] ??
            metadata?['borrowerSignature'] ??
            contract.signatureImage,
      );

      final employerSignedAt =
          _metadataString(metadata, 'authorSignatureDate') ??
              _metadataString(metadata, 'employerSignDate') ??
              _metadataString(metadata, 'clientSignDate') ??
              _metadataString(metadata, 'clientSignedAt');

      final performerSignedAt =
          _metadataString(metadata, 'employeeSignatureDate') ??
              _metadataString(metadata, 'performerSignDate') ??
              _metadataString(metadata, 'performerSignedAt') ??
              _formatDateTime(contract.signatureCompletedAt);
      final authorBytes = _decodeSignatureBytes(authorUrl);

      if (!mounted) return;
      setState(() {
        _contract = contract;
        _templateSchema = schema;
        _templateContent = templateContent;
        _templateFormValues = formValues;
        _authorSignatureBytes = authorBytes;
        _authorSignatureUrl = authorUrl;
        _clientSignatureUrl = performerUrl;
        _clientSignedAt = employerSignedAt;
        _performerSignedAt = performerSignedAt;
        _verificationResult = null;
        _verificationError = null;
        _verifyingPdf = false;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _errorMessage = message.isEmpty ? '계약 정보를 불러오지 못했습니다.' : message;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  String? _metadataTemplateContent(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    final raw = metadata['templateRawContent'];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw;
    }
    return null;
  }

  TemplateFormSchema? _metadataTemplateSchema(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    final raw = metadata['templateFormSchema'];
    if (raw is Map<String, dynamic>) {
      return TemplateFormSchema.tryParse(raw);
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return TemplateFormSchema.tryParse(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic> _metadataTemplateValues(Map<String, dynamic>? metadata) {
    if (metadata == null) return const {};

    final result = <String, dynamic>{};

    // 갑이 입력한 값 (templateFormValues)
    final templateValues = metadata['templateFormValues'];
    if (templateValues is Map<String, dynamic>) {
      result.addAll(templateValues);
    } else if (templateValues is String && templateValues.isNotEmpty) {
      try {
        final decoded = jsonDecode(templateValues);
        if (decoded is Map<String, dynamic>) {
          result.addAll(decoded);
        }
      } catch (_) {}
    }

    // 을이 입력한 값 (recipientFormValues) - 병합
    final recipientValues = metadata['recipientFormValues'];
    if (recipientValues is Map<String, dynamic>) {
      result.addAll(recipientValues);
    } else if (recipientValues is String && recipientValues.isNotEmpty) {
      try {
        final decoded = jsonDecode(recipientValues);
        if (decoded is Map<String, dynamic>) {
          result.addAll(decoded);
        }
      } catch (_) {}
    }

    return result;
  }

  String? _metadataString(Map<String, dynamic>? metadata, String key) {
    if (metadata == null) return null;
    final value = metadata[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  String? _resolveSignatureUrl(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      if (trimmed.startsWith('data:') || trimmed.startsWith('http')) {
        return trimmed;
      }
      if (trimmed.startsWith('/')) {
        final base = ApiConfig.baseUrl.replaceFirst(RegExp(r'/+$'), '');
        return '$base$trimmed';
      }
      final base64Pattern = RegExp(r'^[A-Za-z0-9+/=]+$');
      if (base64Pattern.hasMatch(trimmed)) {
        return 'data:image/png;base64,$trimmed';
      }
      final base = ApiConfig.baseUrl.replaceFirst(RegExp(r'/+$'), '');
      return '$base/$trimmed';
    }
    return null;
  }

  Uint8List? _decodeSignatureBytes(String? uri) {
    if (uri == null) return null;
    if (uri.startsWith('data:')) {
      final index = uri.indexOf(',');
      if (index >= 0 && index < uri.length - 1) {
        final dataPart = uri.substring(index + 1);
        try {
          return base64Decode(dataPart);
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  String _signatureImgTag(String url) {
    return '<div style="width:100%;padding:6px 0;">'
        '<img src="$url" style="display:block;width:100%;max-width:100%;height:auto;object-fit:contain;" />'
        '</div>';
  }

  Map<String, dynamic>? get _metadata => _contract?.metadata;

  bool get _isDeclined =>
      _contract?.status == 'signature_declined' ||
      (_contract?.signatureDeclinedAt?.isNotEmpty ?? false);
  bool get _isCompleted =>
      _contract?.status == 'signature_completed' ||
      (_contract?.signatureCompletedAt?.isNotEmpty ?? false);
  bool get _isExpired {
    final end = _contract?.endDate;
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  bool get _disableResend =>
      _resending || _isDeclined || _isCompleted || _isExpired;

  bool _hasBlockchainInfo(Contract contract) {
    return contract.blockchainHash?.isNotEmpty ?? false;
  }

  String? _getBlockchainExplorerUrl(String network, String? txHash) {
    if (txHash == null || txHash.trim().isEmpty) return null;

    // Kaia 블록체인 익스플로러
    if (network.contains('testnet') || network.contains('kairos')) {
      return 'https://kairos.kaiascan.io/tx/$txHash';
    } else if (network.contains('mainnet') || network.contains('kaia')) {
      return 'https://kaiascan.io/tx/$txHash';
    }

    // 기본값: testnet
    return 'https://kairos.kaiascan.io/tx/$txHash';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && !_refreshing) {
      return const Center(
          child: CircularProgressIndicator(color: primaryColor));
    }

    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }

    final contract = _contract;
    if (contract == null) {
      return _buildErrorState('계약 정보를 찾을 수 없습니다.');
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: () => _loadContract(isRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(context),
            const SizedBox(height: 24),
            _buildHeroSection(contract),
            const SizedBox(height: 24),
            _buildStatusTimeline(contract),
            const SizedBox(height: 20),
            _buildPartiesCard(contract),
            const SizedBox(height: 20),
            _buildOverviewCard(contract),
            if (_hasBlockchainInfo(contract)) ...[
              const SizedBox(height: 20),
              _buildBlockchainCard(contract),
            ],
            if (_authorSignatureBytes != null) ...[
              const SizedBox(height: 20),
            ],
            ..._buildHtmlPreviewWidgets(),
            const SizedBox(height: 24),
            _buildActionSection(contract),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15, color: Color(0xFF991B1B), height: 1.5),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : () => _loadContract(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('다시 시도'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _CircleIconButton(
          icon: Icons.arrow_back,
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        const Text(
          '계약 상세',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
  }

  Widget _buildHeroSection(Contract contract) {
    final statusLabel = _statusLabel(contract);
    final performerName = (contract.performerName?.trim().isNotEmpty ?? false)
        ? contract.performerName!.trim()
        : '미정';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _heroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.description_outlined,
                color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            contract.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '의뢰인 ${contract.clientName} · 수행자 $performerName',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            '계약 ID #${contract.id}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          _StatusChip(label: statusLabel, status: contract.status),
          if (_isExpired)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xFFF97316)),
                  SizedBox(width: 6),
                  Text(
                    '계약 기간이 만료되었습니다.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFF97316)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionSection(Contract contract) {
    final shareUrl = _signatureShareUrl(contract);
    final performerEmail = (contract.performerEmail?.trim().isNotEmpty ?? false)
        ? contract.performerEmail!.trim()
        : '미정';

    String? disableReason;
    if (_disableResend && !_resending) {
      if (_isDeclined) {
        disableReason = '서명이 거절된 계약은 다시 요청할 수 없습니다.';
      } else if (_isCompleted) {
        disableReason = '이미 서명이 완료된 계약입니다.';
      } else if (_isExpired) {
        disableReason = '계약 기간이 만료되어 재전송할 수 없습니다.';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: _disableResend ? null : () => _handleResend(contract),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            child: _resending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    '서명 요청 재전송',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            '서명 요청은 수행자 이메일 $performerEmail 로 발송됩니다.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF64748B), height: 1.5),
          ),
          if (disableReason != null) ...[
            const SizedBox(height: 8),
            Text(
              disableReason,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed:
                shareUrl == null ? null : () => _handleCopyLink(shareUrl),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            icon: const Icon(Icons.link, size: 18),
            label: const Text(
              '서명 링크 복사',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _exportingPdf ? null : _handleDownloadPdf,
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            icon: _exportingPdf
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: primaryColor),
                  )
                : const Icon(Icons.picture_as_pdf, size: 18),
            label: Text(
              _exportingPdf ? 'PDF 생성 중...' : '계약서 PDF 다운로드',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(Contract contract) {
    final steps = _statusSteps(contract);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '계약 진행 상태',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              for (int i = 0; i < steps.length; i++)
                _TimelineTile(
                  label: steps[i].label,
                  completed: steps[i].completed,
                  isLast: i == steps.length - 1,
                  timestamp: _statusTimestamp(contract, i),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPartiesCard(Contract contract) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '계약 당사자',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 16),
          _PartyInfoCard(
            title: '갑 (의뢰인)',
            name: contract.clientName,
            email: contract.clientEmail,
            contact: contract.clientContact,
          ),
          const SizedBox(height: 12),
          _PartyInfoCard(
            title: '을 (수행자)',
            name: contract.performerName ?? '-',
            email: contract.performerEmail,
            contact: contract.performerContact,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(Contract contract) {
    final period = _formatPeriod(contract.startDate, contract.endDate);
    final amount = contract.amount?.isNotEmpty == true
        ? _formatCurrency(contract.amount!)
        : '-';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주요 정보',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 12),
          _InfoRow(label: '계약 기간', value: period ?? '-'),
          _InfoRow(label: '계약 금액', value: amount == '-' ? '-' : '$amount 원'),
          _InfoRow(label: '현재 상태', value: _statusLabel(contract)),
          _InfoRow(label: '작성일', value: _formatDateTime(contract.createdAt)),
          _InfoRow(label: '최근 수정', value: _formatDateTime(contract.updatedAt)),
          if (contract.signatureSentAt != null)
            _InfoRow(
                label: '서명 요청 일시',
                value: _formatDateTime(contract.signatureSentAt)),
          if (contract.signatureCompletedAt != null)
            _InfoRow(
                label: '서명 완료 일시',
                value: _formatDateTime(contract.signatureCompletedAt)),
          if (_isDeclined && contract.signatureDeclinedAt != null)
            _InfoRow(
                label: '서명 거절 일시',
                value: _formatDateTime(contract.signatureDeclinedAt)),
        ],
      ),
    );
  }

  Widget _buildBlockchainCard(Contract contract) {
    final timestamp = _formatDateTime(contract.blockchainTimestamp);
    final network = contract.blockchainNetwork ?? 'kaia-testnet';
    final txHash = contract.blockchainTxHash;
    final explorerUrl = _getBlockchainExplorerUrl(network, txHash);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.shield_outlined, color: primaryColor, size: 22),
              SizedBox(width: 8),
              Text(
                '블록체인 인증 정보',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(label: '네트워크', value: network),
          _InfoRow(label: '등록 일시', value: timestamp ?? '-'),
          _buildHashDisplay('트랜잭션 해시', txHash, explorerUrl: explorerUrl),
          _buildHashDisplay('문서 해시', contract.blockchainHash),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          const Text(
            '위변조 검사',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '서명 완료 시 다운로드받은 PDF 문서를 업로드하면 블록체인에 기록된 해시값과 즉시 비교합니다.',
            style: TextStyle(fontSize: 13, color: Color(0xFF475467), height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _verifyingPdf ? null : _handleVerifyPdf,
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: _verifyingPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  )
                : const Icon(Icons.search, size: 18),
            label: Text(
              _verifyingPdf ? '검증 중...' : 'PDF 업로드하여 위변조 검사',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_verificationError != null) ...[
            const SizedBox(height: 8),
            Text(
              _verificationError!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
          if (_verificationResult != null)
            _buildVerificationResultCard(_verificationResult!),
        ],
      ),
    );
  }

  Widget _buildVerificationResultCard(
      BlockchainVerificationResult result) {
    final matchesStored = result.matchesStoredPdf ?? false;
    final matchesBlockchain = result.matchesBlockchain ?? matchesStored;
    final bool isValid = matchesStored;
    final bool blockchainWarning = matchesStored && !matchesBlockchain;

    final Color baseColor = isValid
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);
    final icon = isValid ? Icons.verified_outlined : Icons.warning_amber_rounded;
    final title = isValid
        ? (blockchainWarning
            ? '저장된 해시는 일치하지만 블록체인 값은 다릅니다.'
            : '원본과 일치합니다.')
        : '경고: 해시가 일치하지 않습니다.';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: baseColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: baseColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: baseColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildHashDisplay(
            '업로드한 PDF 해시',
            result.computedHash,
            labelColor: const Color(0xFF52525B),
            valueColor: const Color(0xFF111827),
          ),
          if (result.blockchainHash?.isNotEmpty ?? false)
            _buildHashDisplay(
              '문서 해시',
              result.blockchainHash,
              labelColor: const Color(0xFF52525B),
              valueColor: const Color(0xFF111827),
            ),
        ],
      ),
    );
  }

  Widget _buildHashDisplay(
    String label,
    String? value, {
    Color? labelColor,
    Color? valueColor,
    String? explorerUrl,
  }) {
    final hasValue = value?.trim().isNotEmpty ?? false;
    final display = hasValue ? value!.trim() : '-';
    final hasExplorerUrl = explorerUrl?.trim().isNotEmpty ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: labelColor ?? const Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              display,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: valueColor ?? const Color(0xFF111827),
              ),
            ),
          ),
          if (hasValue)
            IconButton(
              tooltip: '값 복사',
              splashRadius: 18,
              icon: const Icon(Icons.copy, size: 18, color: Color(0xFF94A3B8)),
              onPressed: () => _copyToClipboard(
                display,
                message: '$label 값을 복사했습니다.',
              ),
            ),
          if (hasExplorerUrl)
            IconButton(
              tooltip: '블록체인 익스플로러에서 보기',
              splashRadius: 18,
              icon: const Icon(Icons.open_in_new, size: 18, color: primaryColor),
              onPressed: () => _openExplorerUrl(explorerUrl!),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildHtmlPreviewWidgets() {
    final html = _buildFilledTemplateHtml();
    if (html == null || html.trim().isEmpty) {
      return const [];
    }
    return [
      const SizedBox(height: 20),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '계약서 미리보기',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827)),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(16),
              child: HtmlWidget(
                html,
                renderMode: RenderMode.column,
                textStyle: const TextStyle(
                    fontSize: 14, height: 1.6, color: Color(0xFF1F2937)),
                customStylesBuilder: _htmlStylesBuilder,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  String? _signatureShareUrl(Contract contract) {
    final token = contract.signatureToken;
    if (token == null || token.isEmpty) {
      return null;
    }
    if (kIsWeb) {
      final origin = Uri.base.origin.replaceFirst(RegExp(r'/\$'), '');
      return '$origin/sign/$token';
    }
    final base = ApiConfig.baseUrl.replaceFirst(RegExp(r'/\$'), '');
    return '$base/sign/$token';
  }

  Future<void> _handleResend(Contract contract) async {
    if (_disableResend) return;
    setState(() => _resending = true);

    try {
      final token = await SessionService.getAccessToken();
      await _contractRepository.resendSignatureRequest(
          id: contract.id, token: token);
      await _loadContract(isRefresh: true);
      if (!mounted) return;
      final targetEmail = (contract.performerEmail?.trim().isNotEmpty ?? false)
          ? contract.performerEmail!.trim()
          : '등록된 수행자 이메일';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('서명 요청을 $targetEmail 로 재전송했습니다.'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isEmpty ? '서명 요청을 재전송하지 못했습니다.' : message),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _resending = false);
    }
  }

  Future<void> _copyToClipboard(String value, {String message = '클립보드에 복사했습니다.'}) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _handleCopyLink(String url) async {
    await _copyToClipboard(url, message: '서명 링크를 복사했습니다.');
  }

  Future<void> _openExplorerUrl(String url) async {
    final uri = Uri.parse(url);

    if (kIsWeb) {
      // 웹: 새 탭에서 열기
      html.window.open(url, '_blank');
    } else {
      // 모바일: 외부 브라우저에서 열기
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('블록체인 익스플로러를 열 수 없습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleDownloadPdf() async {
    final contract = _contract;
    if (contract == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('계약 정보를 불러오지 못했습니다.'),
            duration: Duration(seconds: 2)),
      );
      return;
    }

    setState(() => _exportingPdf = true);

    try {
      final token = await SessionService.getAccessToken();
      final pdfBytes = await _contractRepository.downloadContractPdf(
        id: contract.id,
        token: token,
      );

      await _savePdfToDevice(pdfBytes, 'contract_${contract.id}.pdf');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('계약서를 PDF로 저장했습니다.'), duration: Duration(seconds: 2)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF 다운로드에 실패했습니다: $error'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingPdf = false);
      }
    }
  }

  Future<void> _handleVerifyPdf() async {
    final contract = _contract;
    if (contract == null) return;

    final bytes = await _pickPdfBytes();
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('검사할 PDF 파일을 선택해 주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _verifyingPdf = true;
      _verificationError = null;
    });

    try {
      final token = await SessionService.getAccessToken();
      final result = await _contractRepository.verifyContractPdf(
        id: contract.id,
        fileBytes: bytes,
        token: token,
      );

      if (!mounted) return;
      setState(() {
        _verificationResult = result;
        _verificationError = null;
      });

      final matchesStored = result.matchesStoredPdf ?? false;
      final matchesChain = result.matchesBlockchain ?? matchesStored;
      late final String message;
      if (matchesStored && matchesChain) {
        message = '업로드한 PDF가 블록체인 해시와 일치합니다.';
      } else if (matchesStored && !matchesChain) {
        message = 'PDF는 저장된 해시와 일치하지만 블록체인 값은 다릅니다.';
      } else {
        message = '경고: 업로드한 PDF가 저장된 해시와 다릅니다.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _verificationError =
            message.isEmpty ? '위변조 검사를 완료하지 못했습니다.' : message;
        _verificationResult = null;
      });
    } finally {
      if (mounted) {
        setState(() => _verifyingPdf = false);
      }
    }
  }

  Future<Uint8List?> _pickPdfBytes() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );

    if (selection == null || selection.files.isEmpty) {
      return null;
    }

    final file = selection.files.single;
    if (file.bytes != null) {
      return file.bytes;
    }

    final path = file.path;
    if (path != null && path.isNotEmpty) {
      final io.File ioFile = io.File(path);
      return ioFile.readAsBytes();
    }

    return null;
  }

  Future<void> _savePdfToDevice(Uint8List bytes, String filename) async {
    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..download = filename
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    } else {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    }
  }

  String? _buildFilledTemplateHtml() {
    final contract = _contract;
    final content = _templateContent ?? contract?.details;
    if (contract == null || content == null || content.trim().isEmpty) {
      return null;
    }

    final values = <String, String>{};

    void assign(String key, dynamic raw) {
      if (key.isEmpty) return;
      final normalized = _normalizeValue(raw);
      values[key] = normalized;
    }

    final metadata = _metadata;
    metadata?.forEach((key, value) {
      if (key is! String) return;
      if (key.startsWith('template')) return; // HTML/스키마 원본은 제외
      assign(key, value);
    });

    _templateFormValues.forEach((key, value) => assign(key, value));

    assign('contractName', contract.name);
    assign('clientName', contract.clientName);
    assign('clientContact', contract.clientContact);
    assign('clientEmail', contract.clientEmail);
    assign('performerName', contract.performerName);
    assign('performerContact', contract.performerContact);
    assign('performerEmail', contract.performerEmail);
    final contractDetails = contract.details?.trim();
    if (contractDetails != null && contractDetails.isNotEmpty) {
      assign('details', contractDetails);
    }
    assign('startDate', _formatDate(contract.startDate));
    assign('endDate', _formatDate(contract.endDate));
    assign('amount', contract.amount);
    assign('lenderName', contract.clientName);
    assign('lenderContact', contract.clientContact);
    assign('lenderEmail', contract.clientEmail);
    assign('borrowerName', contract.performerName);
    assign('borrowerContact', contract.performerContact);
    assign('borrowerEmail', contract.performerEmail);
    assign('createdAt', _formatDateTime(contract.createdAt));
    assign('updatedAt', _formatDateTime(contract.updatedAt));
    assign('signatureSentAt', _formatDateTime(contract.signatureSentAt));
    assign(
        'signatureCompletedAt', _formatDateTime(contract.signatureCompletedAt));

    final clientSignedAt = _formatDateTime(_clientSignedAt);
    if (clientSignedAt.isNotEmpty && clientSignedAt != '-') {
      assign('clientSignatureDate', clientSignedAt);
      assign('clientSignDate', clientSignedAt);
      assign('lenderSignDate', clientSignedAt);
      assign('employerSignDate', clientSignedAt);
    }

    final performerSignedAt =
        _performerSignedAt ?? _formatDateTime(contract.signatureCompletedAt);
    if (performerSignedAt.isNotEmpty && performerSignedAt != '-') {
      assign('employeeSignatureDate', performerSignedAt);
      assign('employeeSignDate', performerSignedAt);
      assign('performerSignDate', performerSignedAt);
      assign('borrowerSignDate', performerSignedAt);
    }

    // 갑(계약 작성자)의 서명
    final authorSigUrl = _authorSignatureUrl;
    if (authorSigUrl != null) {
      final tag = _signatureImgTag(authorSigUrl);
      for (final key in const [
        'clientSignatureImage',
        'clientSignature',
        'authorSignatureImage',
        'authorSignature',
        'lenderSignatureImage',
        'lenderSignature',
        'employerSignatureImage',
        'employerSignature',
      ]) {
        assign(key, tag);
      }
    }

    // 을(수행자)의 서명 - 을이 서명한 경우에만 표시
    final performerSigUrl = _clientSignatureUrl;
    if (performerSigUrl != null) {
      final tag = _signatureImgTag(performerSigUrl);
      for (final key in const [
        'employeeSignatureImage',
        'employeeSignature',
        'performerSignatureImage',
        'performerSignature',
        'borrowerSignatureImage',
        'borrowerSignature',
      ]) {
        assign(key, tag);
      }
    }

    final replaced = content.replaceAllMapped(_placeholderPattern, (match) {
      final key = match.group(1)?.trim();
      if (key == null || key.isEmpty) return '';
      return values[key] ?? '';
    });
    final cleaned = replaced.replaceAll(_placeholderPattern, '');
    return normalizeContractHtmlLayout(cleaned);
  }

  Map<String, String>? _htmlStylesBuilder(dynamic element) =>
      buildContractHtmlStyles(element);

  List<_StatusStep> _statusSteps(Contract contract) {
    return [
      _StatusStep('기안 완료', contract.createdAt != null),
      _StatusStep(
          '서명 대기',
          contract.status == 'active' ||
              contract.signatureSentAt != null ||
              _isDeclined),
      _StatusStep('서명 완료', _isCompleted),
    ];
  }

  String _statusLabel(Contract contract) {
    final metadataStatus = _metadata?['status'];
    if (metadataStatus is String && metadataStatus.isNotEmpty) {
      return metadataStatus;
    }
    switch (contract.status) {
      case 'signature_completed':
        return '서명 완료';
      case 'signature_declined':
        return '서명 거절';
      case 'active':
        return '서명 대기';
      case 'draft':
      default:
        return '기안 완료';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return _dateFormatter.format(_toKst(date));
  }

  String? _formatPeriod(DateTime? start, DateTime? end) {
    if (start == null && end == null) return null;
    final startText = start != null ? _dateFormatter.format(_toKst(start)) : '';
    final endText = end != null ? _dateFormatter.format(_toKst(end)) : '';
    if (startText.isEmpty || endText.isEmpty) {
      return startText.isNotEmpty ? startText : endText;
    }
    return '$startText ~ $endText';
  }

  String _formatCurrency(String raw) {
    final normalized = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) return raw;
    final value = int.tryParse(normalized);
    if (value == null) return raw;
    return NumberFormat.decimalPattern('ko_KR').format(value);
  }

  String _normalizeValue(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      final trimmed = value.trim();
      if (_isMaskedResidentValue(trimmed)) {
        return _maskedResidentDisplay(trimmed);
      }
      return trimmed;
    }
    if (value is num || value is bool) return value.toString();
    if (value is DateTime) return _dateFormatter.format(value);
    if (value is List) {
      return value.map(_normalizeValue).where((v) => v.isNotEmpty).join(', ');
    }
    if (value is Map) {
      return value.values
          .map(_normalizeValue)
          .where((v) => v.isNotEmpty)
          .join(', ');
    }
    return value.toString();
  }

  bool _isMaskedResidentValue(String value) {
    return RegExp(r'^\d{6}-\d$').hasMatch(value);
  }

  String _maskedResidentDisplay(String value) {
    return '${value.substring(0, 6)}-${value.substring(7, 8)}******';
  }

  String _formatTemplateFieldValue(
      TemplateFieldDefinition field, dynamic value) {
    if (value == null) return '-';
    if (field.type == 'checkbox') {
      if (field.options.isEmpty) {
        final boolValue = value is bool
            ? value
            : value is String
                ? (value.toLowerCase() == 'true' || value == '1')
                : value == 1;
        return boolValue ? '예' : '아니오';
      }
      if (value is List) {
        return value
            .map((item) => _mapOptionLabel(field, item.toString()))
            .join(', ');
      }
      if (value is String && value.isNotEmpty) {
        return _mapOptionLabel(field, value);
      }
    }
    if ((field.type == 'select' || field.type == 'radio') && value is String) {
      return _mapOptionLabel(field, value);
    }
    final normalized = _normalizeValue(value);
    return normalized.isEmpty ? '-' : normalized;
  }

  String _mapOptionLabel(TemplateFieldDefinition field, String value) {
    for (final option in field.options) {
      if (option.value == value) {
        return option.label;
      }
    }
    return value;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return DateTime.tryParse(trimmed);
    }
    return null;
  }

  DateTime _toKst(DateTime dateTime) {
    final utc = dateTime.isUtc ? dateTime : dateTime.toUtc();
    return utc.add(const Duration(hours: 9));
  }

  String _formatDateTime(dynamic date) {
    final parsed = _parseDateTime(date);
    if (parsed == null) {
      if (date is String && date.trim().isNotEmpty) {
        return date.trim();
      }
      return '-';
    }
    return _dateTimeFormatter.format(_toKst(parsed));
  }

  String? _statusTimestamp(Contract contract, int step) {
    switch (step) {
      case 0:
        return _formatDateTime(contract.createdAt);
      case 1:
        final sent = _formatDateTime(contract.signatureSentAt);
        if (sent != '-' && sent.isNotEmpty) {
          return sent;
        }
        return _formatDateTime(contract.updatedAt);
      case 2:
        return _formatDateTime(contract.signatureCompletedAt);
      default:
        return null;
    }
  }

  BoxDecoration _heroDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [
        BoxShadow(
            color: Color(0x14111827), blurRadius: 18, offset: Offset(0, 8)),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
            color: Color(0x14111827), blurRadius: 14, offset: Offset(0, 6)),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _CircleIconButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0x1F4F46E5),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: primaryColor),
      ),
    );
  }
}

class _StatusStep {
  final String label;
  final bool completed;

  const _StatusStep(this.label, this.completed);
}

class _TimelineTile extends StatelessWidget {
  final String label;
  final bool completed;
  final bool isLast;
  final String? timestamp;

  const _TimelineTile({
    required this.label,
    required this.completed,
    required this.isLast,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = completed ? primaryColor : const Color(0xFFE2E8F0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? primaryColor : Colors.white,
                border: Border.all(color: activeColor, width: 2),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 42,
                color: activeColor,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: completed
                        ? const Color(0xFF111827)
                        : const Color(0xFF94A3B8),
                  ),
                ),
                if (timestamp != null && timestamp!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      timestamp!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String? status;

  const _StatusChip({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  static Color _statusColor(String? status) {
    switch (status) {
      case 'signature_completed':
        return const Color(0xFF10B981);
      case 'signature_declined':
        return const Color(0xFFEF4444);
      case 'active':
        return const Color(0xFFF59E0B);
      default:
        return primaryColor;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF111827), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyInfoCard extends StatelessWidget {
  final String title;
  final String name;
  final String? email;
  final String? contact;

  const _PartyInfoCard({
    required this.title,
    required this.name,
    this.email,
    this.contact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          _InfoRow(label: '이름', value: name),
          _InfoRow(label: '연락처', value: contact ?? '-'),
          _InfoRow(label: '이메일', value: email ?? '-'),
        ],
      ),
    );
  }
}

class _TemplateFieldRow extends StatelessWidget {
  final String label;
  final String value;

  const _TemplateFieldRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF111827), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
