import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/api.dart';

class SavingsSuggestionsWidget extends StatefulWidget {
  const SavingsSuggestionsWidget({super.key});

  @override
  State<SavingsSuggestionsWidget> createState() => _SavingsSuggestionsWidgetState();
}

class _SavingsSuggestionsWidgetState extends State<SavingsSuggestionsWidget> {
  List<dynamic> _recommendations = [];
  Map<String, dynamic>? _summary;
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
      final result = await apiService.getSavingsRecommendations();
      if (result['success'] == true) {
        setState(() {
          _recommendations = result['data']?['recommendations'] ?? [];
          _summary = result['data']?['summary'];
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

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.savings, color: Colors.green.shade600),
                const SizedBox(width: 8),
                const Text('Gợi ý tiết kiệm',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (!_isLoading)
                  IconButton(
                    icon: Icon(Icons.refresh, size: 20, color: Colors.grey.shade600),
                    onPressed: _loadData,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Content
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_hasError)
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(height: 8),
                    const Text('Không thể tải gợi ý'),
                    TextButton(onPressed: _loadData, child: const Text('Thử lại')),
                  ],
                ),
              )
            else if (_recommendations.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade400, size: 48),
                      const SizedBox(height: 8),
                      const Text('Chi tiêu của bạn đang hợp lý! 👍'),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  // Summary
                  if (_summary != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.trending_up, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Tiềm năng tiết kiệm: ${_formatCurrency(_summary!['totalPotentialYearlySavings'] ?? 0)}/năm',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Recommendations
                  ..._recommendations.take(3).map((rec) => _RecommendationItem(
                        recommendation: rec,
                        formatCurrency: _formatCurrency,
                      )),

                  if (_recommendations.length > 3)
                    TextButton(
                      onPressed: () => _showAllRecommendations(context),
                      child: Text('Xem thêm ${_recommendations.length - 3} gợi ý'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showAllRecommendations(BuildContext context) {
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
                  Icon(Icons.savings, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  const Text('Tất cả gợi ý tiết kiệm',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _recommendations.length,
                itemBuilder: (context, index) => _RecommendationItem(
                  recommendation: _recommendations[index],
                  formatCurrency: _formatCurrency,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationItem extends StatelessWidget {
  final Map<String, dynamic> recommendation;
  final String Function(num) formatCurrency;

  const _RecommendationItem({
    required this.recommendation,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final category = recommendation['category'];
    final categoryName = category?['name'] ?? recommendation['categoryName'] ?? 'Không xác định';
    final currentSpending = (recommendation['currentMonthlySpending'] ?? 0).toDouble();
    final suggestedReduction = (recommendation['suggestedReduction'] ?? 0).toDouble();
    final potentialSavings = (recommendation['potentialYearlySavings'] ?? 0).toDouble();
    final percentOfTotal = (recommendation['percentOfTotal'] ?? 0).toDouble();
    final priority = recommendation['priority'] ?? 3;
    final tip = recommendation['tip'] ?? '';

    Color priorityColor;
    String priorityText;
    switch (priority) {
      case 1:
        priorityColor = Colors.red;
        priorityText = 'Cao';
        break;
      case 2:
        priorityColor = Colors.orange;
        priorityText = 'Trung bình';
        break;
      default:
        priorityColor = Colors.blue;
        priorityText = 'Thấp';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  categoryName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  priorityText,
                  style: TextStyle(fontSize: 10, color: priorityColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hiện tại: ${formatCurrency(currentSpending)}/tháng',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    Text('Chiếm $percentOfTotal% tổng chi tiêu',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Giảm ${suggestedReduction.toStringAsFixed(0)}%',
                    style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Tiết kiệm ${formatCurrency(potentialSavings)}/năm',
                    style: TextStyle(fontSize: 11, color: Colors.green.shade600),
                  ),
                ],
              ),
            ],
          ),
          if (tip.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
