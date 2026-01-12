import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(baseUrl: Env.apiUrl));

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
        return handler.next(options);
      },
    ));
  }

  Future<List<dynamic>> getTransactions() async {
    final response = await _dio.get('/transactions');
    return response.data;
  }

  Future<List<dynamic>> getCategories() async {
    final response = await _dio.get('/categories');
    return response.data;
  }

  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> data) async {
    final response = await _dio.post('/transactions', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> analyzeReceiptWithAI(String base64Image) async {
    final response = await _dio.post('/ocr/analyze-base64', data: {
      'image': base64Image,
      'mimeType': 'image/jpeg'
    });
    return response.data;
  }

  Future<Map<String, dynamic>> createFromOCR(Map<String, dynamic> data) async {
    final response = await _dio.post('/transactions/ocr', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> getSummary() async {
    final response = await _dio.get('/reports/summary');
    return response.data;
  }
}

final apiService = ApiService();
