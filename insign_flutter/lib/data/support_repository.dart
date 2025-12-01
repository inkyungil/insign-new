import 'package:insign/core/config/api_config.dart';
import 'package:insign/data/services/api_client.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/models/inquiry.dart';

class SupportRepository {
  Future<void> submitInquiry({
    required String category,
    required String subject,
    required String content,
    List<String>? attachmentUrls,
  }) async {
    final session = await SessionService.loadSession();

    await ApiClient.requestVoid(
      path: ApiConfig.inquiriesEndpoint,
      method: 'POST',
      token: session?.accessToken,
      body: {
        'category': category,
        'subject': subject,
        'content': content,
        if (attachmentUrls != null) 'attachmentUrls': attachmentUrls,
      },
    );
  }

  Future<List<Inquiry>> getMyInquiries() async {
    final session = await SessionService.loadSession();

    return await ApiClient.requestList<Inquiry>(
      path: ApiConfig.myInquiriesEndpoint,
      method: 'GET',
      token: session?.accessToken,
      fromJson: (json) => Inquiry.fromJson(json),
    );
  }
}
