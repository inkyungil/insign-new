class Inquiry {
  final int id;
  final String category;
  final String subject;
  final String content;
  final List<String>? attachmentUrls;
  final String status;
  final DateTime createdAt;

  Inquiry({
    required this.id,
    required this.category,
    required this.subject,
    required this.content,
    this.attachmentUrls,
    required this.status,
    required this.createdAt,
  });

  factory Inquiry.fromJson(Map<String, dynamic> json) {
    return Inquiry(
      id: json['id'] as int,
      category: json['category'] as String,
      subject: json['subject'] as String,
      content: json['content'] as String,
      attachmentUrls: json['attachmentUrls'] != null
          ? List<String>.from(json['attachmentUrls'] as List)
          : null,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  String get categoryLabel {
    switch (category) {
      case 'contract':
        return '계약 관련';
      case 'payment':
        return '결제/포인트';
      case 'account':
        return '계정/로그인';
      case 'technical':
        return '기술 지원';
      case 'other':
        return '기타';
      default:
        return category;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return '대기 중';
      case 'in_progress':
        return '처리 중';
      case 'answered':
        return '답변 완료';
      case 'closed':
        return '종료';
      default:
        return status;
    }
  }
}
