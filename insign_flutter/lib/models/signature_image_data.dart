// lib/models/signature_image_data.dart

import 'dart:typed_data';

/// 서명/도장 이미지와 크기 정보
class SignatureImageData {
  final Uint8List imageBytes;
  final double scale; // 크기 배율 (0.3 ~ 2.0)
  final String source; // 'draw' | 'upload'

  const SignatureImageData({
    required this.imageBytes,
    required this.scale,
    required this.source,
  });

  SignatureImageData copyWith({
    Uint8List? imageBytes,
    double? scale,
    String? source,
  }) {
    return SignatureImageData(
      imageBytes: imageBytes ?? this.imageBytes,
      scale: scale ?? this.scale,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scale': scale,
      'source': source,
    };
  }
}
