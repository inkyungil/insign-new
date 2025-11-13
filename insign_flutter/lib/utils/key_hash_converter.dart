import 'dart:convert';
import 'dart:typed_data';

class KeyHashConverter {
  /// SHA1 해시를 Base64로 변환
  static String sha1ToBase64(String sha1Hash) {
    // 콜론 제거하고 16진수 문자열을 바이트로 변환
    String cleanHex = sha1Hash.replaceAll(':', '');
    
    // 16진수 문자열을 바이트 배열로 변환
    List<int> bytes = [];
    for (int i = 0; i < cleanHex.length; i += 2) {
      String hex = cleanHex.substring(i, i + 2);
      bytes.add(int.parse(hex, radix: 16));
    }
    
    // Base64로 인코딩
    return base64Encode(Uint8List.fromList(bytes));
  }
  
  /// 현재 SHA1 해시의 Base64 변환값을 출력
  static void printBase64Hash() {
    const sha1 = 'CD:59:3A:1E:07:28:1E:FD:E3:55:22:E4:D3:27:9D:B1:02:10:8C:44';
    final base64Hash = sha1ToBase64(sha1);
    
    print('🔑 카카오 키 해시 정보:');
    print('SHA1: $sha1');
    print('Base64: $base64Hash');
    print('');
    print('📋 카카오 개발자 콘솔에서 다음 중 하나를 시도해보세요:');
    print('1. SHA1 형식: $sha1');
    print('2. Base64 형식: $base64Hash');
  }
}