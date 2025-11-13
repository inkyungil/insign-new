import 'package:flutter/services.dart';

class KeyHashService {
  static const MethodChannel _channel = MethodChannel('key_hash_channel');
  
  /// 키 해시를 가져오는 메서드
  static Future<String?> getKeyHash() async {
    try {
      final String? keyHash = await _channel.invokeMethod('getKeyHash');
      return keyHash;
    } on PlatformException catch (e) {
      print('키 해시 가져오기 실패: ${e.message}');
      return null;
    }
  }
  
  /// 키 해시를 콘솔에 출력
  static Future<void> printKeyHash() async {
    final keyHash = await getKeyHash();
    if (keyHash != null) {
      print('🔑 카카오 로그인 키 해시: $keyHash');
      print('📱 이 키 해시를 카카오 개발자 콘솔의 플랫폼 설정에 입력하세요.');
    } else {
      print('❌ 키 해시를 가져올 수 없습니다.');
    }
  }
}
