class Template {
  final int id;
  final String name;
  final String category;
  final String description;
  final String content;
  final DateTime? lastUpdatedAt;
  final Map<String, dynamic>? formSchema;
  final Map<String, dynamic>? samplePayload;

  const Template({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.content,
    this.lastUpdatedAt,
    this.formSchema,
    this.samplePayload,
  });

  factory Template.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    Map<String, dynamic>? _parseMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      return null;
    }

    return Template(
      id: json['id'] as int,
      name: json['name'] as String? ?? '-',
      category: json['category'] as String? ?? '기타',
      description: json['description'] as String? ?? '',
      content: json['content'] as String? ?? '',
      lastUpdatedAt: _parseDate(json['lastUpdatedAt']),
      formSchema: _parseMap(json['formSchema']),
      samplePayload: _parseMap(json['samplePayload']),
    );
  }
}
