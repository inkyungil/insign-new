class Policy {
  final int id;
  final String type;
  final String title;
  final String content;
  final String? version;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Policy({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.version,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory Policy.fromJson(Map<String, dynamic> json) {
    return Policy(
      id: json['id'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      version: json['version'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}
