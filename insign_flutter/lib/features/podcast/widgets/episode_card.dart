// lib/features/podcast/widgets/episode_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/core/reusable/cache_image_network.dart';
import 'package:insign/features/podcast/cubit/podcast_player_cubit.dart';
import 'package:insign/models/podcast.dart';

class EpisodeCard extends StatelessWidget {
  final Episode episode;
  final double boxImageSize;

  const EpisodeCard({
    super.key,
    required this.episode,
    required this.boxImageSize,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      // Using the default CardTheme from app_theme.dart
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          context.read<PodcastPlayerCubit>().play(episode);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              child: buildCacheNetworkImage(
                width: boxImageSize,
                height: boxImageSize,
                url: episode.imageUrl,
              ),
            ),
            Container(
              margin: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.title,
                    style: const TextStyle(fontSize: 13, color: black21, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    episode.channel,
                    style: const TextStyle(fontSize: 12, color: softGrey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${episode.duration.inMinutes}분',
                    style: const TextStyle(fontSize: 12, color: softGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}