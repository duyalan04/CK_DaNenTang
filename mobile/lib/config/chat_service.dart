import 'package:dio/dio.dart';
import 'env.dart';

class ChatService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: Env.apiUrl,
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 120), // Tăng timeout cho AI response
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
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return '⏱️ Kết nối quá lâu. Server có thể đang bận, vui lòng thử lại sau.';
      }
      if (e.response?.statusCode == 401) {
        return '🔑 API key không hợp lệ. Vui lòng kiểm tra cấu hình.';
      } else if (e.response?.statusCode == 429) {
        return '⚠️ Đã vượt quá giới hạn request. Vui lòng thử lại sau ít phút.';
      } else if (e.response?.statusCode == 500) {
        return '❌ Lỗi server. Vui lòng thử lại sau.';
      }
      return '🔌 Lỗi kết nối: Không thể kết nối đến server. Kiểm tra kết nối mạng.';
    } catch (e) {
      return '❌ Có lỗi xảy ra: $e';
    }
  }

  /// Xóa history conversation
  static Future<void> clearHistory() async {
    try {
      await _dio.post('/chat/clear', data: {
        'conversationId': _conversationId,
      });
    } catch (e) {
      // Ignore errors
    }
    _conversationId = null;
  }

  /// Lấy conversation ID hiện tại
  static String? get conversationId => _conversationId;
}
