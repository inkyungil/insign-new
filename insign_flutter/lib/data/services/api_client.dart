// lib/data/services/api_client.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:insign/core/config/api_config.dart';

class ApiClient {
  static Future<T> request<T>({
    required String path,
    required String method,
    Map<String, dynamic>? body,
    String? token,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final url = Uri.parse('${ApiConfig.apiEndpoint}$path');

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(url, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          url,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          url,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'PATCH':
        response = await http.patch(
          url,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(url, headers: headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    final responseText = response.body;
    final Map<String, dynamic>? payload =
        responseText.isNotEmpty ? json.decode(responseText) : null;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload?['message'] ?? '요청에 실패했습니다.';
      throw Exception(message);
    }

    if (payload == null) {
      throw Exception('응답 데이터가 없습니다.');
    }

    return fromJson(payload);
  }

  static Future<T?> requestNullable<T>({
    required String path,
    required String method,
    Map<String, dynamic>? body,
    String? token,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final url = Uri.parse('${ApiConfig.apiEndpoint}$path');

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(url, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          url,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          url,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'PATCH':
        response = await http.patch(
          url,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(url, headers: headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    final responseText = response.body;
    final Map<String, dynamic>? payload =
        responseText.isNotEmpty ? json.decode(responseText) : null;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload?['message'] ?? '요청에 실패했습니다.';
      throw Exception(message);
    }

    if (payload == null) {
      return null;
    }

    return fromJson(payload);
  }

  static Future<List<T>> requestList<T>({
    required String path,
    required String method,
    Map<String, dynamic>? body,
    String? token,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final url = Uri.parse('${ApiConfig.apiEndpoint}$path');

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(url, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          url,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          url,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'PATCH':
        response = await http.patch(
          url,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(url, headers: headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    final responseText = response.body;
    final dynamic payload = responseText.isNotEmpty ? json.decode(responseText) : null;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload is Map<String, dynamic> ? payload['message'] : null;
      throw Exception(message ?? '요청에 실패했습니다.');
    }

    if (payload is! List) {
      throw Exception('응답 데이터가 없습니다.');
    }

    return payload
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
  }

  // 응답 데이터가 없는 경우 (예: logout)
  static Future<void> requestVoid({
    required String path,
    required String method,
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final url = Uri.parse('${ApiConfig.apiEndpoint}$path');

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;

    switch (method.toUpperCase()) {
      case 'POST':
        response = await http.post(
          url,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'PATCH':
        response = await http.patch(
          url,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(url, headers: headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final responseText = response.body;
      final Map<String, dynamic>? payload =
          responseText.isNotEmpty ? json.decode(responseText) : null;
      final message = payload?['message'] ?? '요청에 실패했습니다.';
      throw Exception(message);
    }
  }

  static Future<Uint8List> requestBytes({
    required String path,
    required String method,
    Map<String, dynamic>? body,
    String? token,
    String accept = 'application/octet-stream',
  }) async {
    final url = Uri.parse('${ApiConfig.apiEndpoint}$path');

    final headers = <String, String>{
      'Accept': accept,
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(url, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          url,
          headers: {
            ...headers,
            'Content-Type': 'application/json',
          },
          body: body != null ? json.encode(body) : null,
        );
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final responseText = response.body;
      Map<String, dynamic>? payload;
      try {
        payload = responseText.isNotEmpty ? json.decode(responseText) as Map<String, dynamic>? : null;
      } catch (_) {
        payload = null;
      }
      final message = payload?['message'] ?? '요청에 실패했습니다.';
      throw Exception(message);
    }

    return response.bodyBytes;
  }
}
