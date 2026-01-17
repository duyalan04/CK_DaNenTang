import 'package:dio/dio.dart';
import 'env.dart';

class ChatResponse {
  final String message;
  final String? conversationId;
  final Map<String, dynamic>? transactionCreated;

  ChatResponse({
    required this.message,
    this.conversationId,
    this.transactionCreated,
  });

  bool get hasTransaction => transactionCreated != null;
}

class ChatService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: Env.apiUrl,
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 120),
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  static String? _conversationId;

  /// Gửi tin nhắn và nhận phản hồi từ AI
  static Future<ChatResponse> sendMessage(String message, {String? authToken}) async {
    try {
      // Cập nhật baseUrl mỗi lần gọi
      _dio.options.baseUrl = Env.apiUrl;
      
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
        return ChatResponse(
          message: response.data['data']['message'],
          conversationId: _conversationId,
          transactionCreated: response.data['data']['transactionCreated'],
        );
      } else {
        throw Exception(response.data['error'] ?? 'Unknown error');
      }
    } on DioException catch (e) {
      String errorMsg;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMsg = '⏱️ Kết nối quá lâu. Server có thể đang bận, vui lòng thử lại sau.';
      } else if (e.response?.statusCode == 401) {
        errorMsg = '🔑 API key không hợp lệ. Vui lòng kiểm tra cấu hình.';
      } else if (e.response?.statusCode == 429) {
        errorMsg = '⚠️ Đã vượt quá giới hạn request. Vui lòng thử lại sau ít phút.';
      } else if (e.response?.statusCode == 500) {
        errorMsg = '❌ Lỗi server. Vui lòng thử lại sau.';
      } else {
        errorMsg = '🔌 Lỗi kết nối: Không thể kết nối đến server.';
      }
      return ChatResponse(message: errorMsg);
    } catch (e) {
      return ChatResponse(message: '❌ Có lỗi xảy ra: $e');
    }
  }

  /// Xóa history conversation
  static Future<void> clearHistory() async {
    try {
      _dio.options.baseUrl = Env.apiUrl;
      await _dio.post('/chat/clear', data: {
        'conversationId': _conversationId,
      });
    } catch (e) {
      // Ignore errors
    }
    _conversationId = null;
  }

  static String? get conversationId => _conversationId;
}
