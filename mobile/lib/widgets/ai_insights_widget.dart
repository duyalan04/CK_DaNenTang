import 'package:flutter/material.dart';
import '../config/api.dart';

class AIInsightsWidget extends StatefulWidget {
  const AIInsightsWidget({super.key});

  @override
  State<AIInsightsWidget> createState() => _AIInsightsWidgetState();
}

class _AIInsightsWidgetState extends State<AIInsightsWidget> {
  List<dynamic> _insights = [];
  Map<String, dynamic>? _basedOn;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final result = await apiService.getInsights();
      if (result['success'] == true) {
        setState(() {
          _insights = result['data']?['insights'] ?? [];
          _basedOn = result['data']?['basedOn'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.purple.shade600),
                const SizedBox(width: 8),
                const Text('AI Insights',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (!_isLoading)
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.purple.shade600, size: 20),
                    onPressed: _loadData,
                    tooltip: 'Làm mới',
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // AI Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_outline, size: 14, color: Colors.purple.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Phân tích bởi AI',
                    style: TextStyle(fontSize: 11, color: Colors.purple.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Content
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('AI đang phân tích...'),
                    ],
                  ),
                ),
              )
            else if (_hasError)
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(height: 8),
                    const Text('Không thể tải insights'),
                    TextButton(onPressed: _loadData, child: const Text('Thử lại')),
                  ],
                ),
              )
            else if (_insights.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Chưa có đủ dữ liệu để phân tích'),
                ),
              )
            else
              Column(
                children: [
                  ..._insights.map((insight) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                        ),
                        child: Text(
                          insight['content'] ?? insight.toString(),
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
                        ),
                      )),
                  if (_basedOn != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Dựa trên ${_basedOn!['transactionCount'] ?? 0} giao dịch trong ${_basedOn!['period'] ?? ''}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
