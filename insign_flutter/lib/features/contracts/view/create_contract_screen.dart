// lib/features/contracts/view/create_contract_screen.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/data/auth_repository.dart';
import 'package:insign/data/contract_repository.dart';
import 'package:insign/data/services/api_client.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/data/template_repository.dart';
import 'package:insign/features/auth/cubit/auth_cubit.dart';
import 'package:insign/features/templates/view/template_pdf_view_screen.dart';
import 'package:insign/features/contracts/utils/html_layout_utils.dart';
import 'package:insign/models/template_form.dart';
import 'package:insign/models/template.dart';
import 'package:insign/models/user.dart';
import 'package:insign/models/signature_image_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';
import 'package:image/image.dart' as img;

class CreateContractScreen extends StatefulWidget {
  final int? templateId;

  const CreateContractScreen({super.key, this.templateId});

  @override
  State<CreateContractScreen> createState() => _CreateContractScreenState();
}

class _CreateContractScreenState extends State<CreateContractScreen> {
  final _formKey = GlobalKey<FormState>();
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');
  final ContractRepository _contractRepository = ContractRepository();
  final TemplateRepository _templateRepository = TemplateRepository();
  final KoreanPhoneNumberFormatter _phoneNumberFormatter =
      KoreanPhoneNumberFormatter();

  Template? _template;
  bool _templateLoading = false;
  String? _templateError;
  bool _hasAppliedTemplateDefaults = false;
  TemplateFormSchema? _templateSchema;
  List<TemplateFormSection> _authorSections = const [];
  List<TemplateFormSection> _performerSections = const [];
  final Map<String, dynamic> _templateFieldValues = {};
  final Map<String, String> _templateFieldErrors = {};
  final Map<String, TextEditingController> _templateFieldControllers = {};
  final Map<String, Set<String>> _templateCheckboxValues = {};
  final Map<String, TextEditingController> _residentControllers = {};
  final Map<String, TextEditingController> _businessControllers = {};
  final Map<String, VoidCallback> _authorTemplateListeners = {};
  final ScrollController _stepScrollController = ScrollController();
  int _currentStep = 0;
  static final RegExp _htmlPlaceholderPattern = RegExp(r'{{\s*([^}]+)\s*}}');
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: const Color(0xFF111827),
    exportBackgroundColor: Colors.transparent, // 투명 배경
  );
  String _signatureMode = 'draw';
  Uint8List? _authorSignatureBytes;
  String? _authorSignatureSource;
  double _signatureScale = 1.0; // 서명 크기 배율 (0.5 ~ 2.0)
  bool _showContractPreview = false; // 계약서 미리보기 표시 여부
  String? _activeFieldId; // A4 스타일: 현재 포커스된 필드 ID
  final Map<String, SignatureImageData?> _signatureImages = {}; // 필드별 서명 이미지
  static const Set<String> _businessRegistrationFieldIds = {
    'businessRegistrationNumber',
    'companyBusinessNumber',
  };

  // Form controllers
  final TextEditingController _contractNameController = TextEditingController();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientContactController =
      TextEditingController();
  final TextEditingController _clientEmailController = TextEditingController();
  final TextEditingController _performerNameController =
      TextEditingController();
  final TextEditingController _performerContactController =
      TextEditingController();
  final TextEditingController _performerEmailController =
      TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSaving = false;
  bool _includeAmount = false;
  DateTime? _authorSignatureAppliedAt;

  // 템플릿이 로드되면 (일반 작성이든 템플릿 작성이든) 템플릿 플로우 사용
  bool get _isTemplateFlow => _template != null;

  bool get _collectPerformerInBasicStep => _isTemplateFlow;

  void _scrollToTop() {
    if (_stepScrollController.hasClients) {
      _stepScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  List<String> get _steps {
    if (_isTemplateFlow) {
      return ['기본 정보', '계약 항목 & 서명', '서명 요청'];
    }
    return ['기본 정보', '계약 조건', '수행자 정보', '요약'];
  }

  // 현재 Step의 필드 카운트 (채워진 개수/전체 개수)
  String _getFieldCount() {
    int total = 0;
    int filled = 0;

    switch (_currentStep) {
      case 0: // 기본 정보
        total = 3; // 계약서 제목, 갑 이름, 갑 이메일
        if (_contractNameController.text.trim().isNotEmpty) filled++;
        if (_clientNameController.text.trim().isNotEmpty) filled++;
        if (_clientEmailController.text.trim().isNotEmpty) filled++;
        if (_collectPerformerInBasicStep) {
          total += 3; // 을 이름, 이메일, 연락처
          if (_performerNameController.text.trim().isNotEmpty) filled++;
          if (_performerEmailController.text.trim().isNotEmpty) filled++;
          if (_performerContactController.text.trim().isNotEmpty) filled++;
        }
        break;
      case 1: // 계약 항목 & 서명 또는 계약 조건
        if (_isTemplateFlow) {
          // 템플릿 필드 개수 계산
          for (final section in _authorSections) {
            for (final field in section.fields) {
              total++;
              if (field.type == 'signature') {
                // 템플릿 signature 필드는 서명 이미지 등록 여부 기준
                final signatureData = _signatureImages[field.id];
                if (signatureData != null) {
                  filled++;
                }
              } else {
                final value = _templateFieldValues[field.id];
                if (value != null && value.toString().trim().isNotEmpty) {
                  filled++;
                }
              }
            }
          }
        } else {
          total = 2; // 시작일, 종료일
          if (_startDate != null) filled++;
          if (_endDate != null) filled++;
        }
        break;
      case 2: // 서명 요청 또는 수행자 정보
        if (_isTemplateFlow) {
          total = 0; // 최종 확인 단계
          filled = 0;
        } else {
          total = 3; // 수행자 이름, 이메일, 연락처
          if (_performerNameController.text.trim().isNotEmpty) filled++;
          if (_performerEmailController.text.trim().isNotEmpty) filled++;
          if (_performerContactController.text.trim().isNotEmpty) filled++;
        }
        break;
    }

    return '($filled/$total)';
  }

  @override
  void initState() {
    super.initState();
    _includeAmount = _amountController.text.isNotEmpty;
    _loadUserInfo();
    _registerAuthorFieldBindings();
    if (widget.templateId != null) {
      _loadTemplate(widget.templateId!);
    } else {
      _loadDefaultTemplate();
    }
    // 임시 저장 불러오기 (템플릿 로딩 후)
    Future.delayed(const Duration(milliseconds: 500), () {
      _loadDraft();
    });
  }

  @override
  void didUpdateWidget(covariant CreateContractScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.templateId != oldWidget.templateId) {
      _hasAppliedTemplateDefaults = false;
      if (widget.templateId != null) {
        _loadTemplate(widget.templateId!);
      } else {
        setState(() {
          _template = null;
          _templateError = null;
          _templateLoading = false;
        });
        _loadDefaultTemplate();
      }
    }
  }

  @override
  void dispose() {
    _disposeAuthorFieldBindings();
    _contractNameController.dispose();
    _clientNameController.dispose();
    _clientContactController.dispose();
    _clientEmailController.dispose();
    _performerNameController.dispose();
    _performerContactController.dispose();
    _performerEmailController.dispose();
    _amountController.dispose();
    _detailsController.dispose();
    for (final controller in _templateFieldControllers.values) {
      controller.dispose();
    }
    for (final controller in _residentControllers.values) {
      controller.dispose();
    }
    for (final controller in _businessControllers.values) {
      controller.dispose();
    }
    _stepScrollController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  void _showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: isError ? Colors.red : const Color(0xFF6A4C93),
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  void _loadUserInfo() {
    final authCubit = context.read<AuthCubit>();
    final user = authCubit.currentUser;

    if (user != null) {
      // 로그인한 사용자 정보로 갑(작성자) 정보 자동 채우기
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        _clientNameController.text = user.displayName!;
      }
      if (user.email.isNotEmpty) {
        _clientEmailController.text = user.email;
      }
      // 연락처는 User 모델에 없으므로 사용자가 직접 입력해야 함
    }
  }

  Future<void> _loadTemplate(int templateId) async {
    setState(() {
      _templateLoading = true;
      _templateError = null;
    });

    try {
      final token = await SessionService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('템플릿 정보를 불러오려면 로그인이 필요합니다.');
      }
      final template = await _templateRepository.fetchTemplate(
        templateId,
        token: token,
      );
      if (!mounted) return;
      setState(() {
        _template = template;
        _templateLoading = false;
        _templateError = null;
      });
      _initializeTemplateSchema(template);
      _applyTemplateDefaults(template);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _templateLoading = false;
        _templateError = message.isEmpty ? '템플릿 정보를 불러오지 못했습니다.' : message;
      });
    }
  }

  Future<void> _loadDefaultTemplate() async {
    // "그냥 작성" 시 백엔드에서 기본 템플릿 ID를 가져옴
    if (widget.templateId != null) return;

    try {
      final token = await SessionService.getAccessToken();
      if (token == null || token.isEmpty) {
        return;
      }

      final response = await ApiClient.request<Map<String, dynamic>>(
        path: '/templates/default/id',
        method: 'GET',
        token: token,
        fromJson: (json) => json,
      );

      final defaultTemplateId = response['defaultTemplateId'] as int?;
      if (defaultTemplateId != null && mounted) {
        _loadTemplate(defaultTemplateId);
      }
    } catch (error) {
      // 기본 템플릿을 못 찾은 경우 fallback으로 ID=5 사용
      if (mounted) {
        _loadTemplate(5);
      }
    }
  }

  // 임시 저장 기능
  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftKey = 'contract_draft_${widget.templateId ?? "default"}';

      final draftData = {
        'contractName': _contractNameController.text,
        'clientName': _clientNameController.text,
        'clientContact': _clientContactController.text,
        'clientEmail': _clientEmailController.text,
        'performerName': _performerNameController.text,
        'performerContact': _performerContactController.text,
        'performerEmail': _performerEmailController.text,
        'amount': _amountController.text,
        'details': _detailsController.text,
        'includeAmount': _includeAmount,
        'startDate': _startDate?.toIso8601String(),
        'endDate': _endDate?.toIso8601String(),
        'currentStep': _currentStep,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await prefs.setString(draftKey, jsonEncode(draftData));

      if (mounted) {
        Fluttertoast.showToast(
          msg: '임시 저장되었습니다',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: const Color(0xFF4CAF50),
          textColor: Colors.white,
        );
      }
    } catch (error) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: '임시 저장에 실패했습니다',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftKey = 'contract_draft_${widget.templateId ?? "default"}';
      final draftJson = prefs.getString(draftKey);

      if (draftJson == null || draftJson.isEmpty) return;

      final draftData = jsonDecode(draftJson) as Map<String, dynamic>;

      setState(() {
        _contractNameController.text = draftData['contractName'] ?? '';
        _clientNameController.text = draftData['clientName'] ?? '';
        _clientContactController.text = draftData['clientContact'] ?? '';
        _clientEmailController.text = draftData['clientEmail'] ?? '';
        _performerNameController.text = draftData['performerName'] ?? '';
        _performerContactController.text = draftData['performerContact'] ?? '';
        _performerEmailController.text = draftData['performerEmail'] ?? '';
        _amountController.text = draftData['amount'] ?? '';
        _detailsController.text = draftData['details'] ?? '';
        _includeAmount = draftData['includeAmount'] ?? false;

        if (draftData['startDate'] != null) {
          _startDate = DateTime.tryParse(draftData['startDate']);
        }
        if (draftData['endDate'] != null) {
          _endDate = DateTime.tryParse(draftData['endDate']);
        }
        _currentStep = draftData['currentStep'] ?? 0;
      });

      if (mounted) {
        Fluttertoast.showToast(
          msg: '임시 저장된 내용을 불러왔습니다',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: const Color(0xFF4F46E5),
          textColor: Colors.white,
        );
      }
    } catch (error) {
      // 임시 저장 불러오기 실패는 조용히 처리
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftKey = 'contract_draft_${widget.templateId ?? "default"}';
      await prefs.remove(draftKey);
    } catch (error) {
      // 조용히 처리
    }
  }

  void _registerAuthorFieldBindings() {
    _disposeAuthorFieldBindings();
    final bindings = <String, TextEditingController>{
      'clientName': _clientNameController,
      'clientContact': _clientContactController,
      'clientEmail': _clientEmailController,
    };

    bindings.forEach((fieldId, controller) {
      void listener() => _syncAuthorFieldToTemplate(fieldId, controller);
      controller.addListener(listener);
      _authorTemplateListeners[fieldId] = listener;
    });
  }

  void _disposeAuthorFieldBindings() {
    final bindings = <String, TextEditingController>{
      'clientName': _clientNameController,
      'clientContact': _clientContactController,
      'clientEmail': _clientEmailController,
    };

    _authorTemplateListeners.forEach((fieldId, listener) {
      bindings[fieldId]?.removeListener(listener);
    });
    _authorTemplateListeners.clear();
  }

  void _applyTemplateDefaults(Template template) {
    if (_hasAppliedTemplateDefaults) {
      return;
    }

    setState(() {
      _templateFieldValues.clear();
      _templateFieldErrors.clear();
      for (final controller in _templateFieldControllers.values) {
        controller.dispose();
      }
      _templateFieldControllers.clear();
      _templateCheckboxValues.clear();
      for (final controller in _residentControllers.values) {
        controller.dispose();
      }
      _residentControllers.clear();
      for (final controller in _businessControllers.values) {
        controller.dispose();
      }
      _businessControllers.clear();

      // 템플릿 필드 초기화 (섹션은 이미 _initializeTemplateSchema에서 설정됨)
      if (_templateSchema != null) {
        _initializeTemplateFieldValues(template);
      }
    });

    if (_contractNameController.text.trim().isEmpty) {
      _contractNameController.text = template.name;
    }

    final normalizedContent = _normalizeTemplateContent(template.content);
    if (_detailsController.text.trim().isEmpty &&
        normalizedContent.isNotEmpty &&
        !normalizedContent.contains('{{')) {
      _detailsController.text = normalizedContent;
    }

    _applyAuthorDefaultsToTemplate(overwriteExisting: false);
    _hasAppliedTemplateDefaults = true;
  }

  void _initializeTemplateSchema(Template template) {
    final schema = TemplateFormSchema.tryParse(template.formSchema);
    setState(() {
      _templateSchema = schema;

      // 스키마가 있으면 섹션 분리
      if (schema != null) {
        _authorSections = schema.selectSections(
          allowedRoles: const ['author'],
          includeAll: true,
        );
        _performerSections = schema.selectSections(
          allowedRoles: const ['recipient', 'witness', 'viewer'],
          includeAll: false,
        );
      } else {
        _authorSections = const [];
        _performerSections = const [];
      }
    });
  }

  void _initializeTemplateFieldValues(Template template) {
    for (final section in _authorSections) {
      for (final field in section.fields) {
        _templateFieldValues.remove(field.id);
        _templateCheckboxValues.remove(field.id);

        if (_isResidentRegistrationField(field)) {
          final controller = _residentControllers.putIfAbsent(
            field.id,
            () => TextEditingController(),
          );
          controller
            ..text = ''
            ..selection = const TextSelection.collapsed(offset: 0);
          continue;
        }

        if (_isBusinessRegistrationField(field)) {
          final controller = _businessControllers.putIfAbsent(
            field.id,
            () => TextEditingController(),
          );
          controller
            ..text = ''
            ..selection = const TextSelection.collapsed(offset: 0);
          continue;
        }

        if (_isTextInputField(field.type)) {
          final controller = _templateFieldControllers.putIfAbsent(
            field.id,
            () => TextEditingController(),
          );
          controller
            ..text = ''
            ..selection = const TextSelection.collapsed(offset: 0);
        }

        _applyTemplateFieldDefault(field);
      }
    }
  }

  void _applyTemplateFieldDefault(TemplateFieldDefinition field) {
    final defaultValue = field.defaultValue;
    if (defaultValue == null || _templateFieldValues.containsKey(field.id)) {
      return;
    }
    final type = field.type.toLowerCase();
    if (type == 'checkbox') {
      if (_isSingleCheckboxField(field)) {
        _templateFieldValues[field.id] = _coerceBoolValue(defaultValue);
      } else {
        final defaults = _coerceCheckboxDefaultValues(defaultValue);
        if (defaults.isNotEmpty) {
          _templateCheckboxValues[field.id] = defaults.toSet();
          _templateFieldValues[field.id] = defaults;
        }
      }
      return;
    }

    _templateFieldValues[field.id] = defaultValue;
    if (_isTextInputField(type)) {
      final controller = _templateFieldControllers[field.id];
      if (controller != null) {
        controller
          ..text = defaultValue.toString()
          ..selection = TextSelection.collapsed(offset: controller.text.length);
      }
    }
  }

  void _applyAuthorDefaultsToTemplate({required bool overwriteExisting}) {
    if (_templateSchema == null || _template == null) {
      return;
    }

    final bindings = <String, TextEditingController>{
      'clientName': _clientNameController,
      'clientContact': _clientContactController,
      'clientEmail': _clientEmailController,
    };

    bool updated = false;

    bindings.forEach((fieldId, controller) {
      final text = controller.text.trim();
      if (!overwriteExisting) {
        final existing = _templateFieldValues[fieldId]?.toString().trim();
        if (existing != null && existing.isNotEmpty && existing != text) {
          return;
        }
      }

      if (text.isEmpty) {
        return;
      }

      if (_templateFieldValues[fieldId]?.toString() == text) {
        return;
      }

      _templateFieldValues[fieldId] = text;
      final fieldController = _templateFieldControllers[fieldId];
      if (fieldController != null && fieldController.text != text) {
        fieldController.text = text;
      }
      _templateFieldErrors.remove(fieldId);
      updated = true;
    });

    if (updated && mounted) {
      setState(() {});
    }
  }

  void _syncAuthorFieldToTemplate(
    String fieldId,
    TextEditingController source,
  ) {
    if (_templateSchema == null || _template == null || !mounted) {
      return;
    }

    final text = source.text.trim();
    final current = _templateFieldValues[fieldId]?.toString() ?? '';
    if (current == text) {
      return;
    }

    setState(() {
      if (text.isEmpty) {
        _templateFieldValues.remove(fieldId);
        final controller = _templateFieldControllers[fieldId];
        controller?.text = '';
      } else {
        _templateFieldValues[fieldId] = text;
        final controller = _templateFieldControllers[fieldId];
        if (controller != null && controller.text != text) {
          controller.text = text;
        }
      }
      _templateFieldErrors.remove(fieldId);
    });
  }

  bool _isTextInputField(String type) {
    return {
      'text',
      'textarea',
      'number',
      'currency',
      'email',
      'phone',
      'date',
    }.contains(type);
  }

  bool _isSingleCheckboxField(TemplateFieldDefinition field) {
    return field.type.toLowerCase() == 'checkbox' && field.options.isEmpty;
  }

  bool _coerceBoolValue(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  List<String> _coerceCheckboxDefaultValues(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return [value.trim()];
    }
    return const [];
  }

  String _displayTemplateFieldLabel(TemplateFieldDefinition field) {
    return _isResidentRegistrationField(field) ? '주민번호' : field.label;
  }

  bool _isResidentRegistrationField(TemplateFieldDefinition field) {
    final label = field.label;
    final loweredId = field.id.toLowerCase();
    return label.contains('주민') || loweredId.contains('resident');
  }

  bool _isBusinessRegistrationField(TemplateFieldDefinition field) {
    final label = field.label;
    final loweredId = field.id.toLowerCase();
    return label.contains('사업자') || loweredId.contains('business');
  }

  Future<void> _pickTemplateDate(TemplateFieldDefinition field) async {
    final existing = _templateFieldValues[field.id]?.toString();
    DateTime initialDate;
    if (existing != null && existing.isNotEmpty) {
      final parsed = DateTime.tryParse(existing);
      initialDate = parsed ?? DateTime.now();
    } else {
      initialDate = DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ko', 'KR'),
    );

    if (picked != null) {
      final value = _dateFormatter.format(picked);
      setState(() {
        _templateFieldValues[field.id] = value;
        _templateFieldErrors.remove(field.id);
      });
      final controller = _templateFieldControllers[field.id];
      controller?.text = value;
    }
  }

  void _updateTemplateTextValue(TemplateFieldDefinition field, String value) {
    setState(() {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        _templateFieldValues.remove(field.id);
      } else {
        _templateFieldValues[field.id] = value;
      }
      _templateFieldErrors.remove(field.id);
    });
  }

  void _updateTemplateSelectValue(
      TemplateFieldDefinition field, String? value) {
    setState(() {
      if (value == null || value.isEmpty) {
        _templateFieldValues.remove(field.id);
      } else {
        _templateFieldValues[field.id] = value;
      }
      _templateFieldErrors.remove(field.id);
    });
  }

  void _toggleTemplateCheckboxValue(
      TemplateFieldDefinition field, String optionValue, bool selected) {
    final current = _templateCheckboxValues[field.id] ?? <String>{};
    if (selected) {
      current.add(optionValue);
    } else {
      current.remove(optionValue);
    }

    setState(() {
      _templateCheckboxValues[field.id] = current;
      if (current.isEmpty) {
        _templateFieldValues.remove(field.id);
      } else {
        _templateFieldValues[field.id] = current.toList();
      }
      _templateFieldErrors.remove(field.id);
    });
  }

  void _updateTemplateBooleanCheckbox(
      TemplateFieldDefinition field, bool value) {
    setState(() {
      _templateFieldValues[field.id] = value;
      _templateFieldErrors.remove(field.id);
    });
  }

  TextEditingController _getTemplateTextController(
      TemplateFieldDefinition field) {
    if (_templateFieldControllers.containsKey(field.id)) {
      return _templateFieldControllers[field.id]!;
    }
    final initial = _templateFieldValues[field.id]?.toString() ?? '';
    final controller = TextEditingController(text: initial);
    _templateFieldControllers[field.id] = controller;
    return controller;
  }

  String _normalizeTemplateContent(String raw) {
    if (raw.isEmpty) {
      return '';
    }

    var text = raw
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text.replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&');
    return text.trim();
  }

  String _formatTemplateUpdatedAt(DateTime? date) {
    if (date == null) {
      return '업데이트 예정';
    }
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _openTemplatePreview() {
    final template = _template;
    if (template == null) {
      return Future.value();
    }
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemplatePdfViewScreen(templateId: template.id),
      ),
    );
  }

  void _goToPreviousStep() {
    if (_currentStep == 0) {
      return;
    }
    setState(() {
      _currentStep -= 1;
    });
    _scrollToTop();
  }

  void _goToNextStep() {
    if (!_validateStep(_currentStep)) {
      return;
    }
    if (_currentStep >= _steps.length - 1) {
      return;
    }
    setState(() {
      _currentStep += 1;
    });
    _scrollToTop();
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: [
        for (int index = 0; index < _steps.length; index++) ...[
          if (index != 0) const SizedBox(width: 8),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              decoration: BoxDecoration(
                color: index <= _currentStep
                    ? primaryColor
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepChip(int index) {
    final bool isActive = index == _currentStep;
    final bool isCompleted = index < _currentStep;
    final Color strokeColor =
        isActive || isCompleted ? primaryColor : const Color(0xFFD1D5DB);
    final Color backgroundColor = isCompleted
        ? primaryColor
        : (isActive ? primaryColor.withOpacity(0.1) : Colors.white);
    final Color labelColor = isCompleted
        ? Colors.white
        : (isActive ? primaryColor : const Color(0xFF475569));
    final Color badgeBackground = isCompleted
        ? Colors.white
        : (isActive ? primaryColor : const Color(0xFFE2E8F0));
    final Color badgeTextColor = isCompleted
        ? primaryColor
        : (isActive ? Colors.white : const Color(0xFF475569));

    return InkWell(
      onTap: index < _currentStep
          ? () {
              setState(() => _currentStep = index);
              _scrollToTop();
            }
          : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: strokeColor, width: 1.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badgeBackground,
                border: Border.all(
                    color: strokeColor, width: isCompleted ? 0 : 0.8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: badgeTextColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _steps[index],
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateHeader() {
    if (_template == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _template!.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'General Contract',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF5A6C7D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
        ],
      ),
    );
  }

  List<Widget> _buildStepContent() {
    final content = <Widget>[];

    // 템플릿 헤더 추가 (첫 번째 Step에만)
    if (_currentStep == 0 && _template != null) {
      content.add(_buildTemplateHeader());
    }

    switch (_currentStep) {
      case 0:
        content.addAll(_buildBasicInfoStep());
        break;
      case 1:
        if (_isTemplateFlow) {
          // 템플릿 기반 계약: 계약 항목만 표시 (의뢰인 서명 섹션 제거)
          content.addAll(_buildTemplateAuthorStep());
        } else {
          content.addAll(_buildContractConditionsStep());
        }
        break;
      case 2:
        content.addAll(_isTemplateFlow
            ? _buildSummaryStep()
            : _buildPerformerStep());
        break;
    }

    return content;
  }

  List<Widget> _buildBasicInfoStep() {
    final widgets = <Widget>[
      _buildSectionCard(
        title: '계약서 정보',
        icon: Icons.description,
        children: [
          _buildTextField(
            controller: _contractNameController,
            label: '계약서 제목',
            hint: '예: 프리랜서 업무 계약',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '계약서 제목을 입력해주세요';
              }
              return null;
            },
          ),
        ],
      ),
      const SizedBox(height: 16),
      _buildSectionCard(
        title: '갑 (의뢰인)',
        icon: Icons.person_outline,
        subtitle: '로그인한 회원 정보로 자동 입력됩니다.',
        children: [
          _buildTextField(
            controller: _clientNameController,
            label: '이름',
            hint: '홍길동',
            readOnly: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '갑 이름을 입력해주세요';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _clientEmailController,
            label: '이메일',
            hint: 'client@example.com',
            keyboardType: TextInputType.emailAddress,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _clientContactController,
            label: '연락처',
            hint: '010-1234-5678',
            keyboardType: TextInputType.phone,
            inputFormatters: [_phoneNumberFormatter],
          ),
        ],
      ),
    ];

    if (_collectPerformerInBasicStep) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(
          _buildPerformerSection(
            title: '을 (수행자)',
            showEmailReminder: true,
          ),
        );
    }

    return widgets;
  }

  List<Widget> _buildContractConditionsStep() {
    return [
      _buildSectionCard(
        title: '계약 조건',
        icon: Icons.calendar_today,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  label: '시작일',
                  date: _startDate,
                  onTap: () => _selectDate(context, true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField(
                  label: '종료일',
                  date: _endDate,
                  onTap: () => _selectDate(context, false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '계약 금액 입력',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              Switch.adaptive(
                value: _includeAmount,
                activeColor: primaryColor,
                onChanged: (value) {
                  setState(() {
                    _includeAmount = value;
                    if (!value) {
                      _amountController.clear();
                    }
                  });
                },
              ),
            ],
          ),
          if (_includeAmount) ...[
            const SizedBox(height: 12),
            _buildTextField(
              controller: _amountController,
              label: '계약 금액',
              hint: '1,000,000',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              suffixText: '원',
            ),
          ],
        ],
      ),
      const SizedBox(height: 16),
      _buildSectionCard(
        title: '계약 상세 내용',
        icon: Icons.notes,
        children: [
          _buildTextField(
            controller: _detailsController,
            label: '상세 내용',
            hint: '계약 상세 내용을 입력하세요...',
            maxLines: null, // 무제한
            minLines: 4, // 최소 4줄 표시
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildTemplateAuthorStep() {
    if (_templateLoading) {
      return [_buildTemplateLoadingCard()];
    }
    if (_templateError != null) {
      return [_buildTemplateErrorCard(_templateError!)];
    }
    if (_authorSections.isEmpty) {
      return [_buildTemplateEmptyCard()];
    }

    // 모든 섹션을 하나의 A4 카드 안에 표시
    return [
      _buildA4DocumentWrapper(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 모든 섹션을 순차적으로 표시
            ...(_authorSections.asMap().entries.map((entry) {
              final index = entry.key;
              final section = entry.value;
              return Column(
                children: [
                  if (index > 0) const SizedBox(height: 24), // 섹션 간 간격
                  _buildTemplateSectionContent(section),
                ],
              );
            }).toList()),

            // 계약서 내용 미리보기
            const SizedBox(height: 32),
            const Divider(thickness: 2, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 24),
            _buildContractPreviewInStep1(),
          ],
        ),
      ),
    ];
  }

  /// Step 1에서 보여줄 계약서 미리보기
  Widget _buildContractPreviewInStep1() {
    final html = _generateFilledTemplateHtml();

    if (html == null || html.trim().isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              size: 20,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '계약서 내용이 없습니다.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 미리보기 제목
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF3F5F9),
            border: Border(
              top: BorderSide(color: Color(0xFFD4D9E2), width: 0.5),
              bottom: BorderSide(color: Color(0xFFD4D9E2), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.description_outlined,
                size: 16,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              const Text(
                '계약서 내용 미리보기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF59D).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '입력 시 자동 업데이트',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // HTML 내용 + 서명 이미지 오버레이
        _buildContractPreviewWithSignatures(html),
      ],
    );
  }

  Widget _buildContractPreviewWithSignatures(String html) {
    // 서명 이미지는 HTML에 직접 삽입되므로 오버레이 없이 표시
    return HtmlWidget(
      html,
      textStyle: const TextStyle(
        fontSize: 13,
        height: 1.6,
        color: Color(0xFF111827),
      ),
      customStylesBuilder: buildContractHtmlStyles,
    );
  }

  // 오버레이 방식은 제거됨 - 슬라이더 방식으로 변경

  Widget _buildDraggableResizableImage(
    TemplateFieldDefinition field,
    SignatureImageData signatureData,
  ) {
    // 사용되지 않음 - 슬라이더 방식으로 변경됨
    return const SizedBox.shrink();
  }

  // 드래그/리사이즈 방식은 제거됨 - 슬라이더 방식으로 대체

  List<Widget> _buildTemplateSignatureStep() {
    final widgets = <Widget>[
      _buildTemplateSignerGuide(),
      const SizedBox(height: 12),
    ];

    if (!_collectPerformerInBasicStep) {
      widgets
        ..add(_buildPerformerSection(showEmailReminder: true))
        ..add(const SizedBox(height: 12));
    }

    widgets
      ..add(_buildAuthorSignatureSection())
      ..add(const SizedBox(height: 12))
      ..add(_buildSignaturePlaceholderCard());
    return widgets;
  }

  List<Widget> _buildPerformerStep() {
    return [_buildPerformerSection(showEmailReminder: true)];
  }

  List<Widget> _buildSummaryStep() {
    final widgets = <Widget>[
      _buildSummaryCard(),
    ];
    if (widget.templateId != null && _authorSections.isNotEmpty) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(_buildTemplateSummaryPreview());
    }
    widgets.add(const SizedBox(height: 32));
    return widgets;
  }

  Widget _buildPerformerSection({
    String title = '수행자 정보',
    bool showEmailReminder = false,
  }) {
    return _buildSectionCard(
      title: title,
      icon: Icons.work_outline,
      subtitle:
          showEmailReminder ? '서명 요청 메일을 발송하려면 수행자 이름과 이메일을 모두 입력하세요.' : null,
      children: [
        _buildTextField(
          controller: _performerNameController,
          label: '이름',
          hint: '김수행',
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _performerContactController,
          label: '연락처',
          hint: '010-5678-1234',
          keyboardType: TextInputType.phone,
          inputFormatters: [_phoneNumberFormatter],
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _performerEmailController,
          label: '이메일',
          hint: 'performer@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  Widget _buildTemplateLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _templateCardDecoration(),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(color: primaryColor),
      ),
    );
  }

  Widget _buildTemplateErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _templateCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '템플릿을 불러오지 못했습니다.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: Color(0xFF7F1D1D)),
          ),
          const SizedBox(height: 12),
          if (widget.templateId != null)
            OutlinedButton.icon(
              onPressed: _templateLoading
                  ? null
                  : () => _loadTemplate(widget.templateId!),
              icon: const Icon(Icons.refresh, size: 18, color: primaryColor),
              label: const Text('다시 시도'),
            ),
        ],
      ),
    );
  }

  Widget _buildTemplateEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _templateCardDecoration(),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: primaryColor),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '추가로 입력할 계약 항목이 없습니다.',
              style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignaturePlaceholderCard() {
    return _buildInfoNotice(
      icon: Icons.info_outline,
      title: '서명 요청 안내',
      message: '등록한 서명은 요약 단계에서 미리 확인할 수 있으며, 계약 저장 시 함께 전송됩니다.',
    );
  }

  // Step 2에서 사용하는 서명 섹션 (모달 오픈 버튼)
  Widget _buildSignatureSection() {
    final bool hasSignature = _authorSignatureBytes != null;

    return _buildSectionCard(
      title: '의뢰인 서명',
      icon: Icons.draw_outlined,
      subtitle: hasSignature
          ? '서명이 등록되었습니다. 아래 미리보기에서 크기를 조절할 수 있습니다.'
          : '계약서에 들어갈 서명 또는 도장을 등록하세요.',
      children: [
        if (hasSignature) ...[
          // 서명 미리보기 (작게)
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Image.memory(
              _authorSignatureBytes!,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showSignatureModal,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('서명 수정'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _authorSignatureBytes = null;
                      _authorSignatureSource = null;
                      _authorSignatureAppliedAt = null;
                      _showContractPreview = false;
                      _signatureScale = 1.0;
                    });
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('서명 삭제'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showSignatureModal,
              icon: const Icon(Icons.edit, size: 20),
              label: const Text('서명/도장 등록'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 서명 입력 모달
  void _showSignatureModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 모달 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    '서명/도장 등록',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // 모달 콘텐츠
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildAuthorSignatureSectionContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 계약서 미리보기 섹션 (서명 크기 조절 포함)
  Widget _buildContractPreviewSection() {
    return _buildSectionCard(
      title: '계약서 미리보기',
      icon: Icons.preview,
      subtitle: '계약서에 적용될 내용을 최종 확인하세요.',
      children: [
        // 계약서 HTML 미리보기
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 500),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildContractPreviewContent(),
            ),
          ),
        ),
      ],
    );
  }

  // 계약서 미리보기 콘텐츠 (HtmlWidget)
  Widget _buildContractPreviewContent() {
    final filledHtml = _generateFilledTemplateHtml();
    if (filledHtml == null || filledHtml.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '미리보기를 생성할 수 없습니다.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
      );
    }

    final normalized = normalizeContractHtmlLayout(filledHtml);

    return HtmlWidget(
      normalized,
      textStyle: const TextStyle(
        fontSize: 13,
        height: 1.6,
        color: Color(0xFF111827),
      ),
      customStylesBuilder: buildContractHtmlStyles,
    );
  }

  // 기존 _buildAuthorSignatureSection의 내용 (모달용)
  Widget _buildAuthorSignatureSectionContent() {
    final bool hasSignature = _authorSignatureBytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '서명 방법 선택',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              _buildSignatureModeButton('draw', '직접 서명'),
              const SizedBox(width: 6),
              _buildSignatureModeButton('upload', '이미지 첨부'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_signatureMode == 'draw')
          _buildSignatureDrawPad()
        else
          _buildSignatureUploadPanel(),
        if (hasSignature) ...[
          const SizedBox(height: 20),
          const Text(
            '서명 미리보기',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: Image.memory(
              _authorSignatureBytes!,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAuthorSignatureSection() {
    final bool hasSignature = _authorSignatureBytes != null;
    return _buildSectionCard(
      title: '의뢰인 서명',
      icon: Icons.draw_outlined,
      subtitle: '계약 제출 전 의뢰인(갑)의 서명을 등록하세요. 서명 이미지는 서명 요청 시 함께 전달됩니다.',
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              _buildSignatureModeButton('draw', '직접 서명'),
              const SizedBox(width: 6),
              _buildSignatureModeButton('upload', '이미지 첨부'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_signatureMode == 'draw')
          _buildSignatureDrawPad()
        else
          _buildSignatureUploadPanel(),
        if (hasSignature) ...[
          const SizedBox(height: 16),
          const Text(
            '서명 미리보기',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: Image.memory(
              _authorSignatureBytes!,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSignatureModeButton(String mode, String label) {
    final bool isActive = _signatureMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => _switchSignatureMode(mode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isActive ? primaryColor : const Color(0xFFE2E8F0)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureDrawPad() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Signature(
              controller: _signatureController,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed:
                  _signatureController.isEmpty ? null : _handleClearSignature,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('다시 쓰기'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _handleApplyDrawnSignature,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('서명 적용'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignatureUploadPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '이미지 조건',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'PNG, JPG 형식을 권장하며 2MB 이하 이미지를 사용해주세요. 배경이 투명한 파일이면 더 깔끔하게 표시됩니다.',
                style: TextStyle(
                    fontSize: 12, color: Color(0xFF64748B), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _handlePickSignatureImage,
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('서명 이미지 업로드'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
        if (_authorSignatureBytes != null &&
            _authorSignatureSource == 'upload') ...[
          const SizedBox(height: 8),
          const Text(
            '업로드한 서명이 적용되었습니다.',
            style: TextStyle(fontSize: 12, color: Color(0xFF10B981)),
          ),
        ],
      ],
    );
  }

  void _switchSignatureMode(String mode) {
    if (_signatureMode == mode) {
      return;
    }
    setState(() {
      _signatureMode = mode;
      if (mode == 'draw' && _authorSignatureSource == 'upload') {
        _authorSignatureBytes = null;
        _authorSignatureSource = null;
        _authorSignatureAppliedAt = null;
      }
    });
  }

  Future<void> _handleApplyDrawnSignature() async {
    if (_signatureController.isEmpty) {
      _showToast('서명을 먼저 입력해주세요.', isError: true);
      return;
    }
    try {
      final data = await _signatureController.toPngBytes();
      if (data == null || data.isEmpty) {
        _showToast('서명 이미지를 생성하지 못했습니다.', isError: true);
        return;
      }

      // 이미지 리사이즈
      final resizedData = await _resizeSignatureImage(data);
      if (resizedData == null) {
        _showToast('서명 이미지 처리에 실패했습니다.', isError: true);
        return;
      }

      setState(() {
        _authorSignatureBytes = resizedData;
        _authorSignatureSource = 'draw';
        _authorSignatureAppliedAt = DateTime.now();
        _showContractPreview = true; // 미리보기 자동 표시
      });
      _showToast('서명이 적용되었습니다.');
      // 모달 닫기
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (error) {
      _showToast('서명 적용 중 오류가 발생했습니다.', isError: true);
    }
  }

  void _handleClearSignature() {
    _signatureController.clear();
    setState(() {
      if (_authorSignatureSource == 'draw') {
        _authorSignatureBytes = null;
        _authorSignatureSource = null;
        _authorSignatureAppliedAt = null;
      }
    });
  }

  Future<void> _handlePickSignatureImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = result?.files.single;
      if (file == null || file.bytes == null) {
        return;
      }
      if (file.size != null && file.size! > 2 * 1024 * 1024) {
        _showToast('2MB 이하 이미지를 선택해주세요.', isError: true);
        return;
      }

      // 이미지 리사이즈
      final resizedData = await _resizeSignatureImage(file.bytes!);
      if (resizedData == null) {
        _showToast('이미지 처리에 실패했습니다.', isError: true);
        return;
      }

      setState(() {
        _signatureController.clear();
        _authorSignatureBytes = resizedData;
        _authorSignatureSource = 'upload';
        _authorSignatureAppliedAt = DateTime.now();
        _showContractPreview = true; // 미리보기 자동 표시
      });
      _showToast('서명 이미지가 적용되었습니다.');
      // 모달 닫기
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (error) {
      _showToast('이미지 업로드에 실패했습니다.', isError: true);
    }
  }

  /// 서명 이미지를 적절한 크기로 리사이즈 (최대 400x200px)
  Future<Uint8List?> _resizeSignatureImage(Uint8List imageBytes) async {
    try {
      // 이미지 디코드
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return null;
      }

      // 최대 크기 설정 (서명은 가로로 긴 경우가 많으므로 400x200)
      const maxWidth = 400;
      const maxHeight = 200;

      // 현재 크기가 이미 작으면 리사이즈 불필요
      if (image.width <= maxWidth && image.height <= maxHeight) {
        return imageBytes;
      }

      // 비율 유지하면서 리사이즈
      final resized = img.copyResize(
        image,
        width: image.width > maxWidth ? maxWidth : null,
        height: image.height > maxHeight ? maxHeight : null,
        maintainAspect: true,
      );

      // PNG로 인코딩
      return Uint8List.fromList(img.encodePng(resized));
    } catch (error) {
      debugPrint('서명 이미지 리사이즈 실패: $error');
      return imageBytes; // 실패 시 원본 반환
    }
  }

  String? _generateFilledTemplateHtml() {
    final template = _template;
    if (template == null) {
      return null;
    }
    final raw = template.content;
    if (raw.trim().isEmpty) {
      return null;
    }

    final values = <String, String>{};

    void assign(String key, dynamic value) {
      if (key.isEmpty) {
        return;
      }
      final normalized = _normalizePlaceholderValueForHtml(value);
      values[key] = normalized ?? '';
    }

    final schema =
        _templateSchema ?? TemplateFormSchema.tryParse(template.formSchema);
    if (schema != null) {
      for (final section in schema.sections) {
        for (final field in section.fields) {
          // signature 타입 필드는 서명 이미지 또는 점선 박스 표시
          if (field.type == 'signature') {
            final signatureData = _signatureImages[field.id];
            if (signatureData != null) {
              // 서명이 등록되어 있으면 이미지 삽입
              final dataUrl =
                  'data:image/png;base64,${base64Encode(signatureData.imageBytes)}';
              final scaledHeight = (80 * signatureData.scale).toInt();
              final scaledWidth = (200 * signatureData.scale).toInt();
              assign(field.id,
                  '<img src="$dataUrl" style="max-height:${scaledHeight}px;max-width:${scaledWidth}px;width:auto;height:auto;object-fit:contain;display:block;" />');
            } else {
              // 서명이 없으면 점선 박스 표시
              assign(field.id,
                  '<div style="border: 2px dashed #CBD5E1; padding: 20px 40px; text-align: center; color: #94A3B8; font-size: 12px; border-radius: 4px;">서명란</div>');
            }
            continue; // 다음 필드로
          }

          final rawValue = _templateFieldValues[field.id];
          if (rawValue != null) {
            final formatted = _formatTemplateSummaryValue(field);
            if (formatted != '-' && formatted.trim().isNotEmpty) {
              assign(field.id, formatted);
            } else {
              assign(field.id, rawValue);
            }
          } else if (field.defaultValue != null) {
            assign(field.id, field.defaultValue);
          }
        }
      }
    }

    assign('contractName', _contractNameController.text.trim());
    assign('clientName', _clientNameController.text.trim());
    assign('clientContact', _clientContactController.text.trim());
    assign('clientEmail', _clientEmailController.text.trim());
    assign('performerName', _performerNameController.text.trim());
    assign('performerContact', _performerContactController.text.trim());
    assign('performerEmail', _performerEmailController.text.trim());
    assign('startDate',
        _startDate != null ? _dateFormatter.format(_startDate!) : null);
    assign(
        'endDate', _endDate != null ? _dateFormatter.format(_endDate!) : null);
    assign('amount', _includeAmount ? _amountController.text.trim() : null);
    final detailsText = _detailsController.text.trim();
    if (detailsText.isNotEmpty) {
      assign('details', detailsText);
    }
    assign('lenderName', _clientNameController.text.trim());
    assign('lenderContact', _clientContactController.text.trim());
    assign('lenderEmail', _clientEmailController.text.trim());
    assign('lenderSignatureName', _clientNameController.text.trim());
    assign('borrowerName', _performerNameController.text.trim());
    assign('borrowerContact', _performerContactController.text.trim());
    assign('borrowerEmail', _performerEmailController.text.trim());

    if (_authorSignatureBytes != null) {
      final dataUrl =
          'data:image/png;base64,${base64Encode(_authorSignatureBytes!)}';
      // 서명 크기 배율 적용
      final scaledHeight = (80 * _signatureScale).toInt();
      final scaledWidth = (200 * _signatureScale).toInt();
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
        assign(key,
            '<img src="$dataUrl" style="max-height:${scaledHeight}px;max-width:${scaledWidth}px;width:auto;height:auto;object-fit:contain;display:block;" />');
      }
      final signedAt = _authorSignatureAppliedAt ?? DateTime.now();
      final today = _dateFormatter.format(signedAt);
      assign('clientSignatureDate', today);
      assign('authorSignatureDate', today);
      assign('lenderSignDate', today);
      assign('employerSignDate', today);
    }

    final filled = raw.replaceAllMapped(_htmlPlaceholderPattern, (match) {
      final key = match.group(1)?.trim();
      if (key == null || key.isEmpty) {
        return '';
      }
      return values[key] ?? '';
    });

    return filled.replaceAll(_htmlPlaceholderPattern, '');
  }

  String? _normalizePlaceholderValueForHtml(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      // 문자열의 줄바꿈(\n)을 HTML 줄바꿈(<br>)으로 변환해 textarea 등의 개행이 미리보기/PDF에 반영되도록 처리
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return '';
      }
      return trimmed.replaceAll('\n', '<br />');
    }
    if (value is bool) {
      return value ? '예' : '아니오';
    }
    if (value is num) {
      return value.toString();
    }
    if (value is DateTime) {
      return _dateFormatter.format(value);
    }
    if (value is List) {
      final parts = value
          .map(_normalizePlaceholderValueForHtml)
          .whereType<String>()
          .where((element) => element.trim().isNotEmpty)
          .toList();
      if (parts.isEmpty) {
        return '';
      }
      return parts.join(', ');
    }
    if (value is Set) {
      return _normalizePlaceholderValueForHtml(value.toList());
    }
    if (value is Map) {
      final parts = value.values
          .map(_normalizePlaceholderValueForHtml)
          .whereType<String>()
          .where((element) => element.trim().isNotEmpty)
          .toList();
      if (parts.isEmpty) {
        return '';
      }
      return parts.join(', ');
    }
    return value.toString();
  }

  Widget _buildInfoNotice({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF475569), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureField(TemplateFieldDefinition field) {
    final signatureData = _signatureImages[field.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 서명/도장 등록 버튼
        ElevatedButton.icon(
          onPressed: () => _showSignatureUploadOptions(field),
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(signatureData == null ? '서명/도장 등록' : '이미지 다시 등록'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // 등록된 이미지가 있으면 미리보기 표시
        if (signatureData != null) ...[
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.memory(
                signatureData.imageBytes,
                height: 80,
                width: 200,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 드래그/리사이즈 함수는 슬라이더 방식으로 대체되어 제거됨

  void _showSignatureUploadOptions(TemplateFieldDefinition field) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '서명/도장 등록 방법',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.draw, color: primaryColor),
                ),
                title: const Text('직접 그리기'),
                subtitle: const Text('화면에 직접 서명을 그립니다'),
                onTap: () {
                  Navigator.pop(context);
                  _showSignatureDrawDialog(field);
                },
              ),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.image, color: primaryColor),
                ),
                title: const Text('이미지 업로드'),
                subtitle: const Text('기존 서명/도장 이미지를 선택합니다'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadSignatureImage(field);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSignatureDrawDialog(TemplateFieldDefinition field) async {
    final signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: const Color(0xFF111827),
      exportBackgroundColor: Colors.transparent, // 투명 배경
    );

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '서명 그리기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Signature(
                    controller: signatureController,
                    backgroundColor: Colors.white, // 그리는 동안만 흰 배경 (export는 투명)
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          signatureController.clear();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('지우기'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (signatureController.isNotEmpty) {
                            final imageBytes =
                                await signatureController.toPngBytes();
                            if (imageBytes != null) {
                              setState(() {
                                _signatureImages[field.id] = SignatureImageData(
                                  imageBytes: imageBytes,
                                  scale: 1.0, // 기본 크기 (100%)
                                  source: 'draw',
                                );
                              });
                              Navigator.pop(context);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('완료'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _uploadSignatureImage(TemplateFieldDefinition field) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final fileBytes = result.files.first.bytes;
        if (fileBytes != null) {
          setState(() {
            _signatureImages[field.id] = SignatureImageData(
              imageBytes: fileBytes,
              scale: 1.0, // 기본 크기 (100%)
              source: 'upload',
            );
          });
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '이미지 업로드에 실패했습니다',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Widget _buildTemplateSummaryPreview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _templateCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '항목 요약',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          for (final section in _authorSections) ...[
            Text(
              section.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: section.fields
                  .map((field) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(
                                _displayTemplateFieldLabel(field),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _formatTemplateSummaryValue(field),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF111827),
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (_performerSections.isNotEmpty) ...[
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            const Text(
              '서명자가 입력할 항목',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _performerSections
                  .expand((section) => section.fields)
                  .map(
                    (field) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              field.label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              '서명자가 입력',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// 섹션 내용만 렌더링 (A4 wrapper 및 헤더 제외)
  Widget _buildTemplateSectionContent(TemplateFormSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 타이틀
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF3F5F9),
            border: Border(
              top: BorderSide(color: Color(0xFFD4D9E2), width: 0.5),
              bottom: BorderSide(color: Color(0xFFD4D9E2), width: 0.5),
            ),
          ),
          child: Text(
            section.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 필드 테이블
        _buildA4FieldsTable(section.fields),
      ],
    );
  }

  Widget _buildTemplateFieldRow(TemplateFieldDefinition field) {
    final error = _templateFieldErrors[field.id];
    final displayLabel = _displayTemplateFieldLabel(field);
    final helperText = _isResidentRegistrationField(field)
        ? '주민번호는 생년월일과 성별 식별 숫자(1~4)만 입력하면 실제 번호는 저장되지 않습니다.'
        : field.helperText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  displayLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (field.required)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text(
                    '필수',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          if (helperText != null && helperText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                helperText,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          const SizedBox(height: 8),
          _buildTemplateFieldInput(field),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error,
                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTemplateFieldInput(TemplateFieldDefinition field) {
    final type = field.type.toLowerCase();

    if (_isResidentRegistrationField(field)) {
      return _buildResidentRegistrationField(field);
    }

    if (_isBusinessRegistrationField(field)) {
      return _buildBusinessRegistrationField(field);
    }

    if (type == 'checkbox') {
      if (_isSingleCheckboxField(field)) {
        final currentValue = (_templateFieldValues[field.id] as bool?) ??
            _coerceBoolValue(field.defaultValue);
        return Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: field.readonly
                ? null
                : () => _updateTemplateBooleanCheckbox(field, !currentValue),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: currentValue,
                  onChanged: field.readonly
                      ? null
                      : (value) =>
                          _updateTemplateBooleanCheckbox(field, value ?? false),
                ),
                const SizedBox(width: 8),
                Text(
                  currentValue ? '선택됨' : '선택 안 됨',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        );
      }

      final options = field.options;
      final selected = _templateCheckboxValues[field.id] ?? <String>{};
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map(
              (option) => FilterChip(
                selected: selected.contains(option.value),
                label: Text(option.label),
                onSelected: (value) =>
                    _toggleTemplateCheckboxValue(field, option.value, value),
              ),
            )
            .toList(),
      );
    }

    if (type == 'radio') {
      final options = field.options;
      final currentValue = _templateFieldValues[field.id]?.toString();
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map(
              (option) => ChoiceChip(
                selected: currentValue == option.value,
                label: Text(option.label),
                onSelected: (selected) => _updateTemplateSelectValue(
                    field, selected ? option.value : null),
              ),
            )
            .toList(),
      );
    }

    if (type == 'select') {
      final currentValue = _templateFieldValues[field.id]?.toString();
      return DropdownButtonFormField<String>(
        value: currentValue?.isNotEmpty == true ? currentValue : null,
        decoration: _templateInputDecoration(field.placeholder ?? '선택')
            .copyWith(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: field.options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.value,
                child: Text(option.label),
              ),
            )
            .toList(),
        hint: field.options.isEmpty
            ? const Text('옵션이 없습니다')
            : Text(field.placeholder ?? '선택'),
        onChanged: (value) => _updateTemplateSelectValue(field, value),
      );
    }

    if (type == 'date') {
      final controller = _getTemplateTextController(field);

      // readonly 필드인 경우 자동으로 현재 날짜 설정
      if (field.readonly &&
          (_templateFieldValues[field.id] == null ||
              _templateFieldValues[field.id].toString().isEmpty)) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        _templateFieldValues[field.id] = today;
      }

      controller.value = controller.value.copyWith(
        text: _templateFieldValues[field.id]?.toString() ?? controller.text,
        selection: TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        ),
      );

      return TextField(
        controller: controller,
        readOnly: true,
        enabled: !field.readonly, // readonly 필드는 비활성화
        decoration: _templateInputDecoration(field.readonly
            ? (field.helperText ?? '자동 입력됨')
            : (field.placeholder ?? 'YYYY-MM-DD')),
        onTap: field.readonly ? null : () => _pickTemplateDate(field),
      );
    }

    if (type == 'signature') {
      return _buildSignatureField(field);
    }

    final controller = _getTemplateTextController(field);
    TextInputType keyboardType = TextInputType.text;
    TextInputAction? textInputAction;
    List<TextInputFormatter>? formatters;
    int? maxLines = 1;
    int? minLines;

    switch (type) {
      case 'textarea':
        maxLines = null; // 무제한 줄 수
        minLines = 4; // 최소 4줄 표시
        keyboardType = TextInputType.multiline;
        textInputAction = TextInputAction.newline; // 엔터키로 줄바꿈
        break;
      case 'number':
        keyboardType =
            const TextInputType.numberWithOptions(signed: true, decimal: false);
        formatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))];
        break;
      case 'currency':
        keyboardType = const TextInputType.numberWithOptions(decimal: true);
        formatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))];
        break;
      case 'email':
        keyboardType = TextInputType.emailAddress;
        break;
      case 'phone':
        keyboardType = TextInputType.phone;
        break;
    }

    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction, // textarea에서 엔터 가능
      inputFormatters: formatters,
      enabled: !field.readonly,
      expands: false, // 명시적으로 설정
      decoration: _templateInputDecoration(field.placeholder ?? ''),
      onChanged: field.readonly
          ? null
          : (value) => _updateTemplateTextValue(field, value),
    );
  }

  Widget _buildResidentRegistrationField(TemplateFieldDefinition field) {
    final controller = _residentControllers.putIfAbsent(
        field.id, () => TextEditingController());
    final currentRaw = _templateFieldValues[field.id]?.toString();
    if (currentRaw != null && currentRaw.isNotEmpty) {
      final digits = _extractResidentDigits(currentRaw);
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
      decoration: _templateInputDecoration('주민번호 (예: 900101-1******)'),
      onChanged: (value) {
        final digits = _extractResidentDigits(value);
        final masked = _maskResidentDigits(digits);
        if (masked != controller.text) {
          controller
            ..text = masked
            ..selection = TextSelection.collapsed(offset: masked.length);
        }
        _onResidentFieldChanged(field, digits);
      },
    );
  }

  Widget _buildBusinessRegistrationField(TemplateFieldDefinition field) {
    final controller = _businessControllers.putIfAbsent(
        field.id, () => TextEditingController());
    final currentRaw = _templateFieldValues[field.id]?.toString();
    if (currentRaw != null && currentRaw.isNotEmpty) {
      final digits = _extractBusinessDigits(currentRaw);
      final formatted = _formatBusinessRegistrationDigits(digits);
      if (controller.text != formatted) {
        controller
          ..text = formatted
          ..selection = TextSelection.collapsed(offset: formatted.length);
      }
    }

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _templateInputDecoration('사업자등록번호 (예: 123-45-67890)'),
      onChanged: (value) {
        final digits = _extractBusinessDigits(value);
        final formatted = _formatBusinessRegistrationDigits(digits);
        if (formatted != controller.text) {
          controller
            ..text = formatted
            ..selection = TextSelection.collapsed(offset: formatted.length);
        }
        _onBusinessRegistrationChanged(field, digits);
      },
    );
  }

  void _onResidentFieldChanged(TemplateFieldDefinition field, String digits) {
    String limited = digits;
    if (limited.length > 7) {
      limited = limited.substring(0, 7);
    }

    setState(() {
      if (limited.length >= 7) {
        final birth = limited.substring(0, 6);
        final gender = limited.substring(6, 7);
        _templateFieldValues[field.id] = '$birth-$gender';
      } else if (limited.isNotEmpty) {
        _templateFieldValues[field.id] = limited;
      } else {
        _templateFieldValues.remove(field.id);
      }
      _templateFieldErrors.remove(field.id);
    });
  }

  void _onBusinessRegistrationChanged(
      TemplateFieldDefinition field, String digits) {
    String limited = digits;
    if (limited.length > 10) {
      limited = limited.substring(0, 10);
    }

    setState(() {
      if (limited.isEmpty) {
        _templateFieldValues.remove(field.id);
      } else {
        _templateFieldValues[field.id] =
            _formatBusinessRegistrationDigits(limited);
      }
      _templateFieldErrors.remove(field.id);
    });
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
    final buffer = StringBuffer();
    if (digits.length <= 6) {
      buffer.write(digits);
      return buffer.toString();
    }
    buffer.write(digits.substring(0, 6));
    buffer.write('-');
    buffer.write(digits.substring(6, 7));
    buffer.write('******');
    return buffer.toString();
  }

  String _extractBusinessDigits(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 10) {
      return digits;
    }
    return digits.substring(0, 10);
  }

  String _formatBusinessRegistrationDigits(String digits) {
    if (digits.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    final int first = digits.length >= 3 ? 3 : digits.length;
    buffer.write(digits.substring(0, first));
    if (digits.length > 3) {
      buffer.write('-');
      final int remaining = digits.length - 3;
      final int second = remaining >= 2 ? 2 : remaining;
      buffer.write(digits.substring(3, 3 + second));
      if (digits.length > 5) {
        buffer.write('-');
        buffer.write(digits.substring(5));
      }
    }
    return buffer.toString();
  }

  InputDecoration _templateInputDecoration(String? placeholder) {
    return InputDecoration(
      hintText: placeholder,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor),
      ),
    );
  }

  String _formatTemplateSummaryValue(TemplateFieldDefinition field) {
    final value = _templateFieldValues[field.id];
    if (value == null) {
      return '-';
    }
    if (field.type == 'checkbox') {
      if (_isSingleCheckboxField(field) && value is bool) {
        return value ? '예' : '아니오';
      }
      final list = value is List ? value.cast<String>() : <String>[];
      if (list.isEmpty) return '-';
      return list
          .map((item) => field.options
              .firstWhere(
                (option) => option.value == item,
                orElse: () => TemplateFieldOption(label: item, value: item),
              )
              .label)
          .join(', ');
    }
    if (_isResidentRegistrationField(field) && value is String) {
      final digits = _extractResidentDigits(value);
      return _maskResidentDigits(digits);
    }
    if ((field.type == 'select' || field.type == 'radio') && value is String) {
      return field.options
          .firstWhere(
            (option) => option.value == value,
            orElse: () => TemplateFieldOption(label: value, value: value),
          )
          .label;
    }
    if (value is List) {
      return value.join(', ');
    }
    return value.toString().trim().isEmpty ? '-' : value.toString();
  }

  bool _validateTemplateFields() {
    if (_authorSections.isEmpty) {
      return true;
    }

    final errors = <String, String>{};

    for (final section in _authorSections) {
      for (final field in section.fields) {
        if (field.type.toLowerCase() == 'signature') {
          continue;
        }
        final value = _templateFieldValues[field.id];
        final hasValue = _hasTemplateValue(field, value);
        if (field.required && !hasValue) {
          errors[field.id] = '${field.label}을 입력해 주세요.';
          continue;
        }
        final validationError = _validateTemplateFieldValue(field, value);
        if (validationError != null) {
          errors[field.id] = validationError;
        }
      }
    }

    setState(() {
      _templateFieldErrors
        ..clear()
        ..addAll(errors);
    });

    if (errors.isNotEmpty) {
      _showToast(errors.values.first, isError: true);
      return false;
    }

    return true;
  }

  String? _validateTemplateFieldValue(
      TemplateFieldDefinition field, dynamic value) {
    if (value == null) {
      return null;
    }

    final type = field.type.toLowerCase();

    if (type == 'checkbox' && _isSingleCheckboxField(field)) {
      final boolValue = value is bool ? value : _coerceBoolValue(value);
      if (field.required && !boolValue) {
        return '${field.label}에 동의해 주세요.';
      }
      return null;
    }

    final stringValue =
        value is String ? value.trim() : value.toString().trim();

    final validation = field.validation;
    if (validation != null) {
      if (validation.minLength != null &&
          stringValue.length < validation.minLength!) {
        return '${field.label}은(는) 최소 ${validation.minLength}자 이상 입력해 주세요.';
      }
      if (validation.maxLength != null &&
          stringValue.length > validation.maxLength!) {
        return '${field.label}은(는) 최대 ${validation.maxLength}자까지 입력할 수 있습니다.';
      }
      if (validation.pattern != null && validation.pattern!.isNotEmpty) {
        try {
          final regex = RegExp(validation.pattern!);
          if (!regex.hasMatch(stringValue)) {
            return '${field.label} 형식을 확인해 주세요.';
          }
        } catch (_) {
          // ignore invalid pattern
        }
      }
    }

    if (type == 'email' &&
        stringValue.isNotEmpty &&
        !_isValidEmail(stringValue)) {
      return '${field.label} 이메일 형식을 확인해 주세요.';
    }

    if (type == 'phone') {
      final digits = stringValue.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 7) {
        return '${field.label} 연락처를 정확히 입력해 주세요.';
      }
    }

    if (type == 'number' || type == 'currency') {
      final normalized = stringValue.replaceAll(RegExp(r','), '');
      final numericValue = double.tryParse(normalized);
      if (numericValue == null) {
        return '${field.label}에 숫자를 입력해 주세요.';
      }
      if (validation?.min != null && numericValue < validation!.min!) {
        return '${field.label}은(는) ${validation.min} 이상이어야 합니다.';
      }
      if (validation?.max != null && numericValue > validation!.max!) {
        return '${field.label}은(는) ${validation.max} 이하이어야 합니다.';
      }
    }

    if (type == 'date' && stringValue.isNotEmpty) {
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(stringValue)) {
        return '${field.label}을(를) YYYY-MM-DD 형식으로 입력해 주세요.';
      }
      final parsed = DateTime.tryParse(stringValue);
      if (parsed == null) {
        return '${field.label}에 유효한 날짜를 입력해 주세요.';
      }
    }

    if ((type == 'select' || type == 'radio') && field.options.isNotEmpty) {
      final match = field.options.any((option) => option.value == stringValue);
      if (!match) {
        return '${field.label} 옵션을 다시 선택해 주세요.';
      }
    }

    return null;
  }

  bool _hasTemplateValue(TemplateFieldDefinition field, dynamic value) {
    if (value == null) {
      return false;
    }
    final type = field.type.toLowerCase();
    if (type == 'checkbox') {
      if (_isSingleCheckboxField(field)) {
        return value is bool ? value : _coerceBoolValue(value);
      }
      final list = value is List
          ? value
          : (_templateCheckboxValues[field.id]?.toList() ?? []);
      return list.isNotEmpty;
    }
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    if (value is List) {
      return value.isNotEmpty;
    }
    return true;
  }

  Map<String, dynamic> _buildTemplateFormValuesPayload() {
    final result = <String, dynamic>{};
    _templateFieldValues.forEach((key, value) {
      if (value == null) {
        return;
      }
      if (value is Set) {
        result[key] = value.toList();
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  Widget _buildTemplateSignerGuide() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '서명 요청 준비',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4338CA),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '수행자 연락처와 이메일을 입력하면 자동으로 서명 요청이 전송됩니다. 서명자 정보를 정확히 입력해주세요.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF312E81),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final String startDateText =
        _startDate != null ? _dateFormatter.format(_startDate!) : '-';
    final String endDateText =
        _endDate != null ? _dateFormatter.format(_endDate!) : '-';
    final String amountText =
        _includeAmount && _amountController.text.trim().isNotEmpty
            ? NumberFormat.decimalPattern('ko_KR').format(
                int.tryParse(_amountController.text.trim()) ?? 0,
              )
            : '-';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14111827), blurRadius: 12, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0x1F4F46E5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    const Icon(Icons.description_outlined, color: primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _contractNameController.text.trim().isEmpty
                          ? '제목 미정'
                          : _contractNameController.text.trim(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.templateId != null ? '템플릿 기반 계약' : '새 계약서 초안',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('고객 이름', _clientNameController.text.trim()),
          _buildSummaryRow('고객 연락처', _clientContactController.text.trim()),
          _buildSummaryRow('고객 이메일', _clientEmailController.text.trim()),
          const SizedBox(height: 12),
          _buildSummaryRow('수행자 이름', _performerNameController.text.trim()),
          _buildSummaryRow('수행자 연락처', _performerContactController.text.trim()),
          _buildSummaryRow('수행자 이메일', _performerEmailController.text.trim()),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    final displayValue = value.isEmpty ? '-' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
              displayValue,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF111827),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignaturePreviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14111827), blurRadius: 12, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '의뢰인 서명 미리보기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: _authorSignatureBytes == null
                ? const Text('서명이 등록되지 않았습니다.',
                    style: TextStyle(color: Color(0xFF94A3B8)))
                : Image.memory(_authorSignatureBytes!, fit: BoxFit.contain),
          ),
          if (_authorSignatureAppliedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              '서명일: ${_dateFormatter.format(_authorSignatureAppliedAt!)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildContractHtmlPreview() {
    if (_template == null) {
      return null;
    }
    final html = _generateFilledTemplateHtml();
    if (html == null || html.trim().isEmpty) {
      return null;
    }
    // A4 스타일 계약서 미리보기
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '계약서 미리보기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HTML 계약서 내용
                HtmlWidget(
                  html,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    color: Color(0xFF1F2937),
                  ),
                  renderMode: RenderMode.column,
                  customStylesBuilder: buildContractHtmlStyles,
                ),
                if (_authorSignatureBytes != null) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.draw_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        '서명 이미지가 포함되어 있습니다',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepActionBar(BuildContext context) {
    final bool isLastStep = _currentStep == _steps.length - 1;
    final bool isFirstStep = _currentStep == 0;
    final String fieldCount = _getFieldCount();
    final String buttonText = isLastStep
        ? (_isTemplateFlow ? '서명 요청' : '저장')
        : '다음 단계로 ${isLastStep ? '' : fieldCount} →';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFBBD08), // 노란색 배경
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: isFirstStep
              ? ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : (isLastStep ? _handleSave : _goToNextStep),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A5568),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          buttonText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _goToPreviousStep,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text(
                          '이전 단계',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF4A5568),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : (isLastStep ? _handleSave : _goToNextStep),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A5568),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                buttonText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_contractNameController.text.trim().isEmpty) {
          _showToast('계약서 제목을 입력해주세요.', isError: true);
          return false;
        }
        if (_clientNameController.text.trim().isEmpty) {
          _showToast('고객 이름을 입력해주세요.', isError: true);
          return false;
        }
        if (_clientEmailController.text.trim().isNotEmpty &&
            !_isValidEmail(_clientEmailController.text.trim())) {
          _showToast('고객 이메일 형식을 확인해주세요.', isError: true);
          return false;
        }
        if (_collectPerformerInBasicStep) {
          final performerName = _performerNameController.text.trim();
          final performerEmail = _performerEmailController.text.trim();
          if (performerName.isEmpty) {
            _showToast('수행자 이름을 입력해주세요.', isError: true);
            return false;
          }
          if (performerEmail.isEmpty) {
            _showToast('수행자 이메일을 입력해주세요.', isError: true);
            return false;
          }
          if (!_isValidEmail(performerEmail)) {
            _showToast('수행자 이메일 형식을 확인해주세요.', isError: true);
            return false;
          }
        }
        return true;
      case 1:
        if (_isTemplateFlow) {
          // 템플릿 필드 검사
          return _validateTemplateFields();
        }
        // 일반 플로우
        if (_startDate != null &&
            _endDate != null &&
            _endDate!.isBefore(_startDate!)) {
          _showToast('종료일이 시작일보다 빠릅니다.', isError: true);
          return false;
        }
        if (_includeAmount && _amountController.text.trim().isEmpty) {
          _showToast('계약 금액을 입력하거나 스위치를 끄세요.', isError: true);
          return false;
        }
        if (_detailsController.text.trim().isEmpty) {
          _showToast('계약 상세 내용을 입력해주세요.', isError: true);
          return false;
        }
        return true;
      case 2:
        if (_isTemplateFlow) {
          // 템플릿 플로우의 최종 확인 단계 (유효성 검사 불필요)
          return true;
        }
        // 일반 플로우의 수행자 정보 단계
        if (_performerNameController.text.trim().isEmpty) {
          _showToast('수행자 이름을 입력해주세요.', isError: true);
          return false;
        }
        final email = _performerEmailController.text.trim();
        if (email.isEmpty) {
          _showToast('수행자 이메일을 입력해주세요.', isError: true);
          return false;
        }
        if (!_isValidEmail(email)) {
          _showToast('수행자 이메일 형식을 확인해주세요.', isError: true);
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  bool _isValidEmail(String value) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(value);
  }

  BoxDecoration _templateCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14111827),
          blurRadius: 12,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ko', 'KR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6A4C93),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _showLimitExceededDialog(User user) async {
    final contractsUsed = user.contractsUsedThisMonth;
    final contractsLimit = user.monthlyContractLimit;
    final points = user.points;
    final isPremium = user.isPremium;

    if (isPremium) {
      // 프리미엄 사용자는 무제한이므로 이 다이얼로그가 나올 수 없음
      return;
    }

    if (contractsUsed >= contractsLimit && points < 3) {
      // 포인트 부족
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('계약서 작성 제한'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '이번 달 무료 계약서를 모두 사용했습니다.\n($contractsUsed/$contractsLimit개)',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emoji_events_outlined, color: Color(0xFFF59E0B), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '보유 포인트: $points P',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '포인트 3개로 계약서 1개를 더 작성할 수 있어요!',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '포인트를 모으는 방법:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                '• 매일 출석 체크: +1 포인트',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const Text(
                '• 다음 달 1일에 자동 충전: 12 포인트',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/profile');
              },
              child: const Text('출석 체크하러 가기', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    } else if (contractsUsed >= contractsLimit && points >= 3) {
      // 포인트 사용 확인
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('포인트 사용 확인'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '이번 달 무료 계약서를 모두 사용했습니다.\n($contractsUsed/$contractsLimit개)',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDEEBFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '포인트 3개를 사용하여\n계약서 1개를 더 작성하시겠습니까?',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '현재 보유 포인트:',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                  Text(
                    '$points P',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primaryColor),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '사용 후 잔여:',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                  Text(
                    '${points - 3} P',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('포인트 사용하기'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        // 사용자가 취소함
        return;
      }
      // 포인트 사용에 동의함 - 계약서 작성 계속 진행
      // 백엔드에서 자동으로 포인트를 차감하므로 여기서는 아무것도 하지 않음
    }
  }

  Future<void> _handleSave() async {
    if (!_validateStep(_currentStep)) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      _showToast('필수 정보를 모두 입력해주세요.', isError: true);
      return;
    }

    // 계약서 작성 제한 확인
    final user = context.read<AuthCubit>().state.user;
    if (user != null && !user.canCreateContract) {
      await _showLimitExceededDialog(user);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final token = await SessionService.getAccessToken();

      final template = _template;
      final metadata = <String, dynamic>{};
      if (template != null) {
        metadata['templateName'] = template.name;
        final schema = template.formSchema;
        final schemaVersion =
            schema is Map<String, dynamic> ? schema['version'] : null;
        if (schemaVersion != null) {
          metadata['templateSchemaVersion'] = schemaVersion;
        }
        if (template.content.isNotEmpty) {
          metadata['templateRawContent'] = template.content;
        }
      }

      if (_templateFieldValues.isNotEmpty) {
        metadata['templateFormValues'] = _buildTemplateFormValuesPayload();
      }

      // 템플릿 서명 필드에서 등록한 서명/도장 이미지도 메타데이터에 함께 저장
      if (_signatureImages.isNotEmpty) {
        final signatureMetadata = <String, dynamic>{};
        _signatureImages.forEach((fieldId, data) {
          if (data == null) return;
          final dataUrl =
              'data:image/png;base64,${base64Encode(data.imageBytes)}';
          signatureMetadata[fieldId] = {
            'dataUrl': dataUrl,
            'scale': data.scale,
            'source': data.source,
          };
        });
        if (signatureMetadata.isNotEmpty) {
          metadata['templateSignatureImages'] = signatureMetadata;
        }

        // 별도의 의뢰인 서명 섹션을 사용하지 않는 경우,
        // 첫 번째 서명 이미지를 계약 작성자의 서명으로 간주하여 메타데이터에 저장
        if (_authorSignatureBytes == null) {
          final first = _signatureImages.values.firstWhere(
            (value) => value != null,
            orElse: () => null,
          );
          if (first != null) {
            _authorSignatureBytes = first.imageBytes;
            _authorSignatureSource = first.source;
            _authorSignatureAppliedAt ??= DateTime.now();
          }
        }
      }

      if (_authorSignatureBytes != null) {
        // 갑(계약 작성자)의 서명 정보 저장
        metadata['authorSignatureImage'] = base64Encode(_authorSignatureBytes!);
        metadata['authorSignatureSource'] =
            _authorSignatureSource ?? _signatureMode;
        if (_authorSignatureAppliedAt != null) {
          metadata['authorSignatureDate'] =
              _dateFormatter.format(_authorSignatureAppliedAt!);
        }
      }

      final metadataPayload = metadata.isEmpty ? null : metadata;

      final payload = CreateContractPayload(
        templateId: widget.templateId,
        name: _contractNameController.text.trim(),
        clientName: _clientNameController.text.trim(),
        clientContact: _clientContactController.text.trim().isNotEmpty
            ? _clientContactController.text.trim()
            : null,
        clientEmail: _clientEmailController.text.trim().isNotEmpty
            ? _clientEmailController.text.trim()
            : null,
        performerName: _performerNameController.text.trim().isNotEmpty
            ? _performerNameController.text.trim()
            : null,
        performerContact: _performerContactController.text.trim().isNotEmpty
            ? _performerContactController.text.trim()
            : null,
        performerEmail: _performerEmailController.text.trim().isNotEmpty
            ? _performerEmailController.text.trim()
            : null,
        startDate:
            _startDate != null ? _dateFormatter.format(_startDate!) : null,
        endDate: _endDate != null ? _dateFormatter.format(_endDate!) : null,
        amount: _includeAmount && _amountController.text.trim().isNotEmpty
            ? _amountController.text.trim()
            : null,
        details: _detailsController.text.trim().isNotEmpty
            ? _detailsController.text.trim()
            : null,
        metadata: metadataPayload,
      );

      await _contractRepository.createContract(
        payload: payload,
        token: token,
      );

      if (!mounted) return;

      // 임시 저장 삭제
      await _clearDraft();

      _showToast('계약서가 저장되었습니다.');
      context.pop(true); // true를 반환하여 홈 화면에서 새로고침 가능
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      _showToast(
        message.isEmpty ? '계약서 저장에 실패했습니다.' : message,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          _template != null ? '${_template!.name} 작성' : '새 계약서 작성',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF4A5568), // 어두운 회색
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_template != null)
            IconButton(
              onPressed: _openTemplatePreview,
              icon: const Icon(Icons.visibility_outlined,
                  color: Colors.white),
              tooltip: '템플릿 미리보기',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildProgressIndicator(),
            ),
            Expanded(
              child: ListView(
                controller: _stepScrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  ..._buildStepContent(),
                ],
              ),
            ),
            _buildStepActionBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    String? subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 어두운 회색 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF4A5568), // 어두운 회색
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // 내용 영역
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null) ...[
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int? maxLines = 1,
    int? minLines,
    String? suffixText,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType ?? ((maxLines == null || maxLines > 1) ? TextInputType.multiline : TextInputType.text),
          textInputAction: (maxLines == null || maxLines > 1) ? TextInputAction.newline : null, // 여러 줄이면 엔터로 줄바꿈
          inputFormatters: inputFormatters,
          onChanged: (_) => setState(() {}),
          validator: validator,
          maxLines: maxLines,
          minLines: minLines,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            suffixText: suffixText,
            filled: true,
            fillColor:
                readOnly ? const Color(0xFFE5E7EB) : const Color(0xFFFEF3C7),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none, // 테두리 제거
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none, // 테두리 제거
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFBBD08), width: 2), // 노란색 포커스
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date == null ? 'YYYY-MM-DD' : _dateFormatter.format(date),
                    style: TextStyle(
                      fontSize: 15,
                      color: date == null
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF111827),
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Color(0xFF6B7280),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== A4 Document Style Widgets ====================

  /// A4 문서 스타일 래퍼
  Widget _buildA4DocumentWrapper(Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }

  /// CONTRACT 헤더
  Widget _buildContractDocumentHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONTRACT',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '전자계약서 (Electronic Contract)',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF111827), width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'INSIGN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(thickness: 2, color: Color(0xFF111827)),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 테이블 셀 (헤더용)
  Widget _buildA4TableCell(
    String text, {
    required bool isHeader,
    bool isRequired = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: isHeader ? const Color(0xFFF3F5F9) : null,
      child: isHeader
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                if (isRequired)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      '필수',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            )
          : Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF111827),
              ),
            ),
    );
  }

  /// 하이라이트 인라인 입력 필드 (A4 스타일)
  Widget _buildHighlightInlineInput({
    required TemplateFieldDefinition field,
    required TextEditingController controller,
    double? width,
  }) {
    final isActive = _activeFieldId == field.id;
    final isFilled = controller.text.isNotEmpty;

    return Container(
      constraints: width != null ? BoxConstraints(maxWidth: width) : null,
      child: TextField(
        controller: controller,
        onTap: () => setState(() => _activeFieldId = field.id),
        onChanged: (value) {
          _updateTemplateTextValue(field, value);
          setState(() {});
        },
        readOnly: field.readonly,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2937),
        ),
        decoration: InputDecoration(
          hintText: field.placeholder,
          hintStyle: TextStyle(
            color: const Color(0xFF1F2937).withOpacity(0.4),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: _activeFieldId == field.id
              ? const Color(0xFFFBC02D)
              : (isFilled
                  ? const Color(0xFFFFF59D).withOpacity(0.7)
                  : const Color(0xFFFFF59D)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: Color(0xFFFBC02D),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  /// A4 스타일 여러 줄 입력 필드 (textarea용)
  Widget _buildA4TextareaInput({
    required TemplateFieldDefinition field,
    required TextEditingController controller,
  }) {
    final isActive = _activeFieldId == field.id;
    final isFilled = controller.text.isNotEmpty;

    return TextField(
      controller: controller,
      onTap: () => setState(() => _activeFieldId = field.id),
      onChanged: (value) {
        _updateTemplateTextValue(field, value);
        setState(() {});
      },
      readOnly: field.readonly,
      maxLines: null,
      minLines: 4,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2937),
      ),
      decoration: InputDecoration(
        hintText: field.placeholder,
        hintStyle: TextStyle(
          color: const Color(0xFF1F2937).withOpacity(0.4),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: isActive
            ? const Color(0xFFFBC02D)
            : (isFilled
                ? const Color(0xFFFFF59D).withOpacity(0.7)
                : const Color(0xFFFFF59D)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: Color(0xFFFBC02D),
            width: 2,
          ),
        ),
      ),
    );
  }

  /// A4 스타일 템플릿 필드 테이블
  Widget _buildA4FieldsTable(List<TemplateFieldDefinition> fields) {
    final rows = <TableRow>[];

    for (final field in fields) {
      rows.add(
        TableRow(
          children: [
            _buildA4TableCell(
              _displayTemplateFieldLabel(field),
              isHeader: true,
              isRequired: field.required,
            ),
            Container(
              padding: const EdgeInsets.all(8),
              child: _buildTemplateFieldInputForA4(field),
            ),
          ],
        ),
      );
    }

    return Table(
      border: TableBorder.all(
        color: const Color(0xFFD4D9E2),
        width: 0.5,
      ),
      columnWidths: const {
        0: FixedColumnWidth(90),
        1: FlexColumnWidth(),
      },
      children: rows,
    );
  }

  /// A4 스타일용 템플릿 필드 입력 위젯
  Widget _buildTemplateFieldInputForA4(TemplateFieldDefinition field) {
    final type = field.type.toLowerCase();

    // 날짜 필드는 A4 스타일 달력 위젯 사용
    if (type == 'date') {
      return _buildA4DateField(field);
    }

    // 주민번호, 사업자번호는 기존 위젯 사용하되 A4 스타일로
    if (_isResidentRegistrationField(field) ||
        _isBusinessRegistrationField(field)) {
      return _buildTemplateFieldInput(field);
    }

    // checkbox, radio, select, signature는 기존 위젯 사용
    if (type == 'checkbox' ||
        type == 'radio' ||
        type == 'select' ||
        type == 'signature') {
      return _buildTemplateFieldInput(field);
    }

    // 연락처 필드는 자동 하이픈 포맷터 적용
    if (type == 'phone') {
      final controller = _getTemplateTextController(field);
      return TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        inputFormatters: [_phoneNumberFormatter],
        enabled: !field.readonly,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: field.placeholder ?? '010-0000-0000',
          filled: true,
          fillColor: const Color(0xFFFFF59D),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFFBC02D),
              width: 2,
            ),
          ),
        ),
        onChanged: field.readonly
            ? null
            : (value) => _updateTemplateTextValue(field, value),
      );
    }

    // 일반 텍스트 입력 필드 (text, textarea, email, number, currency 등)
    if (_isTextInputField(type)) {
      final controller = _getTemplateTextController(field);

      if (type == 'textarea') {
        // textarea는 여러 줄 입력 가능하도록 별도 위젯 사용
        return _buildA4TextareaInput(
          field: field,
          controller: controller,
        );
      }

      return _buildHighlightInlineInput(
        field: field,
        controller: controller,
      );
    }

    // 기타 필드 타입은 기존 로직 사용
    return _buildTemplateFieldInput(field);
  }

  /// A4 스타일 날짜 입력 필드
  Widget _buildA4DateField(TemplateFieldDefinition field) {
    final controller = _getTemplateTextController(field);

    // readonly 필드인 경우 자동으로 현재 날짜 설정
    if (field.readonly &&
        (_templateFieldValues[field.id] == null ||
            _templateFieldValues[field.id].toString().isEmpty)) {
      final today = DateTime.now().toIso8601String().split('T')[0];
      _templateFieldValues[field.id] = today;
    }

    controller.value = controller.value.copyWith(
      text: _templateFieldValues[field.id]?.toString() ?? controller.text,
      selection: TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      ),
    );

    return InkWell(
      onTap: field.readonly ? null : () => _pickTemplateDate(field),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF59D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.transparent,
            width: 0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                controller.text.isEmpty
                    ? (field.placeholder ?? 'YYYY-MM-DD')
                    : controller.text,
                style: TextStyle(
                  fontSize: 13,
                  color: controller.text.isEmpty
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.calendar_today,
              size: 14,
              color: Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }
}

class KoreanPhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }

    final formatted = _formatDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatDigits(String digits) {
    if (digits.isEmpty) {
      return '';
    }

    if (digits.startsWith('02')) {
      return _formatSeoulNumber(digits);
    }

    return _formatStandardNumber(digits);
  }

  String _formatSeoulNumber(String digits) {
    if (digits.length <= 2) {
      return digits;
    }
    if (digits.length <= 5) {
      return '${digits.substring(0, 2)}-${digits.substring(2)}';
    }

    final middle = digits.length - 4;
    final midSection = digits.substring(2, middle);
    final lastSection = digits.substring(middle);
    return '${digits.substring(0, 2)}-$midSection-$lastSection';
  }

  String _formatStandardNumber(String digits) {
    if (digits.length <= 3) {
      return digits;
    }
    if (digits.length <= 7) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    }
    if (digits.length <= 10) {
      final middle = digits.length - 4;
      final midSection = digits.substring(3, middle);
      final lastSection = digits.substring(middle);
      return '${digits.substring(0, 3)}-$midSection-$lastSection';
    }

    return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, 11)}';
  }
}
