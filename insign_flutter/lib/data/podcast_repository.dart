// lib/data/podcast_repository.dart

import 'package:insign/models/podcast.dart';

/// A repository to fetch podcast episodes.
class PodcastRepository {
  /// Fetches a list of mock podcast episodes.
  Future<List<Episode>> fetchEpisodes() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    return [
      Episode(
        id: '1',
        title: 'AI in Stock Market Analysis',
        channel: 'FinTech Today',
        description: 'Exploring how artificial intelligence is revolutionizing stock market predictions and trading strategies.',
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        imageUrl: 'https://picsum.photos/seed/1/200',
        duration: const Duration(minutes: 28, seconds: 45),
        publishedAt: DateTime.now().subtract(const Duration(days: 2)),
        tags: ['#AI', '#주식', '#핀테크'],
      ),
      Episode(
        id: '2',
        title: 'Global Economic Outlook 2025',
        channel: 'Market Movers',
        description: 'A deep dive into the macroeconomic trends shaping the global economy for the upcoming year.',
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        imageUrl: 'https://picsum.photos/seed/2/200',
        duration: const Duration(minutes: 35, seconds: 12),
        publishedAt: DateTime.now().subtract(const Duration(days: 4)),
        tags: ['#거시경제', '#전망'],
        progress: 0.5,
      ),
      Episode(
        id: '3',
        title: 'The Rise of Robo-Advisors',
        channel: 'FinTech Today',
        description: 'Are robo-advisors the future of personal investment? We discuss the pros and cons.',
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
        imageUrl: 'https://picsum.photos/seed/3/200',
        duration: const Duration(minutes: 22, seconds: 30),
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
        tags: ['#로보어드바이저', '#자산관리'],
      ),
      Episode(
        id: '4',
        title: 'Understanding Blockchain Beyond Crypto',
        channel: 'Tech Forward',
        description: 'Exploring the application of blockchain technology in supply chain, healthcare, and more.',
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
        imageUrl: 'https://picsum.photos/seed/4/200',
        duration: const Duration(minutes: 42, seconds: 5),
        publishedAt: DateTime.now().subtract(const Duration(days: 10)),
        tags: ['#블록체인', '#기술'],
      ),
      Episode(
        id: '5',
        title: 'Interview with a Venture Capitalist',
        channel: 'Startup Stories',
        description: 'An insightful conversation with a leading VC about what they look for in a startup.',
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
        imageUrl: 'https://picsum.photos/seed/5/200',
        duration: const Duration(minutes: 55, seconds: 18),
        publishedAt: DateTime.now().subtract(const Duration(days: 15)),
        tags: ['#스타트업', '#VC'],
      ),
      Episode(
        id: '6',
        title: 'Behavioral Economics and Your Portfolio',
        channel: 'Market Movers',
        description: 'How psychological biases can impact your investment decisions and how to avoid common pitfalls.',
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
        imageUrl: 'https://picsum.photos/seed/6/200',
        duration: const Duration(minutes: 31, seconds: 40),
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
        tags: ['#행동경제학', '#심리'],
      ),
    ];
  }
}
