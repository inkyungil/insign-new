class Contract {
  final int id;
  final int? templateId;
  final String name;
  final String clientName;
  final String? clientContact;
  final String? clientEmail;
  final String? performerName;
  final String? performerEmail;
  final String? performerContact;
  final String? status;
  final String? amount;
  final String? details;
  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, dynamic>? metadata;
  final String? signatureDeclinedAt;
  final String? signatureCompletedAt;
  final String? signatureToken;
  final String? signatureSentAt;
  final String? signatureImage;
  final String? signatureSource;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? blockchainHash;
  final String? blockchainTxHash;
  final DateTime? blockchainTimestamp;
  final String? blockchainNetwork;
  final String? pdfHash;

  const Contract({
    required this.id,
    required this.templateId,
    required this.name,
    required this.clientName,
    this.clientContact,
    this.clientEmail,
    this.performerName,
    this.performerEmail,
    this.performerContact,
    this.status,
    this.amount,
    this.details,
    this.startDate,
    this.endDate,
    this.metadata,
    this.signatureDeclinedAt,
    this.signatureCompletedAt,
    this.signatureToken,
    this.signatureSentAt,
    this.signatureImage,
    this.signatureSource,
    this.createdAt,
    this.updatedAt,
    this.blockchainHash,
    this.blockchainTxHash,
    this.blockchainTimestamp,
    this.blockchainNetwork,
    this.pdfHash,
  });

  factory Contract.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    Map<String, dynamic>? _parseMetadata(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      return null;
    }

    return Contract(
      id: json['id'] as int,
      templateId: json['templateId'] as int?,
      name: json['name'] as String? ?? '-',
      clientName: json['clientName'] as String? ?? '-',
      clientContact: json['clientContact'] as String?,
      clientEmail: json['clientEmail'] as String?,
      performerName: json['performerName'] as String?,
      performerEmail: json['performerEmail'] as String?,
      performerContact: json['performerContact'] as String?,
      status: json['status'] as String?,
      amount: json['amount'] as String?,
      details: json['details'] as String?,
      startDate: _parseDate(json['startDate']),
      endDate: _parseDate(json['endDate']),
      metadata: _parseMetadata(json['metadata']),
      signatureDeclinedAt: json['signatureDeclinedAt'] as String?,
      signatureCompletedAt: json['signatureCompletedAt'] as String?,
      signatureToken: json['signatureToken'] as String?,
      signatureSentAt: json['signatureSentAt'] as String?,
      signatureImage: json['signatureImage'] as String?,
      signatureSource: json['signatureSource'] as String?,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      blockchainHash: json['blockchainHash'] as String?,
      blockchainTxHash: json['blockchainTxHash'] as String?,
      blockchainTimestamp: _parseDate(json['blockchainTimestamp']),
      blockchainNetwork: json['blockchainNetwork'] as String?,
      pdfHash: json['pdfHash'] as String?,
    );
  }
}
