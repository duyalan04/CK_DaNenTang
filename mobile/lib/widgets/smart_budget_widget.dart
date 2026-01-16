import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/api.dart';

class SmartBudgetWidget extends StatefulWidget {
  const SmartBudgetWidget({super.key});

  @override
  State<SmartBudgetWidget> createState() => _SmartBudgetWidgetState();
}

class _SmartBudgetWidgetState extends State<SmartBudgetWidget> {
  List<dynamic> _suggestions = [];
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
      final result = await apiService.getBudgetSuggestions();
      if (result['success'] == true) {
        setState(() {
          _suggestions = result['data']?['suggestions'] ?? [];
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
                Icon(Icons.auto_fix_high, color: Colors.teal.shade600),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Gợi ý ngân sách thông minh',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (!_isLoading)
                  IconButton(
                    icon: Icon(Icons.refresh, size: 20, color: Colors.grey.shade600),
                    onPressed: _loadData,
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // 50/30/20 Rule Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Quy tắc 50/30/20',
                style: TextStyle(fontSize: 11, color: Colors.teal.shade700, fontWeight: FontWeight.w500),
              ),
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
            else
              Column(
                children: [
                  // Summary - 50/30/20 breakdown
                  if (_summary != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Thu nhập TB: ${_formatCurrency(_summary!['monthlyIncome'] ?? 0)}/tháng',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _BudgetRuleItem(
                                percent: '50%',
                                label: 'Thiết yếu',
                                amount: _formatCurrency(_summary!['essentials'] ?? 0),
                                color: Colors.blue,
                              ),
                              _BudgetRuleItem(
                                percent: '30%',
                                label: 'Mong muốn',
                                amount: _formatCurrency(_summary!['wants'] ?? 0),
                                color: Colors.orange,
                              ),
                              _BudgetRuleItem(
                                percent: '20%',
                                label: 'Tiết kiệm',
                                amount: _formatCurrency(_summary!['savings'] ?? 0),
                                color: Colors.green,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Category Suggestions
                  if (_suggestions.isNotEmpty) ...[
                    const Text('Gợi ý theo danh mục',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    ..._suggestions.take(5).map((s) => _SuggestionItem(
                          suggestion: s,
                          formatCurrency: _formatCurrency,
                        )),
                    if (_suggestions.length > 5)
                      TextButton(
                        onPressed: () => _showAllSuggestions(context),
                        child: Text('Xem thêm ${_suggestions.length - 5} danh mục'),
                      ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showAllSuggestions(BuildContext context) {
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
              child: const Text('Gợi ý ngân sách theo danh mục',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _suggestions.length,
                itemBuilder: (context, index) => _SuggestionItem(
                  suggestion: _suggestions[index],
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

class _BudgetRuleItem extends StatelessWidget {
  final String percent;
  final String label;
  final String amount;
  final Color color;

  const _BudgetRuleItem({
    required this.percent,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              percent,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          Text(amount, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _SuggestionItem extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final String Function(num) formatCurrency;

  const _SuggestionItem({
    required this.suggestion,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final categoryName = suggestion['categoryName'] ?? 'Không xác định';
    final currentAvg = (suggestion['currentMonthlyAvg'] ?? 0).toDouble();
    final suggestedBudget = (suggestion['suggestedBudget'] ?? 0).toDouble();
    final percentOfIncome = (suggestion['percentOfIncome'] ?? 0).toDouble();
    final recommendation = suggestion['recommendation'] ?? 'maintain';

    Color recColor;
    IconData recIcon;
    String recText;
    switch (recommendation) {
      case 'reduce':
        recColor = Colors.red;
        recIcon = Icons.arrow_downward;
        recText = 'Giảm';
        break;
      case 'increase':
        recColor = Colors.green;
        recIcon = Icons.arrow_upward;
        recText = 'Tăng';
        break;
      default:
        recColor = Colors.blue;
        recIcon = Icons.check;
        recText = 'Giữ';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(categoryName, style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  'Hiện tại: ${formatCurrency(currentAvg)} → Gợi ý: ${formatCurrency(suggestedBudget)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                Text(
                  'Chiếm $percentOfIncome% thu nhập',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: recColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(recIcon, size: 14, color: recColor),
                const SizedBox(width: 4),
                Text(recText, style: TextStyle(fontSize: 11, color: recColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
