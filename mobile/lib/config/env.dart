import 'dart:io';
import 'package:dio/dio.dart';

/// Environment configuration
/// Tự động phát hiện môi trường và chọn API URL phù hợp
class Env {
  // Supabase Configuration
  static const String supabaseUrl = 'https://gaprsacsrfrlvmdvagoj.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_uwsW7owDxtlfhpyANr-hxw_pi57JFcd';
  
  // Port backend
  static const int _port = 3000;
  
  // Danh sách IP có thể kết nối (thử lần lượt)
  static const List<String> _possibleIPs = [
    '192.168.207.21',  // WiFi chính
    '10.0.0.199',      // Ethernet/WiFi khác
    '192.168.1.1',     // Router default
    '10.0.2.2',        // Android Emulator
    'localhost',       // iOS Simulator
  ];
  
  // Cache API URL đã tìm được
  static String? _cachedApiUrl;
  
  /// API URL mặc định (sẽ được cập nhật sau khi test)
  static String get apiUrl {
    if (_cachedApiUrl != null) return _cachedApiUrl!;
    
    // Mặc định dùng IP đầu tiên cho thiết bị thật
    if (Platform.isAndroid || Platform.isIOS) {
      return 'http://${_possibleIPs[0]}:$_port/api';
    }
    return 'http://localhost:$_port/api';
  }
  
  /// Tự động tìm API URL hoạt động
  static Future<String?> findWorkingApiUrl() async {
    if (_cachedApiUrl != null) return _cachedApiUrl;
    
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    ));
    
    for (final ip in _possibleIPs) {
      final testUrl = 'http://$ip:$_port/health';
      try {
        final response = await dio.get(testUrl);
        if (response.statusCode == 200) {
          _cachedApiUrl = 'http://$ip:$_port/api';
          print('✅ Found working API: $_cachedApiUrl');
          return _cachedApiUrl;
        }
      } catch (e) {
        print('❌ Failed to connect to $ip: $e');
      }
    }
    
    return null;
  }
  
  /// Cập nhật API URL thủ công
  static void setApiUrl(String url) {
    _cachedApiUrl = url;
  }
}
