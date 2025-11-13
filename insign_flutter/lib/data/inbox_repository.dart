import 'package:insign/core/config/api_config.dart';
import 'package:insign/data/services/api_client.dart';
import 'package:insign/models/inbox_message.dart';

class InboxRepository {
  Future<List<InboxMessage>> fetchMessages({required String token}) {
    return ApiClient.requestList<InboxMessage>(
      path: ApiConfig.inbox,
      method: 'GET',
      token: token,
      fromJson: (json) => InboxMessage.fromJson(json),
    );
  }

  Future<InboxMessage> markRead({
    required int id,
    required bool isRead,
    required String token,
  }) {
    return ApiClient.request<InboxMessage>(
      path: '${ApiConfig.inbox}/$id/read',
      method: 'PATCH',
      token: token,
      body: {'isRead': isRead},
      fromJson: (json) => InboxMessage.fromJson(json),
    );
  }

  Future<void> deleteMessage({
    required int id,
    required String token,
  }) {
    return ApiClient.requestVoid(
      path: '${ApiConfig.inbox}/$id',
      method: 'DELETE',
      token: token,
    );
  }

  Future<InboxMessage> createMessage({
    required String token,
    required MessageKind kind,
    required String title,
    required String body,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return ApiClient.request<InboxMessage>(
      path: ApiConfig.inbox,
      method: 'POST',
      token: token,
      body: {
        'kind': messageKindToString(kind),
        'title': title,
        'body': body,
        if (tags != null) 'tags': tags,
        if (metadata != null) 'metadata': metadata,
      },
      fromJson: (json) => InboxMessage.fromJson(json),
    );
  }
}
