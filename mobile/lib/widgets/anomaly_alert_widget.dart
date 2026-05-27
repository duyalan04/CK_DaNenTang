import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/api.dart';

class AnomalyAlertWidget extends StatefulWidget {
  const AnomalyAlertWidget({super.key});

  @override
  State<AnomalyAlertWidget> createState() => _AnomalyAlertWidgetState();
}

class _AnomalyAlertWidgetState extends State<AnomalyAlertWidget> {
  List<dynamic> _anomalies = [];
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final result = await apiService.getAnomalies();
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _anomalies = result['data']?['anomalies'] ?? [];
          _statistics = result['data']?['statistics'];
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(value);
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text('Đang phân tích...', style: TextStyle(color: Colors.grey.shade600)),
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
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              const Expanded(child: Text('Không thể tải dữ liệu')),
              TextButton(onPressed: _loadData, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    if (_anomalies.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: Colors.green.shade400, size: 40),
              ),
              const SizedBox(height: 12),
              const Text('Không có giao dịch bất thường! 🎉',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Chi tiêu của bạn đang ổn định',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Phát hiện bất thường',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (_statistics != null) ...[
                  if ((_statistics!['highSeverity'] ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_statistics!['highSeverity']}',
                        style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Algorithm explanation
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Z-score: Phát hiện giao dịch khác biệt so với thói quen',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Anomaly List
            ...(_anomalies.take(3).map((anomaly) => _AnomalyItem(
                  anomaly: anomaly,
                  formatCurrency: _formatCurrency,
                  formatDate: _formatDate,
                ))),

            if (_anomalies.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: TextButton(
                    onPressed: () => _showAllAnomalies(context),
                    child: Text('Xem thêm ${_anomalies.length - 3} cảnh báo'),
                  ),
                ),
              ),

            // Footer
            if (_statistics != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Phân tích từ ${_statistics!['totalTransactions'] ?? 0} giao dịch',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAllAnomalies(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600),
                  const SizedBox(width: 8),
                  const Text('Tất cả cảnh báo bất thường',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _anomalies.length,
                itemBuilder: (context, index) => _AnomalyItem(
                  anomaly: _anomalies[index],
                  formatCurrency: _formatCurrency,
                  formatDate: _formatDate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnomalyItem extends StatelessWidget {
  final dynamic anomaly;
  final String Function(num) formatCurrency;
  final String Function(String) formatDate;

  const _AnomalyItem({
    required this.anomaly,
    required this.formatCurrency,
    required this.formatDate,
  });

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final a = anomaly as Map<String, dynamic>? ?? {};
    final severity = a['severity']?.toString() ?? 'low';
    final transaction = a['transaction'] as Map<String, dynamic>? ?? {};
    final zScore = a['z_score']?.toString() ?? '0';
    final description = a['description']?.toString() ?? '';

    Color bgColor;
    Color borderColor;
    Color iconColor;
    IconData icon;
    String severityText;

    switch (severity) {
      case 'high':
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade200;
        iconColor = Colors.red.shade600;
        icon = Icons.warning;
        severityText = 'Nghiêm trọng';
        break;
      case 'medium':
        bgColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade200;
        iconColor = Colors.orange.shade600;
        icon = Icons.error_outline;
        severityText = 'Trung bình';
        break;
      default:
        bgColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade200;
        iconColor = Colors.blue.shade600;
        icon = Icons.info_outline;
        severityText = 'Nhẹ';
    }

    final amount = _parseDouble(transaction['amount']);
    final type = transaction['type']?.toString() ?? 'expense';
    final categories = transaction['categories'] as Map<String, dynamic>? ?? {};
    final category = categories['name']?.toString() ?? 'Không xác định';
    final date = transaction['transaction_date']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        severityText,
                        style: TextStyle(fontSize: 10, color: iconColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Z: $zScore',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      type == 'expense' ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 16,
                      color: type == 'expense' ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatCurrency(amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: type == 'expense' ? Colors.red.shade700 : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(category, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  '${formatDate(date)} • $description',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
