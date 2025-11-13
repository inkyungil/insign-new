// lib/features/podcast/cubit/podcast_player_cubit.dart

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:insign/models/podcast.dart';
import 'package:rxdart/rxdart.dart';
import 'package:audio_session/audio_session.dart';
import 'podcast_player_state.dart';

class PodcastPlayerCubit extends Cubit<PodcastPlayerState> {
  final AudioPlayer _audioPlayer;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _volumeSubscription;

  PodcastPlayerCubit(this._audioPlayer) : super(PlayerInitial()) {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    _playerStateSubscription = _audioPlayer.playerStateStream.listen((playerState) {
      if (state is PlayerActive) {
        final activeState = state as PlayerActive;
        emit(activeState.copyWith(playerState: playerState));
      }
    });

    _positionSubscription = Rx.combineLatest3<Duration, Duration, Duration?, PlayerPositionData>(
      _audioPlayer.positionStream,
      _audioPlayer.bufferedPositionStream,
      _audioPlayer.durationStream,
      (position, bufferedPosition, duration) => PlayerPositionData(
        position,
        bufferedPosition,
        duration ?? Duration.zero,
      ),
    ).listen((positionData) {
      if (state is PlayerActive) {
        final activeState = state as PlayerActive;
        emit(activeState.copyWith(positionData: positionData));
      }
    });

    _volumeSubscription = _audioPlayer.volumeStream.listen((vol) {
      if (state is PlayerActive) {
        final activeState = state as PlayerActive;
        emit(activeState.copyWith(volume: vol));
      }
    });
  }

  Future<void> play(Episode episode) async {
    try {
      // If it's the same episode, just play. Otherwise, set new source.
      if (state is PlayerActive && (state as PlayerActive).currentEpisode.id == episode.id) {
        _audioPlayer.play();
      } else {
        await _audioPlayer.setUrl(episode.audioUrl);
        emit(PlayerActive(
          currentEpisode: episode,
          playerState: _audioPlayer.playerState,
          positionData: const PlayerPositionData(Duration.zero, Duration.zero, Duration.zero),
          volume: _audioPlayer.volume,
        ));
        _audioPlayer.play();
      }
    } catch (e) {
      // Handle error
    }
  }

  void pause() {
    _audioPlayer.pause();
  }

  void resume() {
    _audioPlayer.play();
  }

  void seek(Duration position) {
    _audioPlayer.seek(position);
  }

  void seekForward() {
    final newPosition = _audioPlayer.position + const Duration(seconds: 10);
    seek(newPosition);
  }

  void seekBackward() {
    final newPosition = _audioPlayer.position - const Duration(seconds: 10);
    seek(newPosition);
  }

  void setSpeed(double speed) {
    _audioPlayer.setSpeed(speed);
    if (state is PlayerActive) {
      emit((state as PlayerActive).copyWith(speed: speed));
    }
  }

  void setVolume(double vol) {
    _audioPlayer.setVolume(vol);
    if (state is PlayerActive) {
      emit((state as PlayerActive).copyWith(volume: vol));
    }
  }

  void stop() {
    _audioPlayer.stop();
    emit(PlayerInitial());
  }

  @override
  Future<void> close() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _volumeSubscription?.cancel();
    _audioPlayer.dispose();
    return super.close();
  }
}
