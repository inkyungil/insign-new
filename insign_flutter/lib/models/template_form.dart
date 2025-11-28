class TemplateFormSchema {
  final int version;
  final String? title;
  final String? description;
  final List<TemplateFormSection> sections;

  const TemplateFormSchema({
    required this.version,
    required this.sections,
    this.title,
    this.description,
  });

  factory TemplateFormSchema.fromMap(Map<String, dynamic> map) {
    final rawSections = map['sections'];
    return TemplateFormSchema(
      version: (map['version'] as num?)?.toInt() ?? 1,
      title: map['title'] as String?,
      description: map['description'] as String?,
      sections: rawSections is List
          ? rawSections
              .whereType<Map<String, dynamic>>()
              .map(TemplateFormSection.fromMap)
              .toList()
          : const [],
    );
  }

  static TemplateFormSchema? tryParse(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return null;
    }
    try {
      return TemplateFormSchema.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  List<TemplateFormSection> selectSections({
    required List<String> allowedRoles,
    bool includeAll = false,
  }) {
    final normalizedAllowed =
        allowedRoles.map((role) => role.trim().toLowerCase()).toSet();

    bool matchesRole(String? rawRole) {
      if (rawRole == null || rawRole.trim().isEmpty) {
        return includeAll;
      }

      final normalized = rawRole.trim().toLowerCase();

      if (normalized == 'all') {
        return true;
      }

      if (normalizedAllowed.contains(normalized)) {
        return true;
      }

      final splitParts = normalized
          .split(RegExp(r'[\s,_\-\|/]+'))
          .where((part) => part.isNotEmpty)
          .toList();

      if (splitParts.length > 1) {
        return splitParts.any(matchesRole);
      }

      return normalizedAllowed.any((allowed) => normalized.contains(allowed));
    }

    return sections
        .map((section) {
          final filtered = section.fields
              .where((field) => matchesRole(field.role ?? section.role))
              .toList();
          if (filtered.isEmpty) {
            return null;
          }
          return section.copyWith(fields: filtered);
        })
        .whereType<TemplateFormSection>()
        .toList();
  }
}

class TemplateFormSection {
  final String id;
  final String title;
  final String? role;
  final String? description;
  final List<TemplateFieldDefinition> fields;

  const TemplateFormSection({
    required this.id,
    required this.title,
    required this.fields,
    this.role,
    this.description,
  });

  factory TemplateFormSection.fromMap(Map<String, dynamic> map) {
    final rawFields = map['fields'];
    return TemplateFormSection(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      role: map['role']?.toString(),
      description: map['description']?.toString(),
      fields: rawFields is List
          ? rawFields
              .whereType<Map<String, dynamic>>()
              .map(TemplateFieldDefinition.fromMap)
              .toList()
          : const [],
    );
  }

  TemplateFormSection copyWith({List<TemplateFieldDefinition>? fields}) {
    return TemplateFormSection(
      id: id,
      title: title,
      role: role,
      description: description,
      fields: fields ?? this.fields,
    );
  }
}

class TemplateFieldDefinition {
  final String id;
  final String label;
  final String type;
  final bool required;
  final String? role;
  final String? placeholder;
  final String? helperText;
  final List<TemplateFieldOption> options;
  final dynamic defaultValue;
  final TemplateFieldValidation? validation;
  final bool readonly; // 사용자가 직접 수정할 수 없는 필드 (자동 생성)

  const TemplateFieldDefinition({
    required this.id,
    required this.label,
    required this.type,
    required this.required,
    this.role,
    this.placeholder,
    this.helperText,
    this.options = const [],
    this.defaultValue,
    this.validation,
    this.readonly = false,
  });

  factory TemplateFieldDefinition.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    return TemplateFieldDefinition(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      type: map['type']?.toString() ?? 'text',
      required: map['required'] == true,
      role: map['role']?.toString(),
      placeholder: map['placeholder']?.toString(),
      helperText: map['helperText']?.toString(),
      options: rawOptions is List
          ? rawOptions
              .whereType<Map<String, dynamic>>()
              .map(TemplateFieldOption.fromMap)
              .toList()
          : const [],
      defaultValue: map['defaultValue'],
      validation: map['validation'] is Map<String, dynamic>
          ? TemplateFieldValidation.fromMap(
              map['validation'] as Map<String, dynamic>)
          : null,
      readonly: map['readonly'] == true,
    );
  }
}

class TemplateFieldOption {
  final String label;
  final String value;

  const TemplateFieldOption({required this.label, required this.value});

  factory TemplateFieldOption.fromMap(Map<String, dynamic> map) {
    return TemplateFieldOption(
      label: map['label']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
    );
  }
}

class TemplateFieldValidation {
  final double? min;
  final double? max;
  final int? minLength;
  final int? maxLength;
  final String? pattern;

  const TemplateFieldValidation({
    this.min,
    this.max,
    this.minLength,
    this.maxLength,
    this.pattern,
  });

  factory TemplateFieldValidation.fromMap(Map<String, dynamic> map) {
    double? _parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    int? _parseInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    return TemplateFieldValidation(
      min: _parseDouble(map['min']),
      max: _parseDouble(map['max']),
      minLength: _parseInt(map['minLength']),
      maxLength: _parseInt(map['maxLength']),
      pattern: map['pattern']?.toString(),
    );
  }
}
