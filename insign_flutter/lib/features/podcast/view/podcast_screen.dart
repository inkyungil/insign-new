// lib/features/podcast/view/podcast_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/data/podcast_repository.dart';
import 'package:insign/features/podcast/cubit/podcast_player_cubit.dart';
import 'package:insign/models/podcast.dart';

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  late Future<List<Episode>> _episodesFuture;
  String _query = '';
  String _selectedFilter = '전체';

  @override
  void initState() {
    super.initState();
    _episodesFuture = _getMockEpisodes();
  }

  Future<List<Episode>> _getMockEpisodes() async {
    // 실제 API 호출 대신 목 데이터 반환
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockEpisodes();
  }

  List<Episode> _mockEpisodes() {
    final now = DateTime.now();
    return [
      Episode(
        id: '1',
        title: '삼성전자 3분기 실적 분석',
        channel: '투자 분석',
        description: '반도체 업황 회복과 함께 삼성전자의 실적이 개선되고 있습니다. 전문가 분석을 들어보세요.',
        audioUrl: 'https://example.com/audio1.mp3',
        imageUrl: 'https://example.com/image1.jpg',
        duration: const Duration(minutes: 12, seconds: 30),
        publishedAt: now.subtract(const Duration(hours: 2)),
        tags: ['#NEW', '#종목분석'],
      ),
      Episode(
        id: '2',
        title: '미국 연준 금리 동결 의미',
        channel: '글로벌 시황',
        description: '연준의 금리 동결 결정이 국내 증시에 미치는 영향을 분석합니다.',
        audioUrl: 'https://example.com/audio2.mp3',
        imageUrl: 'https://example.com/image2.jpg',
        duration: const Duration(minutes: 8, seconds: 45),
        publishedAt: now.subtract(const Duration(hours: 4)),
        tags: ['#NEW', '#글로벌시황'],
      ),
      Episode(
        id: '3',
        title: 'AI 기술주 투자 전망',
        channel: '종목 분석',
        description: '인공지능 기술의 발전과 관련 종목들의 투자 가치를 살펴봅니다.',
        audioUrl: 'https://example.com/audio3.mp3',
        imageUrl: 'https://example.com/image3.jpg',
        duration: const Duration(minutes: 15, seconds: 20),
        publishedAt: now.subtract(const Duration(hours: 6)),
        tags: ['#종목분석'],
      ),
      Episode(
        id: '4',
        title: '2차전지 업계 동향',
        channel: '데일리 브리핑',
        description: '전기차 시장 성장과 함께 2차전지 업계의 최신 동향을 정리했습니다.',
        audioUrl: 'https://example.com/audio4.mp3',
        imageUrl: 'https://example.com/image4.jpg',
        duration: const Duration(minutes: 11, seconds: 15),
        publishedAt: now.subtract(const Duration(hours: 8)),
        tags: ['#데일리브리핑'],
      ),
      Episode(
        id: '5',
        title: '오늘의 증시 브리핑',
        channel: '데일리 브리핑',
        description: '코스피와 코스닥의 주요 이슈와 내일 주목할 종목들을 소개합니다.',
        audioUrl: 'https://example.com/audio5.mp3',
        imageUrl: 'https://example.com/image5.jpg',
        duration: const Duration(minutes: 9, seconds: 30),
        publishedAt: now.subtract(const Duration(hours: 10)),
        tags: ['#NEW', '#데일리브리핑'],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Episode>>(
        future: _episodesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No episodes found.'));
          }

          final all = snapshot.data!;
          final episodes = all.where((e) {
            final matchQuery = _query.isEmpty || e.title.contains(_query) || e.description.contains(_query);
            final matchFilter = _selectedFilter == '전체' || e.tags.map((t) => t.replaceAll('#', '')).contains(_selectedFilter);
            return matchQuery && matchFilter;
          }).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: Icon(Icons.headphones, size: 56, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text('AI 뉴스 팟캐스트', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text('주요 뉴스를 음성으로 편리하게 들어보세요.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: '팟캐스트 검색...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedFilter,
                        items: <String>['전체', ...{for (final e in all) ...e.tags.map((t) => t.replaceAll('#', ''))}].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => _selectedFilter = v ?? '전체'),
                        decoration: InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: episodes.length,
                itemBuilder: (context, index) {
                  final ep = episodes[index];
                  return _EpisodeListTile(episode: ep);
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
          );
        },
      ),
    );
  }
}

class _EpisodeListTile extends StatelessWidget {
  final Episode episode;

  const _EpisodeListTile({required this.episode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    String formatDuration(Duration duration) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 태그 영역
            Row(
              children: [
                // NEW 태그 (있는 경우만)
                if (episode.tags.any((tag) => tag.contains('NEW')))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (episode.tags.any((tag) => tag.contains('NEW')))
                  const SizedBox(width: 8),
                // 카테고리 태그
                if (episode.tags.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor, // 메인 색상
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      episode.tags.firstWhere(
                        (tag) => !tag.contains('NEW'),
                        orElse: () => episode.tags.first,
                      ).replaceAll('#', ''),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // 제목
            Text(
              episode.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            // 설명
            Text(
              episode.description,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // 하단 정보
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  formatDuration(episode.duration),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                BlocBuilder<PodcastPlayerCubit, dynamic>(
                  builder: (context, state) {
                    bool isCurrent = false;
                    bool playing = false;
                    try {
                      if (state != null && state.runtimeType.toString().contains('PlayerActive')) {
                        final active = state as dynamic;
                        final current = active.currentEpisode;
                        isCurrent = current.id == episode.id;
                        playing = active.playerState.playing == true;
                      }
                    } catch (_) {}

                    if (isCurrent) {
                      return FilledButton.tonalIcon(
                        onPressed: () {
                          if (playing) {
                            context.read<PodcastPlayerCubit>().pause();
                          } else {
                            context.read<PodcastPlayerCubit>().resume();
                          }
                        },
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        label: Text(playing ? '일시정지' : '재생'),
                      );
                    }

                    return FilledButton.tonalIcon(
                      onPressed: () => context.read<PodcastPlayerCubit>().play(episode),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('재생'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
