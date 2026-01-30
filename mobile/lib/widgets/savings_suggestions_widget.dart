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

  double _parseNum(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
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
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade500, Colors.green.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tiềm năng tiết kiệm/năm',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade100,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCurrency(_parseNum(_summary!['totalPotentialYearlySavings'])),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.savings,
                            size: 48,
                            color: Colors.green.shade200,
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

                  // Footer
                  if (_summary != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey.shade100)),
                      ),
                      child: Center(
                        child: Text(
                          'Chi tiêu TB: ${_formatCurrency(_parseNum(_summary!['totalMonthlyExpense']))}/tháng',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                        ),
                      ),
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
  final dynamic recommendation;
  final String Function(num) formatCurrency;

  const _RecommendationItem({
    required this.recommendation,
    required this.formatCurrency,
  });

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final rec = recommendation as Map<String, dynamic>? ?? {};
    final category = rec['category'] as Map<String, dynamic>?;
    final categoryName = category?['name']?.toString() ?? rec['categoryName']?.toString() ?? 'Không xác định';
    final categoryIcon = category?['icon']?.toString() ?? '📦';
    final categoryColor = category?['color']?.toString() ?? '#9CA3AF';
    final currentSpending = _parseDouble(rec['currentMonthlySpending']);
    final suggestedReduction = _parseDouble(rec['suggestedReduction']);
    final potentialSavings = _parseDouble(rec['potentialYearlySavings']);
    final percentOfTotal = _parseDouble(rec['percentOfTotal']);
    final priority = _parseInt(rec['priority']);
    final tip = rec['tip']?.toString() ?? '';

    Color priorityColor;
    String priorityText;
    Color priorityBgColor;
    
    switch (priority) {
      case 1:
        priorityColor = Colors.red.shade700;
        priorityText = 'Ưu tiên cao';
        priorityBgColor = Colors.red.shade100;
        break;
      case 2:
        priorityColor = Colors.orange.shade700;
        priorityText = 'Quan trọng';
        priorityBgColor = Colors.orange.shade100;
        break;
      default:
        priorityColor = Colors.yellow.shade700;
        priorityText = 'Gợi ý';
        priorityBgColor = Colors.yellow.shade100;
    }

    // Parse color from hex
    Color parsedColor = Colors.grey;
    try {
      if (categoryColor.startsWith('#')) {
        parsedColor = Color(int.parse(categoryColor.substring(1), radix: 16) + 0xFF000000);
      }
    } catch (_) {}

    // Priority bar width
    final priorityBarWidth = ((4 - priority) / 3);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade100),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Category Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: parsedColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(categoryIcon, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              categoryName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: priorityBgColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              priorityText,
                              style: TextStyle(
                                fontSize: 10,
                                color: priorityColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      // Priority Bar
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: priorityBarWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: priorityColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Current Spending & Reduction
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hiện tại:', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      Text(
                        '${formatCurrency(currentSpending)}/tháng',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        'Chiếm ${percentOfTotal.toStringAsFixed(1)}% tổng chi tiêu',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trending_down, size: 14, color: Colors.green.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Giảm ${suggestedReduction.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tip
          if (tip.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tip,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ),
            ),

          // Potential Savings
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tiết kiệm tiềm năng:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    '${formatCurrency(potentialSavings)}/năm',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
