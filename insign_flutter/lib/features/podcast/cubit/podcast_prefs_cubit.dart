// lib/features/podcast/cubit/podcast_prefs_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

class PodcastPrefsState extends Equatable {
  final bool isSubscribed;
  final Set<String> favoriteEpisodeIds;
  final Set<String> downloadedEpisodeIds;

  const PodcastPrefsState({
    this.isSubscribed = false,
    this.favoriteEpisodeIds = const {},
    this.downloadedEpisodeIds = const {},
  });

  @override
  List<Object> get props => [isSubscribed, favoriteEpisodeIds, downloadedEpisodeIds];

  PodcastPrefsState copyWith({
    bool? isSubscribed,
    Set<String>? favoriteEpisodeIds,
    Set<String>? downloadedEpisodeIds,
  }) {
    return PodcastPrefsState(
      isSubscribed: isSubscribed ?? this.isSubscribed,
      favoriteEpisodeIds: favoriteEpisodeIds ?? this.favoriteEpisodeIds,
      downloadedEpisodeIds: downloadedEpisodeIds ?? this.downloadedEpisodeIds,
    );
  }
}

class PodcastPrefsCubit extends Cubit<PodcastPrefsState> {
  PodcastPrefsCubit() : super(const PodcastPrefsState());

  void toggleSubscription() {
    emit(state.copyWith(isSubscribed: !state.isSubscribed));
  }

  void toggleFavorite(String episodeId) {
    final newFavorites = Set<String>.from(state.favoriteEpisodeIds);
    if (newFavorites.contains(episodeId)) {
      newFavorites.remove(episodeId);
    } else {
      newFavorites.add(episodeId);
    }
    emit(state.copyWith(favoriteEpisodeIds: newFavorites));
  }

  void toggleDownload(String episodeId) {
    final newDownloads = Set<String>.from(state.downloadedEpisodeIds);
    if (newDownloads.contains(episodeId)) {
      newDownloads.remove(episodeId);
    } else {
      newDownloads.add(episodeId);
    }
    emit(state.copyWith(downloadedEpisodeIds: newDownloads));
  }
}
