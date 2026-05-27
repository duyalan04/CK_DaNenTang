import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Environment configuration với auto-discovery
class Env {
  // Supabase Configuration
  static const String supabaseUrl = 'https://mvrqkaoceoxvrudkypqk.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_I2d0Pn0mj4Z-FJleyBCNFw_Yr6K3Yvi';
  
  static const int _port = 3000;
  static const String _apiUrlKey = 'custom_api_url';
  
  static String? _cachedApiUrl;
  
  /// URL mặc định cho web (không cần auto-discovery)
  static String get _defaultWebUrl => 'http://localhost:$_port/api';
  
  static String get apiUrl => _cachedApiUrl ?? _defaultWebUrl;
  
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
    
    // Nếu là web, dùng default URL và skip auto-discovery
    if (kIsWeb) {
      print('🌐 Running on Web - using default URL: $_defaultWebUrl');
      print('⚠️ Note: For web, backend must be accessible from browser');
      return;
    }
    
    // Tự động tìm server mới (chỉ cho mobile)
    print('🔍 Auto-discovering server...');
    final foundUrl = await autoDiscover();
    if (foundUrl != null) {
      print('✅ Found server: $foundUrl');
    } else {
      print('⚠️ No server found, will retry on API calls');
    }
  }
  
  /// Tự động tìm server trong mạng LAN (chỉ cho mobile)
  static Future<String?> autoDiscover() async {
    // Skip trên web
    if (kIsWeb) {
      return _defaultWebUrl;
    }
    
    // Lấy IP của thiết bị để biết subnet
    final deviceIps = await _getDeviceIps();
    
    final ipsToScan = <String>{};
    
    // Thêm các IP đặc biệt cho emulator/simulator
    if (Platform.isAndroid) {
      ipsToScan.add('10.0.2.2'); // Android Emulator host machine
    } else if (Platform.isIOS) {
      ipsToScan.add('localhost'); // iOS Simulator
      ipsToScan.add('127.0.0.1');
    }
    
    // Scan toàn bộ subnet của thiết bị (1-254)
    for (final deviceIp in deviceIps) {
      final parts = deviceIp.split('.');
      if (parts.length == 4) {
        final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
        print('🔍 Scanning subnet: $subnet.0/24');
        
        // Scan toàn bộ subnet (ưu tiên các IP phổ biến trước)
        final priorityIps = [1, 2, 100, 101, 102, 103, 104, 105, 150, 200];
        for (var i in priorityIps) {
          ipsToScan.add('$subnet.$i');
        }
        
        // Thêm các IP còn lại
        for (var i = 1; i <= 254; i++) {
          if (!priorityIps.contains(i)) {
            ipsToScan.add('$subnet.$i');
          }
        }
      }
    }
    
    print('📡 Scanning ${ipsToScan.length} IPs...');
    
    // Scan song song nhưng theo batch để không quá tải
    const batchSize = 20;
    final ipList = ipsToScan.toList();
    
    for (var i = 0; i < ipList.length; i += batchSize) {
      final batch = ipList.skip(i).take(batchSize);
      final results = await Future.wait(
        batch.map((ip) => _testIpWithResult(ip)),
      );
      
      for (final result in results) {
        if (result != null) {
          final apiUrl = 'http://$result:$_port/api';
          await _saveApiUrl(apiUrl);
          print('✅ Server found at: $result');
          return apiUrl;
        }
      }
      
      // Progress indicator
      if (i % 40 == 0 && i > 0) {
        print('   Scanned ${i}/${ipList.length} IPs...');
      }
    }
    
    return null;
  }
  
  /// Lấy danh sách IP của thiết bị (chỉ cho mobile)
  static Future<List<String>> _getDeviceIps() async {
    final ips = <String>[];
    try {
      // Skip trên web
      if (kIsWeb) {
        return ips;
      }
      
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
    if (kIsWeb) {
      print('🌐 Web mode - no reconnection needed');
      return true;
    }
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
