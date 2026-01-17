import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/api.dart';

class PredictionWidget extends StatefulWidget {
  const PredictionWidget({super.key});

  @override
  State<PredictionWidget> createState() => _PredictionWidgetState();
}

class _PredictionWidgetState extends State<PredictionWidget> {
  Map<String, dynamic>? _data;
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
      final result = await apiService.getPrediction();
      setState(() {
        _data = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(value);
  }

  String _getMonthName(int month) {
    const months = [
      '', 'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6',
      'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'
    ];
    return months[month];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Đang dự báo...', style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.orange.shade400, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Chưa đủ dữ liệu để dự báo', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      );
    }

    final prediction = _data?['prediction'];
    final confidence = _data?['confidence'] ?? 0;
    final month = _data?['month'] ?? DateTime.now().month + 1;
    final year = _data?['year'] ?? DateTime.now().year;
    final historicalData = _data?['historicalData'] as List<dynamic>?;

    if (prediction == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade400, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Cần ít nhất 3 tháng dữ liệu để dự báo',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.trending_up, color: Colors.purple.shade600, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dự báo chi tiêu',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(
                        '${_getMonthName(month)} $year',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                // Confidence badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: confidence >= 70
                        ? Colors.green.shade50
                        : confidence >= 50
                            ? Colors.orange.shade50
                            : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.analytics,
                        size: 14,
                        color: confidence >= 70
                            ? Colors.green.shade600
                            : confidence >= 50
                                ? Colors.orange.shade600
                                : Colors.red.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$confidence%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: confidence >= 70
                              ? Colors.green.shade600
                              : confidence >= 50
                                  ? Colors.orange.shade600
                                  : Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Prediction amount
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade400, Colors.purple.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Dự kiến chi tiêu',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(prediction),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Historical mini chart
            if (historicalData != null && historicalData.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Lịch sử chi tiêu',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: _MiniChart(
                  data: historicalData,
                  prediction: prediction.toDouble(),
                  formatCurrency: _formatCurrency,
                ),
              ),
            ],

            // Algorithm info
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.psychology, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Linear Regression từ ${historicalData?.length ?? 0} tháng dữ liệu',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChart extends StatelessWidget {
  final List<dynamic> data;
  final double prediction;
  final String Function(num) formatCurrency;

  const _MiniChart({
    required this.data,
    required this.prediction,
    required this.formatCurrency,
  });

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final amounts = data.map((d) {
      final item = d as Map<String, dynamic>? ?? {};
      return _parseDouble(item['amount']);
    }).toList();
    amounts.add(prediction);
    final maxAmount = amounts.reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ...data.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value as Map<String, dynamic>? ?? {};
          final amount = _parseDouble(item['amount']);
          final height = maxAmount > 0 ? (amount / maxAmount * 50) : 0.0;
          final month = (item['month'] ?? '').toString();
          final shortMonth = month.length > 5 ? month.substring(5) : month;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.purple.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shortMonth,
                    style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }),
        // Prediction bar
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: maxAmount > 0 ? (prediction / maxAmount * 50) : 0,
                  decoration: BoxDecoration(
                    color: Colors.purple.shade500,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.purple.shade700, width: 2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dự báo',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
