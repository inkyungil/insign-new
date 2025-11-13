// lib/models/chat_message.dart

import 'package:equatable/equatable.dart';

enum MessageSender { user, assistant }

class ChatMessage extends Equatable {
  final String id;
  final String content;
  final MessageSender sender;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.sender,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [id, content, sender, timestamp];
}

class QuickAction extends Equatable {
  final String id;
  final String title;
  final String query;

  const QuickAction({
    required this.id,
    required this.title,
    required this.query,
  });

  @override
  List<Object?> get props => [id, title, query];
}
