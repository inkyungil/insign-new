import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:insign/models/stock.dart';

class StockRepository {
  static const String baseUrl = 'https://propose9899.cafe24.com/adm/api/';
  
  Future<List<Stock>> searchStocks({
    required String query,
    String market = 'ALL',
    String queryType = 'name',
    String matchType = 'contains',
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}?pid=stocks'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'list',
          'market': market,
          'q': query,
          'q_type': queryType,
          'match': matchType,
          'page': page.toString(),
          'per_page': perPage.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // 실제 API 응답 구조: errCd, errMsg, data
        if (data['errCd'] == 200 && data['data'] != null && data['data']['items'] != null) {
          final List stocksJson = data['data']['items'] ?? [];
          // 첫 번째 종목의 stock_id 확인 (임시 디버그용)
          if (stocksJson.isNotEmpty) {
            print('Search API - First stock stock_id: ${stocksJson[0]['stock_id']}'); 
          }
          return stocksJson.map((json) => Stock.fromJson(json)).toList();
        }
      }
      
      return [];
    } catch (e) {
      throw Exception('종목 검색 실패: $e');
    }
  }

  Future<List<Stock>> getStocksByMarket(String market, {int page = 1}) async {
    try {
      print('Loading stocks for market: $market'); // 디버그용
      
      Map<String, String> requestBody;
      
      if (market == 'UPBIT-CRYPTO') {
        // 코인용 파라미터
        requestBody = {
          'action': 'list',
          'market': 'UPBIT-KRW',
          'sort': 'turnover_desc',
          'page': page.toString(),
          'per_page': '100',
        };
      } else {
        // 주식용 파라미터
        requestBody = {
          'action': 'list',
          'market': market,
          'q': '',
          'q_type': 'name',
          'match': 'contains',
          'page': page.toString(),
          'per_page': '100',
          'sort_by': 'market_cap',
          'sort_order': 'desc',
        };
      }
      
      final response = await http.post(
        Uri.parse('${baseUrl}?pid=stocks'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['errCd'] == 200 && data['data'] != null && data['data']['items'] != null) {
          final List stocksJson = data['data']['items'] ?? [];
          print('Market API Response - ${stocksJson.length} stocks loaded for market: $market'); // 디버그용
          // 첫 번째 종목의 stock_id 확인 (임시 디버그용)
          if (stocksJson.isNotEmpty) {
            print('Market API - First stock: ${stocksJson[0]['name']} (${stocksJson[0]['code']}), stock_id: ${stocksJson[0]['stock_id']}'); 
          }
          return stocksJson.map((json) => Stock.fromJson(json)).toList();
        }
      }
      
      return [];
    } catch (e) {
      throw Exception('시장별 종목 조회 실패: $e');
    }
  }

  // 관심종목 등록/해제
  Future<bool> toggleFavorite(String userEmail, int stockId) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}?pid=user_favorites'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'user_id': userEmail,
          'stock_id': stockId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Favorite Toggle Response: $data'); // 임시 디버그용
        
        if (data['errCd'] == 200 && data['data'] != null) {
          return data['data']['favorited'] ?? false;
        }
      }
      
      return false;
    } catch (e) {
      print('Favorite Toggle Error: $e'); // 임시 디버그용
      throw Exception('관심종목 등록/해제 실패: $e');
    }
  }

  // 관심종목 목록 조회
  Future<List<Stock>> getFavoriteStocks(String userEmail, {String type = 'ALL'}) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}?pid=user_favorites_list'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'user_id': userEmail,
          'type': type,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Favorite List Response: $data'); // 임시 디버그용
        
        if (data['errCd'] == 200 && data['data'] != null) {
          final List stocksJson = data['data'] ?? [];
          return stocksJson.map((json) => Stock.fromFavoriteJson(json)).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Favorite List Error: $e'); // 임시 디버그용
      throw Exception('관심종목 목록 조회 실패: $e');
    }
  }
}