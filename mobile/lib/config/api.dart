import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: Env.apiUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
        print('🌐 API Request: ${options.method} ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('✅ API Response: ${response.statusCode} ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (error, handler) {
        print('❌ API Error: ${error.type} - ${error.message}');
        print('   URL: ${error.requestOptions.uri}');
        return handler.next(error);
      },
    ));
  }

  /// Helper để xử lý lỗi chung
  Future<T> _safeRequest<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Kết nối quá lâu. Kiểm tra backend đang chạy và API URL đúng.');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw Exception('Không thể kết nối server. Kiểm tra:\n'
            '1. Backend đang chạy (npm run dev)\n'
            '2. API URL trong env.dart đúng IP\n'
            '3. Thiết bị và máy tính cùng mạng WiFi');
      }
      if (e.response?.statusCode == 401) {
        throw Exception('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      }
      throw Exception(e.response?.data?['error'] ?? e.message ?? 'Lỗi không xác định');
    }
  }

  // ============ TRANSACTIONS ============
  Future<List<dynamic>> getTransactions() async {
    return _safeRequest(() async {
      final response = await _dio.get('/transactions');
      return response.data;
    });
  }

  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> data) async {
    return _safeRequest(() async {
      final response = await _dio.post('/transactions', data: data);
      return response.data;
    });
  }

  // ============ CATEGORIES ============
  Future<List<dynamic>> getCategories() async {
    return _safeRequest(() async {
      final response = await _dio.get('/categories');
      return response.data;
    });
  }

  // ============ OCR ============
  Future<Map<String, dynamic>> analyzeReceiptWithAI(String base64Image) async {
    return _safeRequest(() async {
      final response = await _dio.post('/ocr/analyze-base64', data: {
        'image': base64Image,
        'mimeType': 'image/jpeg'
      });
      return response.data;
    });
  }

  Future<Map<String, dynamic>> createFromOCR(Map<String, dynamic> data) async {
    return _safeRequest(() async {
      final response = await _dio.post('/transactions/ocr', data: data);
      return response.data;
    });
  }

  // ============ REPORTS ============
  Future<Map<String, dynamic>> getSummary() async {
    return _safeRequest(() async {
      final response = await _dio.get('/reports/summary');
      return response.data;
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
}

final apiService = ApiService();
