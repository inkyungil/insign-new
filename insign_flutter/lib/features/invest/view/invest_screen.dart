import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insign/features/invest/cubit/stock_cubit.dart';
import 'package:insign/models/stock.dart';

class InvestScreen extends StatefulWidget {
  const InvestScreen({super.key});

  @override
  State<InvestScreen> createState() => _InvestScreenState();
}

class _InvestScreenState extends State<InvestScreen> {
  String _selectedFilter = "코스피";
  String _searchTerm = "";
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  final ScrollController _scrollController = ScrollController();

  final List<String> _filters = ["코스피", "코스닥", "코인", "관심"];
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupScrollListener();
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        // 관심 카테고리가 아닌 경우에만 더 많은 데이터 로드
        if (_selectedFilter != "관심" && _searchTerm.isEmpty) {
          final stockCubit = context.read<StockCubit>();
          stockCubit.loadMoreStocks(_getMarketKey(_selectedFilter));
        }
      }
    });
  }

  void _loadInitialData() {
    final stockCubit = context.read<StockCubit>();
    stockCubit.loadStocksByMarket(_getMarketKey(_selectedFilter));
    stockCubit.loadFavoriteStocks(); // 관심종목도 함께 로드
  }

  String _getMarketKey(String filter) {
    switch (filter) {
      case '코스피':
        return 'KOSPI';
      case '코스닥':
        return 'KOSDAQ';
      case '코인':
        return 'UPBIT-CRYPTO';
      default:
        return 'ALL';
    }
  }
  
  void _onSearchChanged(String query) {
    setState(() {
      _searchTerm = query;
    });
    
    // 이전 타이머 취소
    _debounceTimer?.cancel();
    
    if (query.isEmpty) {
      context.read<StockCubit>().clearSearch();
      return;
    }
    
    // 500ms 지연 후 검색 실행
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty && mounted) {
        context.read<StockCubit>().searchStocks(
          query, 
          market: _getMarketKey(_selectedFilter)
        );
      }
    });
  }


  List<Stock> _getDisplayStocks(StockState state) {
    if (_selectedFilter == "관심") {
      final favoriteStocks = state.favoriteStocks;
      
      if (_searchTerm.isEmpty) {
        return favoriteStocks;
      }
      
      // 관심종목에서 검색
      return favoriteStocks.where((stock) {
        final nameMatch = stock.name.toLowerCase().contains(_searchTerm.toLowerCase());
        final codeMatch = stock.code.toLowerCase().contains(_searchTerm.toLowerCase());
        return nameMatch || codeMatch;
      }).toList();
    }
    
    // 검색어가 있으면 검색 결과를, 없으면 전체 종목 목록을 반환
    return _searchTerm.isNotEmpty ? state.searchResults : state.stocks;
  }

  void _toggleFavorite(String stockCode) {
    context.read<StockCubit>().toggleFavorite(stockCode);
  }

  void _goToChatbotWithStock(Stock stock) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('챗봇 기능은 곧 업데이트될 예정입니다.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: "국내증시 / 코인명 검색",
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            
            const SizedBox(height: 16),

            // Filter Buttons
            Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: () {
                      // 이전 검색 타이머 취소
                      _debounceTimer?.cancel();
                      
                      setState(() {
                        _selectedFilter = filter;
                        _searchTerm = "";
                        _searchController.clear();
                      });
                      
                      final stockCubit = context.read<StockCubit>();
                      stockCubit.clearSearch();
                      
                      if (filter == "관심") {
                        stockCubit.loadFavoriteStocks();
                      } else {
                        stockCubit.loadStocksByMarket(_getMarketKey(filter));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected 
                          ? const Color(0xFF6A4C93) 
                          : Colors.white,
                      foregroundColor: isSelected 
                          ? Colors.white 
                          : Colors.black,
                      elevation: 0,
                      side: BorderSide(
                        color: isSelected 
                            ? const Color(0xFF6A4C93) 
                            : Colors.grey.shade300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  // 챗봇 컬럼 헤더
                  const SizedBox(
                    width: 36,
                    child: Text(
                      "챗봇",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    flex: 3,
                    child: Text(
                      "종목명",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.only(right: 8),
                      child: const Text(
                        "현재가",
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 1,
                    child: Text(
                      "전일대비",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      _selectedFilter == "코인" ? "거래량" 
                        : _selectedFilter == "관심" ? "시가총액\n(거래량)"
                        : "시가총액",
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  // 관심 컬럼 헤더
                  const SizedBox(
                    width: 32,
                    child: Text(
                      "관심",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stock List
            Expanded(
              child: BlocBuilder<StockCubit, StockState>(
                builder: (context, state) {
                  if (state.isLoading && _searchTerm.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (state.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '오류가 발생했습니다',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.error!,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadInitialData,
                            child: const Text('재시도'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  final stocks = _getDisplayStocks(state);
                  
                  if (stocks.isEmpty) {
                    return Center(
                      child: Text(
                        _searchTerm.isNotEmpty 
                            ? "검색 결과가 없습니다." 
                            : (_selectedFilter == "관심" 
                                ? "관심종목이 없습니다." 
                                : "데이터가 없습니다."),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  
                  return Column(
                    children: [
                      // 검색 중 표시
                      if (state.isSearching && _searchTerm.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text("검색 중...", style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: stocks.length + (state.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // 로딩 인디케이터 표시
                            if (index == stocks.length && state.isLoadingMore) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            
                            final stock = stocks[index];
                            final isFavorite = state.favoriteStockCodes.contains(stock.code);
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                        child: Row(
                          children: [
                            // Stock Info
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _goToChatbotWithStock(stock),
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6A4C93).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.smart_toy,
                                        color: Color(0xFF6A4C93),
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          stock.name,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          stock.code,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Price
                            Expanded(
                              flex: 1,
                              child: Text(
                                stock.formattedPrice,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Change
                            Expanded(
                              flex: 1,
                              child: Text(
                                stock.formattedChange,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: stock.changeType == 'up' 
                                      ? Colors.red 
                                      : stock.changeType == 'down'
                                          ? Colors.blue
                                          : Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // Market Cap or Volume
                            Expanded(
                              flex: 1,
                              child: Text(
                                _selectedFilter == "코인" 
                                    ? stock.formattedVolume 
                                    : _selectedFilter == "관심"
                                        ? (stock.market == "UPBIT-CRYPTO" 
                                            ? stock.formattedVolume 
                                            : stock.formattedMarketCap)
                                        : stock.formattedMarketCap,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            // Favorite Heart Icon
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: GestureDetector(
                                onTap: () => _toggleFavorite(stock.code),
                                child: Icon(
                                  isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: isFavorite ? Colors.red : Colors.grey,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
