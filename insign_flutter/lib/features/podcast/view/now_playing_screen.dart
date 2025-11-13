// lib/features/podcast/view/now_playing_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insign/features/podcast/cubit/podcast_player_cubit.dart';
import 'package:insign/features/podcast/cubit/podcast_player_state.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: BlocBuilder<PodcastPlayerCubit, PodcastPlayerState>(
        builder: (context, state) {
          if (state is! PlayerActive) {
            return const Center(child: Text('No active episode.'));
          }

          final episode = state.currentEpisode;
          final positionData = state.positionData;
          final isPlaying = state.playerState.playing;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: episode.imageUrl,
                    fit: BoxFit.cover,
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.width * 0.8,
                  ),
                ),
                const SizedBox(height: 32),
                Text(episode.title, style: textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(episode.channel, style: textTheme.titleMedium?.copyWith(color: Colors.grey)),
                const Spacer(),
                Slider(
                  value: positionData.position.inSeconds.toDouble(),
                  max: positionData.duration.inSeconds.toDouble(),
                  onChanged: (value) {
                    context.read<PodcastPlayerCubit>().seek(Duration(seconds: value.toInt()));
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(positionData.position)),
                      Text(_formatDuration(positionData.duration)),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(icon: const Icon(Icons.replay_10), onPressed: () => context.read<PodcastPlayerCubit>().seekBackward()),
                    IconButton(
                      icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                      iconSize: 64,
                      onPressed: () {
                         if (isPlaying) {
                           context.read<PodcastPlayerCubit>().pause();
                         } else {
                           context.read<PodcastPlayerCubit>().resume();
                         }
                      },
                    ),
                    IconButton(icon: const Icon(Icons.forward_10), onPressed: () => context.read<PodcastPlayerCubit>().seekForward()),
                  ],
                ),
                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }
}
