// lib/models/inbox_message.dart

import 'package:equatable/equatable.dart';

enum MessageKind { notice, alert, news, report, system }

MessageKind messageKindFromString(String value) {
  switch (value) {
    case 'alert':
      return MessageKind.alert;
    case 'news':
      return MessageKind.news;
    case 'report':
      return MessageKind.report;
    case 'system':
      return MessageKind.system;
    case 'notice':
    default:
      return MessageKind.notice;
  }
}

String messageKindToString(MessageKind kind) {
  switch (kind) {
    case MessageKind.alert:
      return 'alert';
    case MessageKind.news:
      return 'news';
    case MessageKind.report:
      return 'report';
    case MessageKind.system:
      return 'system';
    case MessageKind.notice:
    default:
      return 'notice';
  }
}

class InboxMessage extends Equatable {
  final int id;
  final MessageKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final List<String> tags;
  final bool isRead;
  final DateTime? readAt;
  final Map<String, dynamic>? metadata;

  const InboxMessage({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.tags = const [],
    this.isRead = false,
    this.readAt,
    this.metadata,
  });

  factory InboxMessage.fromJson(Map<String, dynamic> json) {
    final tags = json['tags'];
    return InboxMessage(
      id: json['id'] as int,
      kind: messageKindFromString(json['kind'] as String? ?? 'notice'),
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      tags: tags is List ? tags.cast<String>() : const [],
      isRead: json['isRead'] as bool? ?? false,
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt'] as String) : null,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
    );
  }

  InboxMessage copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return InboxMessage(
      id: id,
      kind: kind,
      title: title,
      body: body,
      createdAt: createdAt,
      tags: tags,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      metadata: metadata,
    );
  }

  @override
  List<Object?> get props => [id, kind, title, body, createdAt, tags, isRead, readAt, metadata];
}
