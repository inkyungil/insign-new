// lib/features/settings/view/inbox_screen.dart

import 'package:flutter/material.dart';
import 'package:insign/data/inbox_repository.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/models/inbox_message.dart';


const _adminGeneralTag = 'push/admin/general';
const _adminContractTag = 'push/admin/contract';

bool _matchesGeneralCategory(InboxMessage message) {
  if (message.tags.contains(_adminContractTag)) {
    return false;
  }
  if (message.tags.contains(_adminGeneralTag)) {
    return true;
  }
  return message.kind == MessageKind.alert;
}

bool _matchesContractCategory(InboxMessage message) {
  return message.tags.contains(_adminContractTag);
}

String _labelForKind(MessageKind kind) {
  switch (kind) {
    case MessageKind.alert:
      return '알림';
    case MessageKind.news:
      return '뉴스';
    case MessageKind.report:
      return '리포트';
    case MessageKind.system:
      return '시스템';
    case MessageKind.notice:
    default:
      return '공지사항';
  }
}

String _primaryCategoryLabel(InboxMessage message) {
  if (_matchesContractCategory(message)) {
    return '계약 진행';
  }
  if (message.tags.contains(_adminGeneralTag)) {
    return '앱 알림';
  }
  return _labelForKind(message.kind);
}

Color _messageAccentColor(InboxMessage message) {
  if (_matchesContractCategory(message)) {
    return const Color(0xFF0F766E);
  }
  if (message.tags.contains(_adminGeneralTag)) {
    return const Color(0xFF2563EB);
  }
  switch (message.kind) {
    case MessageKind.alert:
      return const Color(0xFFF97316);
    case MessageKind.news:
      return const Color(0xFF1D4ED8);
    case MessageKind.report:
      return const Color(0xFF16A34A);
    case MessageKind.system:
      return const Color(0xFFDC2626);
    case MessageKind.notice:
    default:
      return const Color(0xFF4338CA);
  }
}

IconData _messageIcon(InboxMessage message) {
  if (_matchesContractCategory(message)) {
    return Icons.assignment_turned_in_outlined;
  }
  if (message.tags.contains(_adminGeneralTag)) {
    return Icons.notifications_active_outlined;
  }
  switch (message.kind) {
    case MessageKind.alert:
      return Icons.warning_amber_outlined;
    case MessageKind.news:
      return Icons.article_outlined;
    case MessageKind.report:
      return Icons.description_outlined;
    case MessageKind.system:
      return Icons.waves_outlined;
    case MessageKind.notice:
    default:
      return Icons.campaign_outlined;
  }
}

List<String> _chipLabelsForMessage(InboxMessage message) {
  final labels = <String>{};
  labels.add(_primaryCategoryLabel(message));
  for (final tag in message.tags) {
    if (tag == _adminGeneralTag || tag == _adminContractTag) {
      continue;
    }
    labels.add('#$tag');
  }
  return labels.toList();
}

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final InboxRepository _repository = InboxRepository();
  final TextEditingController _searchController = TextEditingController();

  List<InboxMessage> _messages = const [];
  String _filter = '전체';
  String _searchQuery = '';
  bool _loading = true;
  String? _errorMessage;
  String? _token;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _loadMessages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String> _requireToken() async {
    if (_token != null && _token!.isNotEmpty) {
      return _token!;
    }
    final token = await SessionService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('메시지를 확인하려면 로그인 후 이용해 주세요.');
    }
    _token = token;
    return token;
  }

  Future<void> _loadMessages({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _loading = !isRefresh;
    });

    try {
      final token = await _requireToken();
      final messages = await _repository.fetchMessages(token: token);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _errorMessage = null;
      });
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;
      setState(() {
        _errorMessage = message.isEmpty ? '메시지를 불러오지 못했습니다.' : message;
      });
      if (message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _deleteMessage(InboxMessage target) async {
    List<InboxMessage>? previous;
    try {
      previous = _messages;
      setState(() {
        _messages = _messages.where((m) => m.id != target.id).toList();
      });
      final token = await _requireToken();
      await _repository.deleteMessage(id: target.id, token: token);
    } catch (error) {
      if (!mounted) return;
      if (previous != null) {
        setState(() {
          _messages = previous!;
        });
      }
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.isEmpty ? '메시지를 삭제하지 못했습니다.' : message)),
      );
    }
  }

  Future<void> _markMessageRead(InboxMessage message) async {
    if (message.isRead) {
      return;
    }
    try {
      final token = await _requireToken();
      final updated = await _repository.markRead(
        id: message.id,
        isRead: true,
        token: token,
      );
      if (!mounted) return;
      setState(() {
        _messages = _messages.map((m) => m.id == updated.id ? updated : m).toList();
      });
    } catch (error) {
      final messageText = error.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageText.isEmpty ? '메시지를 읽음 처리하지 못했습니다.' : messageText)),
      );
    }
  }

  String _subtitleText() {
    if (_loading) {
      return '메시지를 불러오는 중입니다...';
    }
    if (_messages.isEmpty) {
      return '아직 도착한 메시지가 없습니다.';
    }
    final unread = _messages.where((m) => !m.isRead).length;
    if (unread > 0) {
      return '총 ${_messages.length}건, 읽지 않은 메시지 $unread건';
    }
    return '총 ${_messages.length}건의 메시지를 확인할 수 있어요.';
  }

  List<InboxMessage> get _filteredMessages {
    final base = _messages.where((m) {
      if (_filter == '읽지 않음' && m.isRead) {
        return false;
      }
      if (_filter == '앱 알림' && !_matchesGeneralCategory(m)) {
        return false;
      }
      if (_filter == '계약 진행' && !_matchesContractCategory(m)) {
        return false;
      }
      if (_filter == '공지사항' && m.kind != MessageKind.notice) {
        return false;
      }
      return true;
    });

    if (_searchQuery.isEmpty) {
      return base.toList();
    }

    final query = _searchQuery.toLowerCase();
    return base
        .where((m) {
          if (m.title.toLowerCase().contains(query)) return true;
          if (m.body.toLowerCase().contains(query)) return true;
          if (_primaryCategoryLabel(m).toLowerCase().contains(query)) return true;
          return m.tags.any((tag) => tag.toLowerCase().contains(query));
        })
        .toList();
  }

  Future<void> _handleDelete(InboxMessage message) async {
    await _deleteMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMessages;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('메시지함'),
        foregroundColor: const Color(0xFF111827),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 12),
            child: Text(
              _subtitleText(),
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '메시지 검색…',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _ErrorBanner(
                message: _errorMessage!,
                onRetry: () => _loadMessages(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '카테고리',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: '전체',
                      count: _messages.length,
                      selected: _filter == '전체',
                      onTap: () => setState(() => _filter = '전체'),
                    ),
                    _FilterChip(
                      label: '읽지 않음',
                      count: _messages.where((m) => !m.isRead).length,
                      selected: _filter == '읽지 않음',
                      onTap: () => setState(() => _filter = '읽지 않음'),
                    ),
                    _FilterChip(
                      label: '앱 알림',
                      count: _messages.where(_matchesGeneralCategory).length,
                      selected: _filter == '앱 알림',
                      onTap: () => setState(() => _filter = '앱 알림'),
                    ),
                    _FilterChip(
                      label: '계약 진행',
                      count: _messages.where(_matchesContractCategory).length,
                      selected: _filter == '계약 진행',
                      onTap: () => setState(() => _filter = '계약 진행'),
                    ),
                    _FilterChip(
                      label: '공지사항',
                      count: _messages.where((m) => m.kind == MessageKind.notice).length,
                      selected: _filter == '공지사항',
                      onTap: () => setState(() => _filter = '공지사항'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: () => _loadMessages(isRefresh: true),
              child: _loading && filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : filtered.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            final message = filtered[index];
                            return Dismissible(
                              key: Key('${message.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete_outline, color: Colors.white),
                              ),
                              onDismissed: (_) => _handleDelete(message),
                              child: _MessageTile(
                                message: message,
                                onTap: () => _markMessageRead(message),
                              ),
                            );
                          },
                        ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: selected
              ? Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  width: 1,
                )
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final InboxMessage message;
  final VoidCallback onTap;

  const _MessageTile({
    required this.message,
    required this.onTap,
  });

  String _formatTimeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = _messageAccentColor(message);
    final iconData = _messageIcon(message);
    final chipLabels = _chipLabelsForMessage(message);

    return Material(
      color: message.isRead ? Colors.white : const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(20),
      elevation: message.isRead ? 1 : 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(iconData, color: accentColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            message.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: message.isRead ? FontWeight.w500 : FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatTimeAgo(message.createdAt),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    if (chipLabels.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: chipLabels
                            .map(
                              (label) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: accentColor.darken(),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _ColorDarken on Color {
  Color darken([double amount = .2]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          Icon(Icons.mark_email_unread_outlined, size: 48, color: Color(0xFFCBD5F5)),
          SizedBox(height: 12),
          Text(
            '새로운 메시지가 없습니다',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            '알림이 도착하면 이곳에서 바로 확인할 수 있어요.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
