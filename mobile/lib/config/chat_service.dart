import 'package:dio/dio.dart';
import 'env.dart';

class ChatService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: Env.apiUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  static String? _conversationId;

  /// Gửi tin nhắn và nhận phản hồi từ AI
  static Future<String> sendMessage(String message, {String? authToken}) async {
    try {
      final headers = <String, String>{};
      if (authToken != null) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await _dio.post(
        '/chat',
        data: {
          'message': message,
          'conversationId': _conversationId,
        },
        options: Options(headers: headers),
      );

      if (response.data['success'] == true) {
        _conversationId = response.data['data']['conversationId'];
        return response.data['data']['message'];
      } else {
        throw Exception(response.data['error'] ?? 'Unknown error');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return 'API key không hợp lệ. Vui lòng kiểm tra cấu hình.';
      } else if (e.response?.statusCode == 429) {
        return 'Đã vượt quá giới hạn. Vui lòng thử lại sau.';
      }
      return 'Lỗi kết nối: ${e.message}';
    } catch (e) {
      return 'Có lỗi xảy ra: $e';
    }
  }

  /// Xóa history conversation
  static Future<void> clearHistory() async {
    try {
      await _dio.post('/chat/clear', data: {
        'conversationId': _conversationId,
      });
      _conversationId = null;
    } catch (e) {
      // Ignore errors
    }
  }
}
