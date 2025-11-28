import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:insign/core/constants.dart';
import 'package:insign/data/contract_repository.dart';
import 'package:insign/data/services/session_service.dart';
import 'package:insign/models/contract.dart';

const List<String> _tabs = ['전체', '작성중', '서명대기', '완료', '거절됨', '기한만료'];
const String _datePlaceholder = '-';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final ContractRepository _repository = ContractRepository();
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormatter = DateFormat('yyyy.MM.dd');

  List<Contract> _contracts = const [];
  bool _loading = true;
  String _activeTab = _tabs.first;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContracts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContracts({bool isRefresh = false}) async {
    if (!mounted) return;
    if (!isRefresh) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final token = await SessionService.getAccessToken();
      final contracts = await _repository.fetchContracts(token: token);
      if (!mounted) return;
      setState(() {
        _contracts = contracts;
        _errorMessage = null;
      });
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;
      setState(() {
        _errorMessage = message.isEmpty ? '계약 목록을 불러오지 못했습니다.' : message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  List<Contract> get _filteredContracts {
    final query = _searchController.text.trim().toLowerCase();

    bool matchesTab(Contract contract) {
      final label = _statusLabel(contract);

      switch (_activeTab) {
        case '전체':
          return true;
        case '작성중':
          return label == '기안 완료';
        case '서명대기':
          return label == '서명 대기';
        case '완료':
          return label == '서명 완료';
        case '거절됨':
          return label == '서명 거절';
        case '기한만료':
          return _isExpired(contract);
        default:
          return true;
      }
    }

    return _contracts.where((contract) {
      final matchesQuery = contract.name.toLowerCase().contains(query);
      return matchesQuery && matchesTab(contract);
    }).toList();
  }

  String? _extractMetadataStatus(Map<String, dynamic>? metadata) {
    if (metadata == null) {
      return null;
    }
    final value = metadata['status'];
    if (value is String) {
      return value;
    }
    return null;
  }

  bool _isExpired(Contract contract) {
    final end = contract.endDate;
    if (end == null) {
      return false;
    }
    return end.isBefore(DateTime.now());
  }

  String _statusLabel(Contract contract) {
    final metadataStatus = _extractMetadataStatus(contract.metadata);
    if (metadataStatus == '서명 완료') {
      return '서명 완료';
    }
    if (metadataStatus == '서명 대기') {
      return '서명 대기';
    }

    switch (contract.status) {
      case 'signature_completed':
        return '서명 완료';
      case 'signature_declined':
        return '서명 거절';
      case 'active':
        return '서명 대기';
      case 'draft':
        return '기안 완료';
      default:
        return _isExpired(contract) ? '기한만료' : '진행중';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return _datePlaceholder;
    }
    return _dateFormatter.format(date.toLocal());
  }

  void _handleCreateContract() {
    context.push('/create-contract');
  }

  void _handleOpenContract(int id) {
    context.push('/contracts/$id');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    final contracts = _filteredContracts;

    final slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              const Text(
                '계약',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => context.push('/inbox'),
                icon: const Icon(Icons.notifications_outlined),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        sliver: SliverToBoxAdapter(child: _buildHeader(context)),
      ),
    ];

    if (_errorMessage != null) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: _ErrorBanner(message: _errorMessage!, onRetry: () => _loadContracts()),
          ),
        ),
      );
    }

    if (contracts.isEmpty) {
      slivers.add(const SliverToBoxAdapter(child: _EmptyState()));
    } else {
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final contract = contracts[index];
              return _ContractCard(
                contract: contract,
                statusLabel: _statusLabel(contract),
                startDate: _formatDate(contract.startDate),
                endDate: _formatDate(contract.endDate),
                onTap: () => _handleOpenContract(contract.id),
              );
            },
            childCount: contracts.length,
          ),
        ),
      );
    }

    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        sliver: SliverToBoxAdapter(
          child: OutlinedButton(
            onPressed: _handleCreateContract,
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: const BorderSide(color: primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('+ 새 계약 작성', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: primaryColor,
          onRefresh: () => _loadContracts(isRefresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: slivers,
          ),
        ),
      ),
    );
  }

  String _headerSubtitle() {
    if (_loading) {
      return '계약을 불러오는 중입니다...';
    }
    if (_contracts.isEmpty) {
      return '아직 등록된 계약이 없습니다.';
    }

    final filteredCount = _filteredContracts.length;
    if (filteredCount == _contracts.length) {
      return '총 ${_contracts.length}건의 계약을 관리하고 있어요.';
    }
    return '총 ${_contracts.length}건 중 $filteredCount건이 표시되고 있어요.';
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _headerSubtitle(),
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 20),
        _buildSearchBar(context),
        const SizedBox(height: 16),
        _buildStatusChips(),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '계약서 검색... ',
                hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('필터 기능은 준비 중입니다.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.filter_list, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in _tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(tab),
                selected: tab == _activeTab,
                onSelected: (_) => setState(() => _activeTab = tab),
                selectedColor: primaryColor,
                labelStyle: TextStyle(
                  color: tab == _activeTab ? Colors.white : const Color(0xFF475569),
                  fontWeight: tab == _activeTab ? FontWeight.w700 : FontWeight.w500,
                ),
                backgroundColor: const Color(0xFFE2E8F0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  final Contract contract;
  final String statusLabel;
  final String startDate;
  final String endDate;
  final VoidCallback onTap;

  const _ContractCard({
    required this.contract,
    required this.statusLabel,
    required this.startDate,
    required this.endDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14111827),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0x1F4F46E5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.description_outlined, color: primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contract.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '의뢰인: ${contract.clientName} · 수행자: ${contract.performerName?.isNotEmpty == true ? contract.performerName : '미정'}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x1F4F46E5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(startDate, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                        const SizedBox(width: 8),
                        Text(endDate, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      ],
                    ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: const [
          Icon(Icons.description_outlined, size: 32, color: Color(0xFF9CA3AF)),
          SizedBox(height: 8),
          Text(
            '등록된 계약이 없습니다',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
          ),
          SizedBox(height: 4),
          Text(
            '새 계약을 작성해 주세요.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '계약 정보를 불러오지 못했습니다.',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('다시 시도', style: TextStyle(color: Color(0xFFDC2626))),
            ),
          ],
        ),
      ),
    );
  }
}
