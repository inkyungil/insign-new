// lib/models/podcast.dart
import 'package:equatable/equatable.dart';

/// Data class for a single podcast episode.
class Episode extends Equatable {
  final String id;
  final String title;
  final String channel;
  final String description;
  final String audioUrl;
  final String imageUrl;
  final Duration duration;
  final DateTime publishedAt;
  final List<String> tags;
  final double progress; // 0.0 to 1.0

  const Episode({
    required this.id,
    required this.title,
    required this.channel,
    required this.description,
    required this.audioUrl,
    required this.imageUrl,
    required this.duration,
    required this.publishedAt,
    required this.tags,
    this.progress = 0.0,
  });

  @override
  List<Object> get props => [id, title, channel, description, audioUrl, imageUrl, duration, publishedAt, tags, progress];

  Episode copyWith({
    double? progress,
  }) {
    return Episode(
      id: id,
      title: title,
      channel: channel,
      description: description,
      audioUrl: audioUrl,
      imageUrl: imageUrl,
      duration: duration,
      publishedAt: publishedAt,
      tags: tags,
      progress: progress ?? this.progress,
    );
  }
}
