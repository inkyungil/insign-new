// lib/features/podcast/widgets/mini_player.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/features/podcast/cubit/podcast_player_cubit.dart';
import 'package:insign/features/podcast/cubit/podcast_player_state.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PodcastPlayerCubit, PodcastPlayerState>(
      builder: (context, state) {
        if (state is! PlayerActive) {
          return const SizedBox.shrink();
        }

        final episode = state.currentEpisode;
        final isPlaying = state.playerState.playing;

        final position = state.positionData.position.inSeconds.toDouble();
        final durationSec = state.positionData.duration.inSeconds.toDouble();
        final maxValue = durationSec < 1.0 ? 1.0 : durationSec;
        final volume = state.volume;

        String format(Duration d) {
          final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
          final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
          return "$m:$s";
        }

        final theme = Theme.of(context);
        final percent = (volume * 100).round();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('재생 중', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(episode.title, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                      GestureDetector(
                        onTap: () => context.go('/now_playing'),
                        child: const Icon(Icons.expand_less),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(format(Duration(seconds: position.toInt())), style: theme.textTheme.bodySmall),
                      Text(format(Duration(seconds: maxValue.toInt())), style: theme.textTheme.bodySmall),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 4),
                    child: Slider(
                      value: position,
                      max: maxValue,
                      onChanged: (v) => context.read<PodcastPlayerCubit>().seek(Duration(seconds: v.toInt())),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10),
                        onPressed: () => context.read<PodcastPlayerCubit>().seekBackward(),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          if (isPlaying) {
                            context.read<PodcastPlayerCubit>().pause();
                          } else {
                            context.read<PodcastPlayerCubit>().resume();
                          }
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                          child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: theme.colorScheme.onPrimary, size: 34),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.forward_10),
                        onPressed: () => context.read<PodcastPlayerCubit>().seekForward(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.volume_down),
                      Expanded(
                        child: Slider(
                          value: volume,
                          onChanged: (v) => context.read<PodcastPlayerCubit>().setVolume(v),
                        ),
                      ),
                      Text('$percent%'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
