// lib/features/podcast/widgets/podcast_header_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/features/podcast/cubit/podcast_prefs_cubit.dart';

class PodcastHeaderCard extends StatelessWidget {
  const PodcastHeaderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isSubscribed = context.watch<PodcastPrefsCubit>().state.isSubscribed;

    return Card(
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [primaryColor, softBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI 금융 인사이트 팟캐스트',
              style: textTheme.titleLarge?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              '총 128개 에피소드 · 누적 4,820시간 청취',
              style: textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () => context.read<PodcastPrefsCubit>().toggleSubscription(),
                style: FilledButton.styleFrom(
                  foregroundColor: isSubscribed ? theme.colorScheme.primary : Colors.white,
                  backgroundColor: isSubscribed ? theme.colorScheme.onPrimary : Colors.white24,
                ),
                child: Text(isSubscribed ? '구독중' : '구독하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
