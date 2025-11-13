import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import 'package:universal_html/html.dart' as html;

import 'package:insign/core/config/api_config.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/data/contract_repository.dart';
import 'package:insign/data/template_repository.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/features/contracts/utils/html_layout_utils.dart';
import 'package:insign/models/contract.dart';
import 'package:insign/models/template_form.dart';

class ContractSignScreen extends StatefulWidget {
  final String signatureToken;

  const ContractSignScreen({super.key, required this.signatureToken});

  @override
  State<ContractSignScreen> createState() => _ContractSignScreenState();
}

class _ContractSignScreenState extends State<ContractSignScreen> {
  final ContractRepository _contractRepository = ContractRepository();
  final TemplateRepository _templateRepository = TemplateRepository();
  final DateFormat _dateFormatter = DateFormat('yyyy.MM.dd');
  final DateFormat _dateTimeFormatter = DateFormat('yyyy.MM.dd HH:mm');

  final TextEditingController _performerNameController = TextEditingController();
  final TextEditingController _performerEmailController = TextEditingController();
  final TextEditingController _performerContactController = TextEditingController();

  final Map<String, TextEditingController> _recipientControllers = {};
  final Map<String, Set<String>> _recipientCheckboxValues = {};

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2.8,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  Contract? _contract;
  TemplateFormSchema? _templateSchema;
  String? _templateContent;
  Map<String, dynamic> _templateFormValues = const {};
  Map<String, dynamic> _recipientFormValues = {};
  Map<String, String> _recipientFormErrors = {};
  bool _recipientFormCompleted = false;

  bool _verifying = false;
  bool _declineSubmitting = false;
  bool _signatureSubmitting = false;
  bool _refreshing = false;
  bool _recipientFormTouched = false;
  bool _downloadingPdf = false;

  String? _tokenError;
  String? _formError;
  String? _signatureDataUrl;
  String _signatureMode = 'draw';
  String? _signatureSource;
  Uint8List? _signaturePreviewBytes;
  String? _existingPerformerSignatureUrl;
  final Map<String, VoidCallback> _performerFieldListeners = {};

  String? _lastVerifiedName;
  String? _lastVerifiedEmail;
  String? _lastVerifiedContact;

  @override
  void initState() {
    super.initState();
    _registerPerformerFieldBindings();
  }

  @override
  void dispose() {
    _performerNameController.dispose();
    _performerEmailController.dispose();
    _performerContactController.dispose();
    _disposePerformerFieldBindings();
    for (final controller in _recipientControllers.values) {
      controller.dispose();
    }
    _signatureController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _metadata => _contract?.metadata;

  bool get _isDeclined =>
      _contract?.status == 'signature_declined' || (_contract?.signatureDeclinedAt?.isNotEmpty ?? false);
  bool get _isCompleted =>
      _contract?.status == 'signature_completed' || (_contract?.signatureCompletedAt?.isNotEmpty ?? false);
  bool get _isExpired {
    final end = _contract?.endDate;
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  List<TemplateFormSection> get _recipientSections {
    final schema = _templateSchema;
    if (schema == null) return const [];
    return schema.selectSections(
      allowedRoles: const [
        'recipient',
        'performer',
        'employee',
        'borrower',
        'debtor',
        'obligor',
        'signee',
        'signer',
        'witness',
        'viewer',
      ],
      includeAll: false,
    );
  }

  Future<void> _verifyPerformer() async {
    final name = _performerNameController.text.trim();
    final email = _performerEmailController.text.trim();
    final contact = _performerContactController.text.trim();
    final sanitizedContact = contact.replaceAll(RegExp(r'[^0-9]'), '');

    if (name.isEmpty || email.isEmpty || contact.isEmpty) {
      setState(() => _formError = '이름, 이메일, 연락처를 모두 입력해 주세요.');
      return;
    }

    setState(() {
      _formError = null;
      _verifying = true;
      _tokenError = null;
    });

    try {
      final contract = await _contractRepository.verifyContractByToken(
        signatureToken: widget.signatureToken,
        payload: VerifyContractPerformerPayload(
          performerName: name,
          performerEmail: email,
          performerContact: sanitizedContact.isNotEmpty ? sanitizedContact : contact,
        ),
      );
      await _hydrateContract(contract);
      setState(() {
        _lastVerifiedName = name;
        _lastVerifiedEmail = email;
        _lastVerifiedContact = contact;
      });
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        if (message.contains('서명 링크')) {
          _tokenError = message.isEmpty ? '유효하지 않은 서명 링크입니다.' : message;
        } else {
          _formError = message.isEmpty ? '정보를 확인할 수 없습니다. 다시 시도해 주세요.' : message;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  Future<void> _hydrateContract(Contract contract) async {
    TemplateFormSchema? schema;
    String? templateContent = _metadataTemplateContent(contract.metadata);

    final sessionToken = await SessionService.getAccessToken();

    if ((templateContent == null || templateContent.trim().isEmpty) &&
        contract.templateId != null &&
        sessionToken != null && sessionToken.isNotEmpty) {
      try {
        final template = await _templateRepository.fetchTemplate(
          contract.templateId!,
          token: sessionToken,
        );
        templateContent = template.content;
        schema = TemplateFormSchema.tryParse(template.formSchema);
      } catch (_) {
        schema = null;
      }
    }

    schema ??= _metadataTemplateSchema(contract.metadata);

    final templateValues = _metadataTemplateValues(contract.metadata);
    final recipientValues = _metadataRecipientValues(contract.metadata);
    final metadata = contract.metadata;
    final performerSignatureUrl = _resolveSignatureUrl(
      metadata?['employeeSignatureImage'] ??
          metadata?['employeeSignature'] ??
          metadata?['performerSignatureImage'] ??
          metadata?['performerSignature'] ??
          metadata?['borrowerSignatureImage'] ??
          metadata?['borrowerSignature'] ??
          contract.signatureImage,
    );
    final recipientSectionsCandidate = schema?.selectSections(
          allowedRoles: const [
            'recipient',
            'performer',
            'employee',
            'borrower',
            'debtor',
            'obligor',
            'signee',
            'signer',
            'witness',
            'viewer',
          ],
          includeAll: false,
        ) ??
        const <TemplateFormSection>[];
    final recipientCompleted = recipientSectionsCandidate.isEmpty ||
        _areRecipientFieldsComplete(recipientSectionsCandidate, recipientValues);

    setState(() {
      _contract = contract;
      _templateSchema = schema;
      _templateContent = templateContent;
      _templateFormValues = templateValues;
      _recipientFormValues = recipientValues;
      _recipientFormErrors = {};
      _recipientFormCompleted = recipientCompleted;
      _recipientFormTouched = recipientCompleted && recipientValues.isNotEmpty;
      _existingPerformerSignatureUrl = performerSignatureUrl;
    });

    _syncRecipientControllers(recipientValues);
    _applyPerformerDefaultsToRecipient(overwriteExisting: false);

    if (contract.performerName != null && contract.performerName!.isNotEmpty) {
      _performerNameController.text = contract.performerName!;
    }
    if (contract.performerEmail != null && contract.performerEmail!.isNotEmpty) {
      _performerEmailController.text = contract.performerEmail!;
    }
    final performerContact = contract.performerContact ?? _lastVerifiedContact;
    if (performerContact != null && performerContact.isNotEmpty) {
      final formatted = _formatKoreanPhoneNumber(performerContact);
      _performerContactController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    _applyPerformerDefaultsToRecipient(overwriteExisting: true);
  }

  void _syncRecipientControllers(Map<String, dynamic> values) {
    for (final entry in values.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is List) {
        _recipientCheckboxValues[key] = value.map((e) => e.toString()).toSet();
      } else {
        _recipientCheckboxValues.remove(key);
        final controller = _recipientControllers.putIfAbsent(key, () => TextEditingController());
        controller.text = value?.toString() ?? '';
      }
    }
  }

  void _registerPerformerFieldBindings() {
    _disposePerformerFieldBindings();
    final bindings = <String, TextEditingController>{
      'performerName': _performerNameController,
      'performerContact': _performerContactController,
      'performerEmail': _performerEmailController,
    };

    bindings.forEach((fieldId, controller) {
      void listener() => _syncPerformerFieldToRecipient(fieldId, controller);
      controller.addListener(listener);
      _performerFieldListeners[fieldId] = listener;
    });
  }

  void _disposePerformerFieldBindings() {
    final bindings = <String, TextEditingController>{
      'performerName': _performerNameController,
      'performerContact': _performerContactController,
      'performerEmail': _performerEmailController,
    };

    _performerFieldListeners.forEach((fieldId, listener) {
      bindings[fieldId]?.removeListener(listener);
    });
    _performerFieldListeners.clear();
  }

  void _applyPerformerDefaultsToRecipient({required bool overwriteExisting}) {
    if (_templateSchema == null) {
      return;
    }

    final bindings = <String, TextEditingController>{
      'performerName': _performerNameController,
      'performerContact': _performerContactController,
      'performerEmail': _performerEmailController,
    };

    bool updated = false;

    bindings.forEach((fieldId, controller) {
      final text = controller.text.trim();
      if (text.isEmpty) {
        return;
      }

      final existing = _recipientFormValues[fieldId]?.toString().trim();
      if (!overwriteExisting && existing != null && existing.isNotEmpty && existing != text) {
        return;
      }

      if (_recipientFormValues[fieldId]?.toString() == text) {
        return;
      }

      _recipientFormValues[fieldId] = text;
      final controllerRef = _recipientControllers.putIfAbsent(
        fieldId,
        () => TextEditingController(text: text),
      );
      if (controllerRef.text != text) {
        controllerRef.text = text;
      }
      updated = true;
    });

    if (updated && mounted) {
      setState(() {});
    }
  }

  void _syncPerformerFieldToRecipient(
    String fieldId,
    TextEditingController source,
  ) {
    if (_templateSchema == null || !mounted) {
      return;
    }

    final text = source.text.trim();
    final current = _recipientFormValues[fieldId]?.toString() ?? '';
    if (current == text) {
      return;
    }

    setState(() {
      if (text.isEmpty) {
        _recipientFormValues.remove(fieldId);
        final controller = _recipientControllers[fieldId];
        controller?.text = '';
      } else {
        _recipientFormValues[fieldId] = text;
        final controller = _recipientControllers.putIfAbsent(
          fieldId,
          () => TextEditingController(text: text),
        );
        if (controller.text != text) {
          controller.text = text;
        }
      }
    });
  }

  Future<void> _refreshContract() async {
    if (_lastVerifiedName == null || _lastVerifiedEmail == null || _lastVerifiedContact == null) {
      return;
    }
    setState(() => _refreshing = true);
    try {
      final contract = await _contractRepository.verifyContractByToken(
        signatureToken: widget.signatureToken,
        payload: VerifyContractPerformerPayload(
          performerName: _lastVerifiedName!,
          performerEmail: _lastVerifiedEmail!,
          performerContact: _lastVerifiedContact!,
        ),
      );
      await _hydrateContract(contract);
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (mounted && message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _handleDecline() async {
    if (_contract == null || _isDeclined || _isCompleted) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('서명 거절'),
          content: const Text('정말로 서명을 거절하시겠습니까? 계약자에게 별도로 연락해 주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('거절'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _declineSubmitting = true);
    try {
      final updated = await _contractRepository.declineContractByToken(
        signatureToken: widget.signatureToken,
      );
      await _hydrateContract(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서명을 거절했습니다.'), duration: Duration(seconds: 3)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isEmpty ? '서명 거절에 실패했습니다.' : message),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _declineSubmitting = false);
      }
    }
  }

  Future<void> _handleSubmitSignature() async {
    if (_contract == null) return;
    if (_signatureDataUrl == null || _signatureDataUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서명을 작성하거나 이미지를 첨부해 주세요.'), duration: Duration(seconds: 3)),
      );
      return;
    }

    final errors = _validateRecipientForm();
    if (errors.isNotEmpty) {
      setState(() {
        _recipientFormErrors = errors;
        _recipientFormTouched = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 항목을 모두 입력해 주세요.'), duration: Duration(seconds: 3)),
      );
      return;
    }

    setState(() {
      _signatureSubmitting = true;
      _recipientFormErrors = {};
    });

    try {
      final payload = CompleteContractSignaturePayload(
        imageData: _signatureDataUrl!,
        source: _signatureSource ?? 'draw',
        recipientFormValues: _buildRecipientPayload(),
      );

      final updated = await _contractRepository.completeContractByToken(
        signatureToken: widget.signatureToken,
        payload: payload,
      );

      await _hydrateContract(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서명이 완료되었습니다.'), duration: Duration(seconds: 3)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isEmpty ? '서명을 저장하지 못했습니다.' : message),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _signatureSubmitting = false);
      }
    }
  }

  Map<String, dynamic> _buildRecipientPayload() {
    final payload = <String, dynamic>{};
    payload.addAll(_recipientFormValues);
    _recipientCheckboxValues.forEach((key, value) {
      payload[key] = value.toList();
    });
    _recipientControllers.forEach((key, controller) {
      payload[key] = controller.text.trim();
    });
    return payload;
  }

  Map<String, String> _validateRecipientForm() {
    final errors = <String, String>{};
    for (final section in _recipientSections) {
      for (final field in section.fields) {
        // signature 타입은 별도로 검증되므로 제외
        if (field.type.toLowerCase() == 'signature') continue;
        if (!field.required) continue;
        final value = _getRecipientValue(field.id);
        final hasValue = value is String
            ? value.trim().isNotEmpty
            : value is Iterable
                ? value.isNotEmpty
                : value != null;
        if (!hasValue) {
          errors[field.id] = '${field.label}은(는) 필수 항목입니다.';
        }
      }
    }
    return errors;
  }

  bool _areRecipientFieldsComplete(
    List<TemplateFormSection> sections,
    Map<String, dynamic> values,
  ) {
    for (final section in sections) {
      for (final field in section.fields) {
        // signature 타입은 별도로 검증되므로 제외
        if (field.type.toLowerCase() == 'signature') continue;
        if (!field.required) continue;
        if (!_hasValue(values[field.id])) {
          return false;
        }
      }
    }
    return true;
  }

  bool _hasValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  dynamic _getRecipientValue(String fieldId) {
    if (_recipientCheckboxValues.containsKey(fieldId)) {
      return _recipientCheckboxValues[fieldId];
    }
    if (_recipientControllers.containsKey(fieldId)) {
      return _recipientControllers[fieldId]!.text;
    }
    return _recipientFormValues[fieldId];
  }

  Future<void> _openSignatureSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String mode = _signatureMode;
        Uint8List? localPreview = _signaturePreviewBytes;
        String? localSource = _signatureSource;
        bool localModified = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> applySignatureFromPad() async {
              try {
                final data = await _signatureController.toPngBytes();
                if (data == null || data.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('서명을 그려 주세요.'), duration: Duration(seconds: 2)),
                  );
                  return;
                }
                final base64Data = base64Encode(data);
                setState(() {
                  _signatureDataUrl = 'data:image/png;base64,$base64Data';
                  _signaturePreviewBytes = data;
                  _signatureSource = 'draw';
                  _signatureMode = 'draw';
                });
                Navigator.of(context).pop();
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('서명을 저장하지 못했습니다.'), duration: Duration(seconds: 2)),
                );
              }
            }

            Future<void> pickSignatureImage() async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  withData: true,
                );
                if (result == null || result.files.isEmpty) {
                  return;
                }
                final file = result.files.first;
                if (file.bytes == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('선택한 이미지를 불러오지 못했습니다.'), duration: Duration(seconds: 2)),
                  );
                  return;
                }
                final bytes = file.bytes!;
                final mimeType = _inferMimeType(file.extension);
                final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
                setModalState(() {
                  localPreview = bytes;
                  localSource = 'upload';
                  localModified = true;
                });
                setState(() {
                  _signatureDataUrl = dataUrl;
                  _signaturePreviewBytes = bytes;
                  _signatureSource = 'upload';
                  _signatureMode = 'upload';
                });
                Navigator.of(context).pop();
              } catch (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('이미지를 불러오지 못했습니다: $error'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '서명 입력',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ToggleButtons(
                    isSelected: [mode == 'draw', mode == 'upload'],
                    onPressed: (index) {
                      final selectedMode = index == 0 ? 'draw' : 'upload';
                      setModalState(() {
                        mode = selectedMode;
                        if (selectedMode == 'draw' && localModified) {
                          localPreview = null;
                          localSource = null;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    constraints: const BoxConstraints(minWidth: 120, minHeight: 40),
                    children: const [
                      Text('직접 서명'),
                      Text('이미지 첨부'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (mode == 'draw')
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0F111827), blurRadius: 12, offset: Offset(0, 6)),
                        ],
                      ),
                      child: Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.white,
                      ),
                    )
                  else ...[
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0F111827), blurRadius: 12, offset: Offset(0, 6)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: localPreview != null
                          ? Image.memory(localPreview!, fit: BoxFit.contain)
                          : const Text('이미지를 업로드해 주세요.', style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: pickSignatureImage,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('이미지 선택'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (mode == 'draw')
                        TextButton(
                          onPressed: () {
                            _signatureController.clear();
                            setModalState(() {
                              localPreview = null;
                            });
                          },
                          child: const Text('지우기'),
                        ),
                      const Spacer(),
                      if (mode == 'draw')
                        FilledButton(
                          onPressed: applySignatureFromPad,
                          child: const Text('적용'),
                        ),
                    ],
                  ),
                  if (mode == 'upload')
                    const Text(
                      'PNG 또는 JPG 이미지를 권장합니다.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleCompleteRecipientForm() {
    final errors = _validateRecipientForm();
    if (errors.isNotEmpty) {
      setState(() {
        _recipientFormErrors = errors;
        _recipientFormTouched = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 항목을 모두 입력해 주세요.'), duration: Duration(seconds: 3)),
      );
      return;
    }

    setState(() {
      _recipientFormErrors.clear();
      _recipientFormCompleted = true;
      _recipientFormTouched = true;
    });
  }

  void _clearSignature() {
    setState(() {
      _signatureDataUrl = null;
      _signaturePreviewBytes = null;
      _signatureSource = null;
      _signatureMode = 'draw';
    });
  }

  String _inferMimeType(String? extension) {
    final ext = extension?.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';
      case 'webp':
        return 'image/webp';
      case 'png':
      default:
        return 'image/png';
    }
  }

  String _formatKoreanPhoneNumber(String raw) {
    final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return '';
    }
    final digits = digitsOnly.length > 11 ? digitsOnly.substring(0, 11) : digitsOnly;
    final areaLength = digits.startsWith('02') ? 2 : digits.length >= 3 ? 3 : digits.length;
    final area = digits.substring(0, areaLength);
    if (digits.length == areaLength) {
      return area;
    }
    final rest = digits.substring(areaLength);
    if (rest.length <= 4) {
      return '$area-$rest';
    }
    final middleLength = rest.length - 4;
    final middle = rest.substring(0, middleLength);
    final tail = rest.substring(middleLength);
    if (middle.isEmpty) {
      return '$area-$tail';
    }
    return '$area-$middle-$tail';
  }

  Future<void> _handleDownloadContractPdf() async {
    final contract = _contract;
    if (contract == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('계약 정보를 불러오지 못했습니다.'), duration: Duration(seconds: 2)),
      );
      return;
    }

    setState(() => _downloadingPdf = true);

    try {
      final pdfBytes = await _contractRepository.downloadContractPdfByToken(
        signatureToken: widget.signatureToken,
      );

      await _savePdfBytes(pdfBytes, 'contract_${contract.id}_sign.pdf');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('계약서를 PDF로 저장했습니다.'), duration: Duration(seconds: 2)),
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
        setState(() => _downloadingPdf = false);
      }
    }
  }

  Future<void> _savePdfBytes(Uint8List bytes, String filename) async {
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
    final raw = metadata['templateFormValues'];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {}
    }
    return const {};
  }

  Map<String, dynamic> _metadataRecipientValues(Map<String, dynamic>? metadata) {
    if (metadata == null) return {};
    final raw = metadata['recipientFormValues'];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {}
    }
    return {};
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

  List<_StatusStep> _statusSteps(Contract contract) {
    return [
      _StatusStep('기안 완료', contract.createdAt != null),
      _StatusStep('서명 대기', contract.status == 'active' || contract.signatureSentAt != null || _isDeclined),
      _StatusStep('서명 완료', _isCompleted),
    ];
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return _dateFormatter.format(_toKst(date));
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

  String? _buildFilledTemplateHtml() {
    final contract = _contract;
    final content = _templateContent;
    if (contract == null || content == null || content.trim().isEmpty) {
      return null;
    }

    final values = <String, String>{};

    void assign(String key, dynamic raw) {
      if (key.isEmpty) return;
      final normalized = _normalizeValue(raw);
      values[key] = normalized;
    }

    _templateFormValues.forEach((key, value) => assign(key, value));
    _recipientFormValues.forEach((key, value) => assign(key, value));
    _recipientControllers.forEach((key, controller) => assign(key, controller.text));
    _recipientCheckboxValues.forEach((key, value) => assign(key, value.toList()));

    final metadata = _metadata;
    metadata?.forEach((key, value) {
      if (key is! String) return;
      if (key.startsWith('template')) return;
      if (key.startsWith('recipient')) return;
      assign(key, value);
    });

    assign('contractName', contract.name);
    assign('clientName', contract.clientName);
    assign('clientContact', contract.clientContact);
    assign('clientEmail', contract.clientEmail);
    assign('performerName', contract.performerName ?? _performerNameController.text);
    assign('performerContact', contract.performerContact ?? _performerContactController.text);
    assign('performerEmail', contract.performerEmail ?? _performerEmailController.text);
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
    assign('borrowerName', contract.performerName ?? _performerNameController.text);
    assign('borrowerContact', contract.performerContact ?? _performerContactController.text);
    assign('borrowerEmail', contract.performerEmail ?? _performerEmailController.text);
    assign('createdAt', _formatDateTime(contract.createdAt));
    assign('updatedAt', _formatDateTime(contract.updatedAt));
    assign('signatureSentAt', _formatDateTime(contract.signatureSentAt));
    assign('signatureCompletedAt', _formatDateTime(contract.signatureCompletedAt));

    final clientSignedAt = _formatDateTime(metadata?['clientSignedAt']);
    if (clientSignedAt.isNotEmpty && clientSignedAt != '-') {
      assign('clientSignatureDate', clientSignedAt);
      assign('clientSignDate', clientSignedAt);
      assign('lenderSignDate', clientSignedAt);
      assign('employerSignDate', clientSignedAt);
    }

    if (contract.signatureCompletedAt != null) {
      final performerSignedAt = _formatDateTime(contract.signatureCompletedAt);
      if (performerSignedAt.isNotEmpty && performerSignedAt != '-') {
        assign('employeeSignatureDate', performerSignedAt);
        assign('employeeSignDate', performerSignedAt);
        assign('performerSignDate', performerSignedAt);
        assign('borrowerSignDate', performerSignedAt);
      }
    }

    // 갑(계약 작성자)의 서명 이미지 가져오기
    final clientSig = metadata?['authorSignatureImage'] ??
                     metadata?['authorSignature'] ??
                     metadata?['clientSignature'] ??
                     metadata?['clientSignatureImage'];
    if (clientSig is String && clientSig.isNotEmpty) {
      final tag = _signatureImgTag(_resolveSignatureUrl(clientSig));
      if (tag != null) {
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
          values[key] = tag;
        }
      }
    }

    if (_signatureDataUrl != null && _signatureDataUrl!.isNotEmpty) {
      final tag = _signatureImgTag(_signatureDataUrl!);
      if (tag != null) {
        for (final key in const [
          'employeeSignatureImage',
          'employeeSignature',
          'performerSignatureImage',
          'performerSignature',
          'borrowerSignatureImage',
          'borrowerSignature',
        ]) {
          values[key] = tag;
        }
      }
    } else {
      final performerSig = _resolveSignatureUrl(_contract?.signatureImage);
      if (performerSig != null) {
        final tag = _signatureImgTag(performerSig);
        if (tag != null) {
          for (final key in const [
            'employeeSignatureImage',
            'employeeSignature',
            'performerSignatureImage',
            'performerSignature',
            'borrowerSignatureImage',
            'borrowerSignature',
          ]) {
            values[key] = tag;
          }
        }
      }
    }

    final replaced = content.replaceAllMapped(RegExp(r'{{\s*([^}]+)\s*}}'), (match) {
      final key = match.group(1)?.trim();
      if (key == null || key.isEmpty) return '';
      return values[key] ?? '';
    });
    final cleaned = replaced.replaceAll(RegExp(r'{{\s*([^}]+)\s*}}'), '');
    return normalizeContractHtmlLayout(cleaned);
  }

  Map<String, String>? _htmlStylesBuilder(dynamic element) => buildContractHtmlStyles(element);

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

  Widget _buildSignatureDisplayImage(String source) {
    if (source.startsWith('data:')) {
      try {
        final data = Uri.parse(source).data;
        if (data != null) {
          return Image.memory(data.contentAsBytes(), fit: BoxFit.contain);
        }
      } catch (_) {
        // fall through to network rendering
      }
    }
    return Image.network(source, fit: BoxFit.contain);
  }

  String? _signatureImgTag(String? url) {
    if (url == null || url.isEmpty) return null;
    return '<img src="$url" style="max-height:80px;max-width:100%;object-fit:contain;" />';
  }

  String _normalizeValue(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      final trimmed = value.trim();
      if (RegExp(r'^\d{6}-\d$').hasMatch(trimmed)) {
        return '${trimmed.substring(0, 6)}-${trimmed.substring(7, 8)}******';
      }
      return trimmed;
    }
    if (value is num || value is bool) return value.toString();
    if (value is DateTime) return _dateFormatter.format(_toKst(value));
    if (value is Iterable) {
      return value.map(_normalizeValue).where((v) => v.isNotEmpty).join(', ');
    }
    if (value is Map) {
      return value.values.map(_normalizeValue).where((v) => v.isNotEmpty).join(', ');
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final tokenError = _tokenError;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: tokenError != null
            ? _buildTokenError(tokenError)
            : _contract == null
                ? _buildVerificationForm()
                : RefreshIndicator(
                    color: primaryColor,
                    onRefresh: _refreshContract,
                    child: _buildContractView(),
                  ),
      ),
    );
  }

  Widget _buildTokenError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 40, color: Color(0xFF6366F1)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Color(0xFF1F2937), height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '수행자 본인 확인',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 12),
          const Text(
            '이메일로 전달받은 계약 요청에 기재된 정보와 동일하게 입력해 주세요. 정보가 확인되면 계약 내용을 열람하고 서명을 진행할 수 있습니다.',
            style: TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.5),
          ),
          const SizedBox(height: 24),
          _buildInputField(
            label: '이름',
            controller: _performerNameController,
            enabled: !_verifying,
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: '이메일',
            controller: _performerEmailController,
            enabled: !_verifying,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: '연락처',
            controller: _performerContactController,
            enabled: !_verifying,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
            onChanged: (value) {
              final formatted = _formatKoreanPhoneNumber(value);
              if (formatted != value) {
                _performerContactController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
            },
          ),
          if (_formError != null) ...[
            const SizedBox(height: 16),
            Text(
              _formError!,
              style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _verifying ? null : _verifyPerformer,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: _verifying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('계약 확인하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '※ 정보가 일치하지 않으면 서명 링크가 보호되어 계약 내용을 열람할 수 없습니다.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildContractView() {
    final contract = _contract!;
    final htmlPreview = _buildFilledTemplateHtml();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSignTopBar(),
          const SizedBox(height: 16),
          _buildSignHero(contract),
          const SizedBox(height: 20),
          _buildStatusCard(contract),
          if (_recipientSections.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildRecipientFormCard(),
          ],
          const SizedBox(height: 20),
          _buildSignatureCard(contract),
          if (htmlPreview != null) ...[
            const SizedBox(height: 20),
            _buildContractPreview(htmlPreview),
          ],
          const SizedBox(height: 32),
          _buildFooterActions(contract),
        ],
      ),
    );
  }

  Widget _buildRecipientFormStep() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '추가 정보 입력',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
              ),
              if (_refreshing)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Color(0x1F111827), blurRadius: 14, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.assignment_outlined, size: 28, color: primaryColor),
                SizedBox(height: 12),
                Text(
                  '계약에 필요한 추가 정보를 입력해 주세요.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                ),
                SizedBox(height: 8),
                Text(
                  '모든 필수 항목을 제출하면 계약 내용을 확인하고 서명을 진행할 수 있습니다.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildRecipientFormCard(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleCompleteRecipientForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('정보 제출 후 계속', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '계약 서명',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
        ),
        if (_refreshing)
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
          ),
      ],
    );
  }

  Widget _buildSignHero(Contract contract) {
    final statusLabel = _statusLabel(contract);
    final performerName = (contract.performerName?.trim().isNotEmpty ?? false)
        ? contract.performerName!.trim()
        : _performerNameController.text.trim().isNotEmpty
            ? _performerNameController.text.trim()
            : '미정';

    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
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
            child: const Icon(Icons.description_outlined, color: Colors.white, size: 30),
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
          Text('계약 ID #${contract.id}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 12),
          _StatusChip(label: statusLabel, status: contract.status),
          if (_isExpired)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFF97316)),
                  SizedBox(width: 6),
                  Text('계약 기간이 만료되었습니다.', style: TextStyle(fontSize: 12, color: Color(0xFFF97316))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Contract contract) {
    final steps = _statusSteps(contract);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '계약 진행 상태',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
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
              if (_isDeclined)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '서명이 거절되어 절차가 중단되었습니다. 계약자에게 별도로 연락해 주세요.',
                          style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientFormCard() {
    final isCompleted = _recipientFormCompleted;
    final showCompletionHint = !isCompleted && _recipientSections.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('추가 정보 입력', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          const SizedBox(height: 12),
          Text(
            isCompleted
                ? '입력한 정보는 아래에서 서명과 함께 제출됩니다. 필요하면 수정 후 다시 저장하세요.'
                : '계약 본문에 포함될 수행자 정보를 입력해 주세요. 모든 필수 항목을 저장해야 서명 제출이 가능합니다.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 16),
          for (final section in _recipientSections) ...[
            _buildRecipientSection(section),
            if (section != _recipientSections.last) const SizedBox(height: 20),
          ],
          if (showCompletionHint) ...[
            const SizedBox(height: 8),
            Row(
              children: const [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF6366F1)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '필수 입력 항목을 저장하면 서명을 제출할 수 있습니다.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6366F1)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleCompleteRecipientForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: isCompleted ? const Color(0xFF4CAF50) : primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                isCompleted ? '추가 정보 다시 저장' : '추가 정보 저장',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientSection(TemplateFormSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
        ),
        if (section.description != null && section.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              section.description!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        const SizedBox(height: 12),
        for (final field in section.fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildRecipientField(field),
          ),
      ],
    );
  }

  bool _isResidentRecipientField(TemplateFieldDefinition field) {
    final label = field.label;
    final loweredId = field.id.toLowerCase();
    return label.contains('주민') || label.contains('사업자') || loweredId.contains('resident');
  }

  String _extractResidentDigits(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 7) {
      return digits;
    }
    return digits.substring(0, 7);
  }

  String _maskResidentDigits(String digits) {
    if (digits.isEmpty) {
      return '';
    }
    if (digits.length <= 6) {
      return digits;
    }
    final birth = digits.substring(0, 6);
    final gender = digits.substring(6, 7);
    return '$birth-$gender******';
  }

  Widget _buildRecipientField(TemplateFieldDefinition field) {
    final error = _recipientFormErrors[field.id];
    final isResidentField = _isResidentRecipientField(field);
    final displayLabel = isResidentField ? '주민번호' : field.label;
    final helperText = isResidentField
        ? '주민번호는 생년월일 6자리와 성별 식별 숫자(1~4)만 입력하면 실제 번호는 저장되지 않습니다.'
        : field.helperText;

    Widget input;
    final type = field.type.toLowerCase();

    // signature 타입은 별도의 서명 섹션에서 처리되므로 여기서는 제외
    if (type == 'signature') {
      return const SizedBox.shrink();
    }

    if (isResidentField) {
      input = _buildRecipientResidentField(field);
    } else if (type == 'checkbox') {
      final options = field.options;
      final selected = _recipientCheckboxValues[field.id] ?? <String>{};
      input = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map(
              (option) => FilterChip(
                label: Text(option.label),
                selected: selected.contains(option.value),
                onSelected: (value) {
                  setState(() {
                    final set = _recipientCheckboxValues.putIfAbsent(field.id, () => <String>{});
                    if (value) {
                      set.add(option.value);
                    } else {
                      set.remove(option.value);
                    }
                    _recipientFormTouched = true;
                  });
                },
              ),
            )
            .toList(),
      );
    } else if (type == 'radio') {
      final options = field.options;
      final current = _recipientFormValues[field.id]?.toString();
      input = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map(
              (option) => ChoiceChip(
                label: Text(option.label),
                selected: current == option.value,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _recipientFormValues[field.id] = option.value;
                    } else {
                      _recipientFormValues.remove(field.id);
                    }
                    _recipientFormTouched = true;
                  });
                },
              ),
            )
            .toList(),
      );
    } else if (type == 'select') {
      final current = _recipientFormValues[field.id]?.toString();
      input = DropdownButtonFormField<String>(
        value: current?.isNotEmpty == true ? current : null,
        decoration: _inputDecoration(field.placeholder ?? '선택'),
        items: field.options
            .map((option) => DropdownMenuItem<String>(value: option.value, child: Text(option.label)))
            .toList(),
        onChanged: (value) {
          setState(() {
            if (value == null || value.isEmpty) {
              _recipientFormValues.remove(field.id);
            } else {
              _recipientFormValues[field.id] = value;
            }
            _recipientFormTouched = true;
          });
        },
      );
    } else if (type == 'date') {
      final controller = _recipientControllers.putIfAbsent(field.id, () => TextEditingController());

      // readonly 필드인 경우 자동으로 현재 날짜 설정
      if (field.readonly && (_recipientFormValues[field.id] == null || _recipientFormValues[field.id].toString().isEmpty)) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        _recipientFormValues[field.id] = today;
        controller.text = today;
      }

      input = TextField(
        controller: controller,
        readOnly: true,
        enabled: !field.readonly, // readonly 필드는 비활성화
        decoration: _inputDecoration(
          field.readonly
            ? (field.helperText ?? '자동 입력됨')
            : (field.placeholder ?? 'YYYY-MM-DD')
        ),
        onTap: field.readonly ? null : () => _pickRecipientDate(field, controller),
      );
    } else if (type == 'textarea') {
      final controller = _recipientControllers.putIfAbsent(field.id, () => TextEditingController(text: _recipientFormValues[field.id]?.toString() ?? ''));
      input = TextField(
        controller: controller,
        minLines: 4,
        maxLines: 6,
        enabled: !field.readonly,
        decoration: _inputDecoration(field.placeholder ?? ''),
        onChanged: field.readonly ? null : (value) {
          setState(() {
            _recipientFormValues[field.id] = value;
            _recipientFormTouched = true;
          });
        },
      );
    } else if (type == 'phone') {
      final controller =
          _recipientControllers.putIfAbsent(field.id, () => TextEditingController(text: _recipientFormValues[field.id]?.toString() ?? ''));
      input = TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
        enabled: !field.readonly,
        decoration: _inputDecoration(field.placeholder ?? ''),
        onChanged: field.readonly ? null : (value) {
          var formatted = _formatKoreanPhoneNumber(value);
          if (formatted != value) {
            controller.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          }
          if (formatted.isEmpty) {
            formatted = '';
          }
          setState(() {
            if (formatted.isEmpty) {
              _recipientFormValues.remove(field.id);
            } else {
              _recipientFormValues[field.id] = formatted;
            }
            _recipientFormTouched = true;
          });
        },
      );
    } else {
      final controller = _recipientControllers.putIfAbsent(field.id, () => TextEditingController(text: _recipientFormValues[field.id]?.toString() ?? ''));
      TextInputType keyboardType = TextInputType.text;
      List<TextInputFormatter>? formatters;
      if (type == 'number') {
        keyboardType = const TextInputType.numberWithOptions(signed: true, decimal: true);
        formatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]'))];
      } else if (type == 'currency') {
        keyboardType = const TextInputType.numberWithOptions(decimal: true);
        formatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))];
      } else if (type == 'email') {
        keyboardType = TextInputType.emailAddress;
      }
      input = TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        enabled: !field.readonly,
        decoration: _inputDecoration(field.placeholder ?? ''),
        onChanged: field.readonly ? null : (value) {
          setState(() {
            _recipientFormValues[field.id] = value;
            _recipientFormTouched = true;
          });
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              displayLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
            ),
            if (field.required)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('필수', style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        if (helperText != null && helperText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(helperText, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
        const SizedBox(height: 8),
        input,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(error, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
          ),
      ],
    );
  }

  Widget _buildRecipientResidentField(TemplateFieldDefinition field) {
    final controller = _recipientControllers.putIfAbsent(field.id, () => TextEditingController());
    final storedValue = _recipientFormValues[field.id]?.toString();
    if (storedValue != null && storedValue.isNotEmpty) {
      final digits = _extractResidentDigits(storedValue);
      final masked = _maskResidentDigits(digits);
      if (controller.text != masked) {
        controller
          ..text = masked
          ..selection = TextSelection.collapsed(offset: masked.length);
      }
    }

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _inputDecoration('주민번호 (예: 900101-1******)'),
      onChanged: (value) {
        final digits = _extractResidentDigits(value);
        final masked = _maskResidentDigits(digits);
        if (masked != controller.text) {
          controller
            ..text = masked
            ..selection = TextSelection.collapsed(offset: masked.length);
        }
        setState(() {
          if (digits.length >= 7) {
            final birth = digits.substring(0, 6);
            final gender = digits.substring(6, 7);
            _recipientFormValues[field.id] = '$birth-$gender';
          } else if (digits.isNotEmpty) {
            _recipientFormValues[field.id] = digits;
          } else {
            _recipientFormValues.remove(field.id);
          }
          _recipientFormTouched = true;
          _recipientFormErrors.remove(field.id);
        });
      },
    );
  }

  Future<void> _pickRecipientDate(TemplateFieldDefinition field, TextEditingController controller) async {
    final now = DateTime.now();
    final initial = _parseDateTime(controller.text) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        controller.text = formatted;
        _recipientFormValues[field.id] = formatted;
        _recipientFormTouched = true;
      });
    }
  }

  Widget _buildSignatureCard(Contract contract) {
    final isActionDisabled = _isDeclined || _isCompleted || _isExpired;
    final requiresFormCompletion =
        _recipientSections.isNotEmpty && !_recipientFormCompleted && !isActionDisabled;
    final shareUrl = _signatureShareUrl(contract);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('서명 진행', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          const SizedBox(height: 12),
          if (_signaturePreviewBytes != null)
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_signaturePreviewBytes!, fit: BoxFit.contain),
              ),
            )
          else if (_existingPerformerSignatureUrl != null &&
              _existingPerformerSignatureUrl!.isNotEmpty)
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildSignatureDisplayImage(_existingPerformerSignatureUrl!),
              ),
            )
          else
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: const Text('아직 서명이 작성되지 않았습니다.', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
          const SizedBox(height: 16),
          if (!isActionDisabled) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _openSignatureSheet,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('서명 작성하기'),
                  ),
                ),
                const SizedBox(width: 12),
                if (_signatureDataUrl != null)
                  IconButton(
                    onPressed: _clearSignature,
                    tooltip: '서명 지우기',
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_signatureSubmitting || requiresFormCompletion)
                        ? null
                        : _handleSubmitSignature,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: _signatureSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('서명 제출', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _declineSubmitting ? null : _handleDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _declineSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)),
                          )
                        : const Text('서명 거절'),
                  ),
                ),
              ],
            ),
            if (requiresFormCompletion) ...[
              const SizedBox(height: 12),
              Row(
                children: const [
                  Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '추가 정보를 저장해야 서명을 제출할 수 있습니다.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                    ),
                  ),
                ],
              ),
            ],
          ]
          else
            const Text(
              '이미 서명이 완료되었거나 절차가 종료된 계약입니다.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          if (shareUrl != null && shareUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '서명 링크: $shareUrl',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContractPreview(String html) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('계약서 본문', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
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
              textStyle: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF1F2937)),
              customStylesBuilder: _htmlStylesBuilder,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _downloadingPdf ? null : _handleDownloadContractPdf,
            icon: _downloadingPdf
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                  )
                : const Icon(Icons.picture_as_pdf),
            label: Text(
              _downloadingPdf ? 'PDF 생성 중...' : '계약서 PDF 다운로드',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions(Contract contract) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          '서명이 완료되면 계약자에게 자동으로 안내됩니다. 추가 문의 사항이 있다면 별도로 연락해 주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => _copyShareLink(contract),
          icon: const Icon(Icons.link, size: 18),
          label: const Text('서명 링크 복사'),
        ),
      ],
    );
  }

  Future<void> _copyShareLink(Contract contract) async {
    final shareUrl = _signatureShareUrl(contract);
    if (shareUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유 가능한 서명 링크가 없습니다.'), duration: Duration(seconds: 3)),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: shareUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('서명 링크를 복사했습니다.'), duration: Duration(seconds: 3)),
    );
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
        BoxShadow(color: Color(0x14111827), blurRadius: 18, offset: Offset(0, 8)),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(color: Color(0x14111827), blurRadius: 14, offset: Offset(0, 6)),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: _inputDecoration(''),
          onChanged: onChanged,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String placeholder) {
    return InputDecoration(
      hintText: placeholder.isEmpty ? null : placeholder,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryColor),
      ),
      filled: true,
      fillColor: Colors.white,
    );
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

  String _formatAmount(String? amount) {
    if (amount == null || amount.trim().isEmpty) return '-';
    final normalized = amount.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) return amount;
    final value = int.tryParse(normalized);
    if (value == null) return amount;
    return '${NumberFormat.decimalPattern('ko_KR').format(value)} 원';
  }
}

class _StatusStep {
  final String label;
  final bool completed;

  const _StatusStep(this.label, this.completed);
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String? status;

  const _StatusChip({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;

    switch (status) {
      case 'signature_completed':
        background = const Color(0xFFE8F5E9);
        foreground = const Color(0xFF15803D);
        break;
      case 'signature_declined':
        background = const Color(0xFFFEE2E2);
        foreground = const Color(0xFFB91C1C);
        break;
      case 'active':
        background = const Color(0xFFE0E7FF);
        foreground = primaryColor;
        break;
      default:
        background = const Color(0xFFE2E8F0);
        foreground = const Color(0xFF1F2937);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }
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
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _buildIndicator(),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: completed ? primaryColor : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: completed ? primaryColor : const Color(0xFF475569),
                ),
              ),
              if (timestamp != null && timestamp!.isNotEmpty && timestamp != '-')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    timestamp!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIndicator() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: completed ? primaryColor : const Color(0x1F4F46E5),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Icon(
        completed ? Icons.check : Icons.circle_outlined,
        size: 16,
        color: completed ? Colors.white : const Color(0xFF94A3B8),
      ),
    );
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
            ),
          ),
        ],
      ),
    );
  }
}
