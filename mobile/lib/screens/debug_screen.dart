import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import '../config/env.dart';
import '../config/api.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String _status = 'Checking...';
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() {
      _isChecking = true;
      _status = '';
    });

    final buffer = StringBuffer();

    // 1. Check API URL
    buffer.writeln('📡 API URL: ${Env.apiUrl}');
    buffer.writeln('🌐 Current IP: ${Env.getCurrentIp() ?? "Not set"}');
    buffer.writeln('');

    // 2. Check Supabase
    buffer.writeln('🔐 Supabase URL: ${Env.supabaseUrl}');
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      buffer.writeln('✅ User logged in');
      buffer.writeln('   Email: ${session.user.email}');
      buffer.writeln('   Token: ${session.accessToken.substring(0, 30)}...');
      buffer.writeln('   Expires: ${session.expiresAt}');
    } else {
      buffer.writeln('❌ No session - User NOT logged in!');
    }
    buffer.writeln('');

    // 3. Test backend connection
    buffer.writeln('🔍 Testing backend connection...');
    try {
      final dio = Dio(BaseOptions(
        baseUrl: Env.apiUrl,
        connectTimeout: const Duration(seconds: 5),
      ));
      final response = await dio.get('/health');
      if (response.statusCode == 200) {
        buffer.writeln('✅ Backend reachable');
        buffer.writeln('   Response: ${response.data}');
      } else {
        buffer.writeln('⚠️ Backend returned ${response.statusCode}');
      }
    } catch (e) {
      buffer.writeln('❌ Backend NOT reachable');
      buffer.writeln('   Error: $e');
    }
    buffer.writeln('');

    // 4. Test authenticated endpoint
    if (session != null) {
      buffer.writeln('🔍 Testing authenticated endpoint...');
      try {
        final summary = await apiService.getSummary();
        buffer.writeln('✅ API call successful');
        buffer.writeln('   Balance: ${summary['balance']}');
      } catch (e) {
        buffer.writeln('❌ API call failed');
        buffer.writeln('   Error: $e');
      }
    }

    setState(() {
      _status = buffer.toString();
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Info'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkStatus,
          ),
        ],
      ),
      body: _isChecking
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      _status,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Quick actions
                  const Text('Quick Actions:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Env.reconnect();
                      _checkStatus();
                    },
                    icon: const Icon(Icons.wifi_find),
                    label: const Text('Re-discover Server'),
                  ),
                  const SizedBox(height: 8),
                  
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      _checkStatus();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
            ),
    );
  }
}
