import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:insign/data/stock_repository.dart';
import 'package:insign/models/stock.dart';
import 'package:insign/features/auth/cubit/auth_cubit.dart';

class StockCubit extends Cubit<StockState> {
  final StockRepository _stockRepository;
  final AuthCubit _authCubit;

  StockCubit(this._stockRepository, this._authCubit) : super(const StockState());

  // 현재 로그인한 사용자 이메일 가져오기
  String? get _currentUserEmail => _authCubit.currentUser?.email;

  Future<void> loadStocksByMarket(String market, {bool reset = true}) async {
    if (reset) {
      emit(state.copyWith(
        isLoading: true, 
        currentPage: 1,
        hasMoreData: true,
      ));
    } else {
      emit(state.copyWith(isLoadingMore: true));
    }
    
    try {
      final stocks = await _stockRepository.getStocksByMarket(
        market, 
        page: reset ? 1 : state.currentPage,
      );
      
      final updatedStocks = reset 
          ? stocks 
          : [...state.stocks, ...stocks];
      
      emit(state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        stocks: updatedStocks,
        currentPage: reset ? 1 : state.currentPage + 1,
        hasMoreData: stocks.isNotEmpty,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> loadMoreStocks(String market) async {
    if (state.isLoadingMore || !state.hasMoreData) return;
    await loadStocksByMarket(market, reset: false);
  }

  Future<void> searchStocks(String query, {String market = 'ALL'}) async {
    if (query.isEmpty) {
      emit(state.copyWith(searchResults: []));
      return;
    }

    emit(state.copyWith(isSearching: true));
    
    try {
      final results = await _stockRepository.searchStocks(query: query, market: market);
      emit(state.copyWith(
        isSearching: false,
        searchResults: results,
        searchError: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSearching: false,
        searchError: e.toString(),
      ));
    }
  }

  void clearSearch() {
    emit(state.copyWith(searchResults: []));
  }

  // 관심종목 목록 로드
  Future<void> loadFavoriteStocks() async {
    final userEmail = _currentUserEmail;
    
    if (userEmail == null) {
      emit(state.copyWith(error: '로그인이 필요합니다'));
      return;
    }

    try {
      final favoriteStocks = await _stockRepository.getFavoriteStocks(userEmail);
      
      final favoriteStockCodes = favoriteStocks.map((stock) => stock.code).toSet();
      
      emit(state.copyWith(
        favoriteStocks: favoriteStocks,
        favoriteStockCodes: favoriteStockCodes,
      ));
    } catch (e) {
      print('Load Favorites Error: $e'); // 임시 디버그용
      emit(state.copyWith(error: e.toString()));
    }
  }

  // 관심종목 등록/해제
  Future<void> toggleFavorite(String stockCode) async {
    final userEmail = _currentUserEmail;
    
    if (userEmail == null) {
      emit(state.copyWith(error: '로그인이 필요합니다'));
      return;
    }

    try {
      // stockCode로 stockId 찾기
      final stock = _findStockByCode(stockCode);
      print('Toggle Favorite - Stock: ${stock?.name} (${stock?.code}), StockId: ${stock?.stockId}'); // 디버그용
      
      if (stock?.stockId == null) {
        emit(state.copyWith(error: '종목 정보에 stock_id가 없습니다 (코드: $stockCode)'));
        return;
      }

      final favorited = await _stockRepository.toggleFavorite(userEmail, stock!.stockId!);
      
      if (favorited) {
        // 관심종목 추가
        final updatedFavoriteStocks = List<Stock>.from(state.favoriteStocks)..add(stock);
        final updatedFavoriteCodes = Set<String>.from(state.favoriteStockCodes)..add(stockCode);
        
        emit(state.copyWith(
          favoriteStocks: updatedFavoriteStocks,
          favoriteStockCodes: updatedFavoriteCodes,
        ));
      } else {
        // 관심종목 제거
        final updatedFavoriteStocks = state.favoriteStocks.where((s) => s.code != stockCode).toList();
        final updatedFavoriteCodes = Set<String>.from(state.favoriteStockCodes)..remove(stockCode);
        
        emit(state.copyWith(
          favoriteStocks: updatedFavoriteStocks,
          favoriteStockCodes: updatedFavoriteCodes,
        ));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // stockCode로 Stock 객체 찾기
  Stock? _findStockByCode(String stockCode) {
    // 현재 로드된 stocks에서 찾기
    for (final stock in state.stocks) {
      if (stock.code == stockCode) return stock;
    }
    
    // 검색 결과에서 찾기
    for (final stock in state.searchResults) {
      if (stock.code == stockCode) return stock;
    }
    
    // 관심종목에서 찾기
    for (final stock in state.favoriteStocks) {
      if (stock.code == stockCode) return stock;
    }
    
    return null;
  }

  // 하위 호환성을 위해 getter 유지
  List<Stock> get favoriteStocks => state.favoriteStocks;
}

class StockState extends Equatable {
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSearching;
  final List<Stock> stocks;
  final List<Stock> searchResults;
  final List<Stock> favoriteStocks;
  final Set<String> favoriteStockCodes; // 빠른 조회용으로 유지
  final String? error;
  final String? searchError;
  final int currentPage;
  final bool hasMoreData;

  const StockState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSearching = false,
    this.stocks = const [],
    this.searchResults = const [],
    this.favoriteStocks = const [],
    this.favoriteStockCodes = const {},
    this.error,
    this.searchError,
    this.currentPage = 1,
    this.hasMoreData = true,
  });

  StockState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSearching,
    List<Stock>? stocks,
    List<Stock>? searchResults,
    List<Stock>? favoriteStocks,
    Set<String>? favoriteStockCodes,
    String? error,
    String? searchError,
    int? currentPage,
    bool? hasMoreData,
  }) {
    return StockState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSearching: isSearching ?? this.isSearching,
      stocks: stocks ?? this.stocks,
      searchResults: searchResults ?? this.searchResults,
      favoriteStocks: favoriteStocks ?? this.favoriteStocks,
      favoriteStockCodes: favoriteStockCodes ?? this.favoriteStockCodes,
      error: error,
      searchError: searchError,
      currentPage: currentPage ?? this.currentPage,
      hasMoreData: hasMoreData ?? this.hasMoreData,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isLoadingMore,
    isSearching,
    stocks,
    searchResults,
    favoriteStocks,
    favoriteStockCodes,
    error,
    searchError,
    currentPage,
    hasMoreData,
  ];
}