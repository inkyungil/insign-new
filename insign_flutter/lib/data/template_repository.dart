import 'dart:typed_data';

import 'package:insign/core/config/api_config.dart';
import 'package:insign/data/services/api_client.dart';
import 'package:insign/models/template.dart';

class TemplateRepository {
  Future<List<Template>> fetchTemplates({String? token}) async {
    return ApiClient.requestList<Template>(
      path: ApiConfig.templates,
      method: 'GET',
      token: token,
      fromJson: (json) => Template.fromJson(json),
    );
  }

  Future<Template> fetchTemplate(int id, {String? token}) async {
    return ApiClient.request<Template>(
      path: '${ApiConfig.templates}/$id',
      method: 'GET',
      token: token,
      fromJson: (json) => Template.fromJson(json),
    );
  }

  Future<Uint8List> previewTemplatePdf({
    required int id,
    String? token,
  }) async {
    return ApiClient.requestBytes(
      path: '${ApiConfig.templates}/$id/preview-pdf',
      method: 'GET',
      token: token,
      accept: 'application/pdf',
    );
  }
}
