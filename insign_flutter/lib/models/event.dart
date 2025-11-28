class Event {
  final int id;
  final String title;
  final String content;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Event({
    required this.id,
    required this.title,
    required this.content,
    this.startDate,
    this.endDate,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as int,
      title: json['title'] as String,
      content: json['content'] as String,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate'] as String) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      isActive: _parseIsActive(json['isActive']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static bool _parseIsActive(dynamic isActiveValue) {
    if (isActiveValue is bool) {
      return isActiveValue;
    }
    if (isActiveValue is int) {
      return isActiveValue == 1;
    }
    // 기본값은 true로 유지
    return true;
  }

  String get dateRange {
    if (startDate == null && endDate == null) {
      return '기간 제한 없음';
    }
    final start = startDate != null ? _formatDate(startDate!) : '';
    final end = endDate != null ? _formatDate(endDate!) : '';
    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start ~ $end';
    }
    return start.isNotEmpty ? '$start ~' : '~ $end';
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}
