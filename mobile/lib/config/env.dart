import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Environment configuration với auto-discovery
class Env {
  // Supabase Configuration
  static const String supabaseUrl = 'https://gaprsacsrfrlvmdvagoj.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_uwsW7owDxtlfhpyANr-hxw_pi57JFcd';
  
  static const int _port = 3000;
  static const String _apiUrlKey = 'custom_api_url';
  
  static String? _cachedApiUrl;
  
  static String get apiUrl => _cachedApiUrl ?? 'http://localhost:$_port/api';
  
  /// Khởi tạo và tự động tìm server
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_apiUrlKey);
    
    // Thử URL đã lưu trước
    if (savedUrl != null) {
      final ip = Uri.tryParse(savedUrl)?.host;
      if (ip != null && await _testIp(ip)) {
        _cachedApiUrl = savedUrl;
        print('✅ Connected to saved server: $savedUrl');
        return;
      }
    }
    
    // Tự động tìm server mới
    print('🔍 Auto-discovering server...');
    final foundUrl = await autoDiscover();
    if (foundUrl != null) {
      print('✅ Found server: $foundUrl');
    } else {
      print('⚠️ No server found, will retry on API calls');
    }
  }
  
  /// Tự động tìm server trong mạng LAN
  static Future<String?> autoDiscover() async {
    // Lấy IP của thiết bị để biết subnet
    final deviceIps = await _getDeviceIps();
    
    final ipsToScan = <String>{};
    
    // Thêm các IP phổ biến cho emulator
    if (Platform.isAndroid) {
      ipsToScan.add('192.168.207.19'); // Android Emulator
    }
    
    // Scan subnet của thiết bị
    for (final deviceIp in deviceIps) {
      final parts = deviceIp.split('.');
      if (parts.length == 4) {
        final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
        // Thêm các IP phổ biến trong subnet (1-20, 100-110, 150-160, 200-210)
        for (var i in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 
                       100, 101, 102, 103, 104, 105,
                       150, 151, 152, 153, 154, 155,
                       200, 201, 202, 203, 204, 205]) {
          ipsToScan.add('$subnet.$i');
        }
      }
    }
    
    print('📡 Scanning ${ipsToScan.length} IPs...');
    
    // Scan song song để nhanh hơn
    final results = await Future.wait(
      ipsToScan.map((ip) => _testIpWithResult(ip)),
    );
    
    for (final result in results) {
      if (result != null) {
        final apiUrl = 'http://$result:$_port/api';
        await _saveApiUrl(apiUrl);
        return apiUrl;
      }
    }
    
    return null;
  }
  
  /// Lấy danh sách IP của thiết bị
  static Future<List<String>> _getDeviceIps() async {
    final ips = <String>[];
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && 
              !addr.isLoopback &&
              !addr.address.startsWith('127.')) {
            ips.add(addr.address);
          }
        }
      }
    } catch (e) {
      print('Error getting device IPs: $e');
    }
    return ips;
  }
  
  /// Test một IP có server không
  static Future<bool> _testIp(String ip) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(milliseconds: 500),
        receiveTimeout: const Duration(milliseconds: 500),
      ));
      final response = await dio.get('http://$ip:$_port/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
  
  /// Test IP và trả về IP nếu thành công
  static Future<String?> _testIpWithResult(String ip) async {
    if (await _testIp(ip)) {
      return ip;
    }
    return null;
  }
  
  /// Lưu API URL
  static Future<void> _saveApiUrl(String url) async {
    _cachedApiUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiUrlKey, url);
  }
  
  /// Force re-discover (gọi khi mất kết nối)
  static Future<bool> reconnect() async {
    _cachedApiUrl = null;
    final url = await autoDiscover();
    return url != null;
  }
  
  /// Lấy IP hiện tại
  static String? getCurrentIp() {
    if (_cachedApiUrl == null) return null;
    return Uri.tryParse(_cachedApiUrl!)?.host;
  }
}
