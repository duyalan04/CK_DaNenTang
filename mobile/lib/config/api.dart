import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';

class ApiService {
  late Dio _dio;
  bool _isReconnecting = false;
  
  // Cache để giảm request
  final Map<String, _CacheEntry> _cache = {};
  static const _cacheDuration = Duration(seconds: 30);

  ApiService() {
    _initDio();
  }

  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: Env.apiUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.baseUrl = Env.apiUrl;
        
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          print('✅ Token added: ${session.accessToken.substring(0, 20)}...');
        } else {
          print('❌ No session found! User not logged in?');
        }
        print('📡 Request: ${options.method} ${options.baseUrl}${options.path}');
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (_shouldReconnect(error) && !_isReconnecting) {
          _isReconnecting = true;
          
          final success = await Env.reconnect();
          _isReconnecting = false;
          
          if (success) {
            try {
              final opts = error.requestOptions;
              opts.baseUrl = Env.apiUrl;
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          }
        }
        
        return handler.next(error);
      },
    ));
  }

  bool _shouldReconnect(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
           error.type == DioExceptionType.connectionError ||
           error.type == DioExceptionType.receiveTimeout;
  }

  // Cache helper
  T? _getFromCache<T>(String key) {
    final entry = _cache[key];
    if (entry != null && DateTime.now().difference(entry.timestamp) < _cacheDuration) {
      return entry.data as T;
    }
    _cache.remove(key);
    return null;
  }

  void _setCache(String key, dynamic data) {
    _cache[key] = _CacheEntry(data: data, timestamp: DateTime.now());
  }

  void clearCache() {
    _cache.clear();
  }

  /// Helper để xử lý lỗi chung
  Future<T> _safeRequest<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Kết nối quá lâu. Kiểm tra backend đang chạy.');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw Exception('Không thể kết nối server.');
      }
      if (e.response?.statusCode == 401) {
        throw Exception('Phiên đăng nhập hết hạn.');
      }
      throw Exception(e.response?.data?['error'] ?? e.message ?? 'Lỗi không xác định');
    }
  }

  // ============ TRANSACTIONS ============
  Future<List<dynamic>> getTransactions({bool forceRefresh = false}) async {
    const cacheKey = 'transactions';
    if (!forceRefresh) {
      final cached = _getFromCache<List<dynamic>>(cacheKey);
      if (cached != null) return cached;
    }
    
    return _safeRequest(() async {
      final response = await _dio.get('/transactions');
      final data = response.data as List<dynamic>;
      _setCache(cacheKey, data);
      return data;
    });
  }

  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> data) async {
    clearCache(); // Clear cache khi tạo mới
    return _safeRequest(() async {
      final response = await _dio.post('/transactions', data: data);
      return response.data;
    });
  }

  // ============ CATEGORIES ============
  Future<List<dynamic>> getCategories({bool forceRefresh = false}) async {
    const cacheKey = 'categories';
    if (!forceRefresh) {
      final cached = _getFromCache<List<dynamic>>(cacheKey);
      if (cached != null) return cached;
    }
    
    return _safeRequest(() async {
      final response = await _dio.get('/categories');
      final data = response.data as List<dynamic>;
      _setCache(cacheKey, data);
      return data;
    });
  }

  // ============ OCR ============
  Future<Map<String, dynamic>> analyzeReceiptWithAI(String base64Image) async {
    return _safeRequest(() async {
      // Increase timeout for OCR (Gemini can be slow)
      final response = await _dio.post(
        '/ocr/analyze-base64',
        data: {
          'image': base64Image,
          'mimeType': 'image/jpeg'
        },
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return response.data;
    });
  }

  Future<Map<String, dynamic>> createFromOCR(Map<String, dynamic> data) async {
    clearCache();
    return _safeRequest(() async {
      final response = await _dio.post('/transactions/ocr', data: data);
      return response.data;
    });
  }

  // ============ REPORTS ============
  Future<Map<String, dynamic>> getSummary({bool forceRefresh = false}) async {
    const cacheKey = 'summary';
    if (!forceRefresh) {
      final cached = _getFromCache<Map<String, dynamic>>(cacheKey);
      if (cached != null) return cached;
    }
    
    return _safeRequest(() async {
      final response = await _dio.get('/reports/summary');
      final data = response.data as Map<String, dynamic>;
      _setCache(cacheKey, data);
      return data;
    });
  }

  Future<List<dynamic>> getByCategory({String type = 'expense'}) async {
    return _safeRequest(() async {
      final response = await _dio.get('/reports/by-category?type=$type');
      return response.data;
    });
  }

  Future<List<dynamic>> getMonthlyTrend({int months = 6}) async {
    return _safeRequest(() async {
      final response = await _dio.get('/reports/monthly-trend?months=$months');
      return response.data;
    });
  }

  Future<List<dynamic>> getBudgetStatus({required int year, required int month}) async {
    return _safeRequest(() async {
      final response = await _dio.get('/reports/budget-status?year=$year&month=$month');
      return response.data;
    });
  }

  // ============ BUDGETS ============
  Future<List<dynamic>> getBudgets({required int year, required int month}) async {
    return _safeRequest(() async {
      final response = await _dio.get('/budgets?year=$year&month=$month');
      return response.data;
    });
  }

  Future<Map<String, dynamic>> createBudget(Map<String, dynamic> data) async {
    return _safeRequest(() async {
      final response = await _dio.post('/budgets', data: data);
      return response.data;
    });
  }

  Future<Map<String, dynamic>> updateBudget(String id, Map<String, dynamic> data) async {
    return _safeRequest(() async {
      final response = await _dio.put('/budgets/$id', data: data);
      return response.data;
    });
  }

  Future<void> deleteBudget(String id) async {
    return _safeRequest(() async {
      await _dio.delete('/budgets/$id');
    });
  }

  // ============ PREDICTIONS ============
  Future<Map<String, dynamic>> getPrediction() async {
    return _safeRequest(() async {
      final response = await _dio.get('/predictions/next-month');
      return response.data;
    });
  }

  Future<List<dynamic>> getCategoryPredictions() async {
    return _safeRequest(() async {
      final response = await _dio.get('/predictions/by-category');
      return response.data;
    });
  }

  // ============ ANALYTICS ============
  Future<Map<String, dynamic>> getHealthScore() async {
    return _safeRequest(() async {
      final response = await _dio.get('/analytics/health-score');
      return response.data;
    });
  }

  Future<Map<String, dynamic>> getAnomalies() async {
    return _safeRequest(() async {
      final response = await _dio.get('/analytics/anomalies');
      return response.data;
    });
  }

  Future<Map<String, dynamic>> getInsights() async {
    return _safeRequest(() async {
      final response = await _dio.get('/analytics/insights');
      return response.data;
    });
  }

  Future<Map<String, dynamic>> getSavingsRecommendations() async {
    return _safeRequest(() async {
      final response = await _dio.get('/analytics/savings');
      return response.data;
    });
  }

  // ============ GOALS ============
  Future<Map<String, dynamic>> getGoals() async {
    return _safeRequest(() async {
      final response = await _dio.get('/goals');
      return response.data;
    });
  }

  Future<Map<String, dynamic>> createGoal(Map<String, dynamic> data) async {
    return _safeRequest(() async {
      final response = await _dio.post('/goals', data: data);
      return response.data;
    });
  }

  Future<Map<String, dynamic>> updateGoal(String id, Map<String, dynamic> data) async {
    return _safeRequest(() async {
      final response = await _dio.put('/goals/$id', data: data);
      return response.data;
    });
  }

  Future<void> deleteGoal(String id) async {
    return _safeRequest(() async {
      await _dio.delete('/goals/$id');
    });
  }

  Future<Map<String, dynamic>> contributeToGoal(String goalId, Map<String, dynamic> data) async {
    return _safeRequest(() async {
      final response = await _dio.post('/goals/$goalId/contribute', data: data);
      return response.data;
    });
  }

  Future<Map<String, dynamic>> getGoalSuggestions() async {
    return _safeRequest(() async {
      final response = await _dio.get('/goals/ai-suggestions');
      return response.data;
    });
  }

  // ============ RECURRING ============
  Future<Map<String, dynamic>> getRecurring() async {
    return _safeRequest(() async {
      final response = await _dio.get('/recurring');
      return response.data;
    });
  }

  Future<Map<String, dynamic>> createRecurring(Map<String, dynamic> data) async {
    return _safeRequest(() async {
      final response = await _dio.post('/recurring', data: data);
      return response.data;
    });
  }

  Future<Map<String, dynamic>> updateRecurring(String id, Map<String, dynamic> data) async {
    return _safeRequest(() async {
      final response = await _dio.put('/recurring/$id', data: data);
      return response.data;
    });
  }

  Future<void> deleteRecurring(String id) async {
    return _safeRequest(() async {
      await _dio.delete('/recurring/$id');
    });
  }

  Future<Map<String, dynamic>> getRecurringForecast() async {
    return _safeRequest(() async {
      final response = await _dio.get('/recurring/forecast');
      return response.data;
    });
  }

  // ============ SMART ANALYSIS ============
  Future<Map<String, dynamic>> getSmartAnalysis({String period = 'month'}) async {
    return _safeRequest(() async {
      final response = await _dio.get('/smart/analysis?period=$period');
      return response.data;
    });
  }

  Future<Map<String, dynamic>> getSpendingPatterns() async {
    return _safeRequest(() async {
      final response = await _dio.get('/smart/patterns');
      return response.data;
    });
  }

  Future<Map<String, dynamic>> getBudgetSuggestions() async {
    return _safeRequest(() async {
      final response = await _dio.get('/smart/budget-suggestions');
      return response.data;
    });
  }

  Future<Map<String, dynamic>> getFinancialForecast({int months = 3}) async {
    return _safeRequest(() async {
      final response = await _dio.get('/smart/forecast?months=$months');
      return response.data;
    });
  }

  // ============ VOICE INPUT ============
  Future<Map<String, dynamic>> parseVoiceTransaction(String text) async {
    return _safeRequest(() async {
      final response = await _dio.post('/transactions/parse-voice', data: {'text': text});
      return response.data;
    });
  }

  // ============ SMS BANKING ============
  Future<List<dynamic>> parseBankingSms(List<Map<String, dynamic>> messages) async {
    return _safeRequest(() async {
      final response = await _dio.post('/transactions/parse-sms', data: {'messages': messages});
      return response.data;
    });
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  _CacheEntry({required this.data, required this.timestamp});
}

/// Global ApiService instance
final apiService = ApiService();
