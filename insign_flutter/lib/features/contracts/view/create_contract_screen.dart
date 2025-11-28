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
import 'package:insign/features/templates/widgets/template_preview_modal.dart';
import 'package:insign/models/template_form.dart';
import 'package:insign/models/template.dart';
import 'package:insign/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';

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
    exportBackgroundColor: Colors.white,
  );
  String _signatureMode = 'draw';
  Uint8List? _authorSignatureBytes;
  String? _authorSignatureSource;
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
      return ['기본 정보', '계약 항목', '서명 요청 준비', '서명 요청'];
    }
    return ['기본 정보', '계약 조건', '수행자 정보', '요약'];
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
    return showTemplatePreviewModal(context, template);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int index = 0; index < _steps.length; index++) ...[
                if (index != 0) const SizedBox(width: 8),
                _buildStepChip(index),
              ],
            ],
          ),
        ),
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

  List<Widget> _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _isTemplateFlow
            ? _buildTemplateAuthorStep()
            : _buildContractConditionsStep();
      case 2:
        return _isTemplateFlow
            ? _buildTemplateSignatureStep()
            : _buildPerformerStep();
      case 3:
        return _buildSummaryStep();
      default:
        return const [];
    }
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
            maxLines: 8,
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
    final widgets = <Widget>[];
    for (final section in _authorSections) {
      widgets.add(_buildTemplateSectionCard(section));
      widgets.add(const SizedBox(height: 16));
    }
    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }
    return widgets;
  }

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
    final contractPreview = _buildContractHtmlPreview();
    if (contractPreview != null) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(contractPreview);
    }
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
      setState(() {
        _authorSignatureBytes = data;
        _authorSignatureSource = 'draw';
        _authorSignatureAppliedAt = DateTime.now();
      });
      _showToast('서명이 적용되었습니다.');
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
      setState(() {
        _signatureController.clear();
        _authorSignatureBytes = file.bytes;
        _authorSignatureSource = 'upload';
        _authorSignatureAppliedAt = DateTime.now();
      });
      _showToast('서명 이미지가 적용되었습니다.');
    } catch (error) {
      _showToast('이미지 업로드에 실패했습니다.', isError: true);
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
            '<img src="$dataUrl" style="max-height:80px;max-width:100%;object-fit:contain;" />');
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
      final trimmed = value.trim();
      return trimmed.isEmpty ? '' : trimmed;
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

  Widget _buildTemplateSectionCard(TemplateFormSection section) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _templateCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (section.description != null &&
                        section.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          section.description!,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              height: 1.4),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final field in section.fields) _buildTemplateFieldRow(field),
        ],
      ),
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
        decoration: _templateInputDecoration(field.placeholder ?? '선택'),
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
      return _buildInfoNotice(
        icon: Icons.edit_outlined,
        title: '서명 입력 안내',
        message: '서명 항목은 다음 단계에서 입력하거나 이미지를 첨부할 수 있도록 준비 중입니다.',
      );
    }

    final controller = _getTemplateTextController(field);
    TextInputType keyboardType = TextInputType.text;
    List<TextInputFormatter>? formatters;
    int maxLines = 1;
    int? minLines;

    switch (type) {
      case 'textarea':
        maxLines = 6;
        minLines = 4;
        keyboardType = TextInputType.multiline;
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
      inputFormatters: formatters,
      enabled: !field.readonly,
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
            '계약서 미리보기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.all(16),
            child: HtmlWidget(
              html,
              textStyle: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Color(0xFF1F2937),
              ),
              renderMode: RenderMode.column,
            ),
          ),
          if (_authorSignatureBytes != null) ...[
            const SizedBox(height: 16),
            _buildInfoNotice(
              icon: Icons.draw_outlined,
              title: '의뢰인 서명',
              message: '서명 이미지는 계약서 본문에서 직접 확인할 수 있습니다.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepActionBar(BuildContext context) {
    final bool isFirstStep = _currentStep == 0;
    final bool isLastStep = _currentStep == _steps.length - 1;
    final EdgeInsets padding = EdgeInsets.fromLTRB(
      16,
      12,
      16,
      16 + MediaQuery.of(context).padding.bottom,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: padding,
      child: Row(
        children: [
          if (!isFirstStep) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : _goToPreviousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('이전 단계'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed:
                  _isSaving ? null : (isLastStep ? _handleSave : _goToNextStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      isLastStep ? (_isTemplateFlow ? '서명 요청' : '저장') : '다음 단계',
                    ),
            ),
          ),
        ],
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
        return true;
      case 1:
        if (_isTemplateFlow) {
          return _validateTemplateFields();
        }
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
        if (_isTemplateFlow && _authorSignatureBytes == null) {
          _showToast('의뢰인 서명을 등록해주세요.', isError: true);
          return false;
        }
        return true;
      case 3:
        if (_isTemplateFlow) {
          return _validateTemplateFields();
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
        title: const Text(
          '새 계약서 작성',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF111827)),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveDraft,
            icon: const Icon(Icons.save_outlined,
                size: 18, color: Color(0xFF6B7280)),
            label: const Text(
              '임시 저장',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
          ),
          if (_template != null)
            IconButton(
              onPressed: _openTemplatePreview,
              icon: const Icon(Icons.visibility_outlined,
                  color: Color(0xFF6B7280)),
              tooltip: '템플릿 미리보기',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _stepScrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProgressIndicator(),
                  const SizedBox(height: 24),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF6A4C93)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
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
    int maxLines = 1,
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
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLines: maxLines,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            suffixText: suffixText,
            filled: true,
            fillColor: readOnly ? const Color(0xFFE5E7EB) : const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
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
              borderSide: const BorderSide(color: Color(0xFF6A4C93), width: 2),
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
