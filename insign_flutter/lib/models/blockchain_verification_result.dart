class BlockchainVerificationResult {
  final bool matchesBlockchain;
  final bool? matchesStoredPdf;
  final String computedHash;
  final String? blockchainHash;
  final String? pdfHash;
  final String? blockchainTxHash;
  final String? blockchainNetwork;
  final DateTime? blockchainTimestamp;

  const BlockchainVerificationResult({
    required this.matchesBlockchain,
    required this.computedHash,
    this.matchesStoredPdf,
    this.blockchainHash,
    this.pdfHash,
    this.blockchainTxHash,
    this.blockchainNetwork,
    this.blockchainTimestamp,
  });

  factory BlockchainVerificationResult.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    return BlockchainVerificationResult(
      matchesBlockchain: json['matchesBlockchain'] as bool? ?? false,
      matchesStoredPdf: json['matchesStoredPdf'] as bool?,
      computedHash: json['computedHash'] as String? ?? '',
      blockchainHash: json['blockchainHash'] as String?,
      pdfHash: json['pdfHash'] as String?,
      blockchainTxHash: json['blockchainTxHash'] as String?,
      blockchainNetwork: json['blockchainNetwork'] as String?,
      blockchainTimestamp: parseDate(json['blockchainTimestamp']),
    );
  }
}
