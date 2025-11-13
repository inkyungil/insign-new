// lib/data/services/kakao_auth_service.dart

import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class KakaoAuthService {
  /// 카카오 SDK 초기화
  static void initialize() {
    KakaoSdk.init(
      nativeAppKey: '6e0890d62b2c37446106b6f1ed9b4741',
    );
  }

  /// 카카오 로그인
  static Future<User?> signIn() async {
    try {
      // 카카오톡 로그인 가능 여부 확인
      if (await isKakaoTalkInstalled()) {
        try {
          // 카카오톡으로 로그인
          OAuthToken token = await UserApi.instance.loginWithKakaoTalk();
          print('카카오톡으로 로그인 성공: ${token.accessToken}');
        } catch (error) {
          print('카카오톡으로 로그인 실패 $error');
          
          // 사용자가 카카오톡 설치 후 디바이스 권한 요청 화면에서 로그인을 취소한 경우
          if (error is PlatformException && error.code == 'CANCELED') {
            return null;
          }
          // 카카오계정으로 로그인
          try {
            OAuthToken token = await UserApi.instance.loginWithKakaoAccount();
            print('카카오계정으로 로그인 성공: ${token.accessToken}');
          } catch (error) {
            print('카카오계정으로 로그인 실패 $error');
            return null;
          }
        }
      } else {
        // 카카오계정으로 로그인
        try {
          OAuthToken token = await UserApi.instance.loginWithKakaoAccount();
          print('카카오계정으로 로그인 성공: ${token.accessToken}');
        } catch (error) {
          print('카카오계정으로 로그인 실패 $error');
          return null;
        }
      }

      // 사용자 정보 요청
      User user = await UserApi.instance.me();
      print('사용자 정보 요청 성공'
          '\n회원번호: ${user.id}'
          '\n닉네임: ${user.kakaoAccount?.profile?.nickname}'
          '\n이메일: ${user.kakaoAccount?.email}');
      
      return user;
    } catch (error) {
      print('카카오 로그인 에러: $error');
      return null;
    }
  }

  /// 카카오 로그아웃
  static Future<void> signOut() async {
    try {
      await UserApi.instance.unlink();
      print('연결 끊기 성공, SDK에서 토큰 삭제');
    } catch (error) {
      print('연결 끊기 실패 $error');
    }
  }

  /// 현재 로그인한 사용자 정보 가져오기
  static Future<User?> getCurrentUser() async {
    try {
      User user = await UserApi.instance.me();
      return user;
    } catch (error) {
      print('사용자 정보 요청 실패 $error');
      return null;
    }
  }

  /// 토큰 유효성 검사
  static Future<bool> isTokenValid() async {
    try {
      await TokenManagerProvider.instance.manager.getToken();
      return true;
    } catch (error) {
      print('토큰 유효성 검사 실패: $error');
      return false;
    }
  }

  /// 앱의 키 해시를 가져와서 출력 (개발용)
  static Future<void> printKeyHash() async {
    try {
      // 개발용 키 해시 출력
      print('🔑 카카오 키 해시를 확인하려면 다음 방법을 사용하세요:');
      print('');
      print('📱 Android:');
      print('1. Android Studio Terminal에서 실행:');
      print('cd android');
      print('./gradlew signingReport');
      print('');
      print('2. 또는 keytool 사용:');
      print('keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore | openssl sha1 -binary | openssl base64');
      print('');
      print('🍎 iOS:');
      print('iOS는 키 해시가 필요하지 않습니다.');
      print('');
      print('📋 출력된 키 해시를 카카오 개발자 콘솔 > 내 애플리케이션 > 앱 설정 > 플랫폼 > Android 플랫폼 등록에서 해시키 필드에 입력하세요.');
    } catch (error) {
      print('키 해시 정보 출력 실패: $error');
    }
  }
}