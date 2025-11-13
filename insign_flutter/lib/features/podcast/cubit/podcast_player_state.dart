// lib/features/podcast/cubit/podcast_player_state.dart

import 'package:equatable/equatable.dart';
import 'package:just_audio/just_audio.dart';
import 'package:insign/models/podcast.dart';

class PlayerPositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  const PlayerPositionData(this.position, this.bufferedPosition, this.duration);
}

abstract class PodcastPlayerState extends Equatable {
  const PodcastPlayerState();

  @override
  List<Object?> get props => [];
}

class PlayerInitial extends PodcastPlayerState {}

class PlayerActive extends PodcastPlayerState {
  final Episode currentEpisode;
  final PlayerState playerState; // from just_audio
  final PlayerPositionData positionData;
  final double speed;
  final double volume; // 0.0 - 1.0

  const PlayerActive({
    required this.currentEpisode,
    required this.playerState,
    required this.positionData,
    this.speed = 1.0,
    this.volume = 1.0,
  });

  @override
  List<Object?> get props => [currentEpisode, playerState, positionData.position, positionData.duration, speed, volume];

  PlayerActive copyWith({
    Episode? currentEpisode,
    PlayerState? playerState,
    PlayerPositionData? positionData,
    double? speed,
    double? volume,
  }) {
    return PlayerActive(
      currentEpisode: currentEpisode ?? this.currentEpisode,
      playerState: playerState ?? this.playerState,
      positionData: positionData ?? this.positionData,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
    );
  }
}
