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
                    // Income & Potential Savings Cards
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade50, Colors.blue.shade100],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Thu nhập/tháng', 
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCurrency(_summary!['monthlyIncome'] ?? 0),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.green.shade50, Colors.green.shade100],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tiết kiệm tiềm năng', 
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCurrency(_summary!['potentialMonthlySavings'] ?? 0),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                Text(
                                  '${_formatCurrency((_summary!['potentialMonthlySavings'] ?? 0) * 12)}/năm',
                                  style: TextStyle(fontSize: 10, color: Colors.green.shade600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Needs Adjustment Alert
                    if ((_summary!['needsAdjustment'] ?? 0) > 0)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          border: Border.all(color: Colors.amber.shade200),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.auto_fix_high, size: 16, color: Colors.amber.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_summary!['needsAdjustment']} danh mục cần điều chỉnh',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 50/30/20 Progress Bar
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 50,
                              child: Container(color: Colors.blue.shade500),
                            ),
                            Expanded(
                              flex: 30,
                              child: Container(color: Colors.orange.shade500),
                            ),
                            Expanded(
                              flex: 20,
                              child: Container(color: Colors.green.shade500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _LegendItem(color: Colors.blue, label: '50% Thiết yếu'),
                        _LegendItem(color: Colors.orange, label: '30% Mong muốn'),
                        _LegendItem(color: Colors.green, label: '20% Tiết kiệm'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 50/30/20 Amounts
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
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
  final dynamic suggestion;
  final String Function(num) formatCurrency;

  const _SuggestionItem({
    required this.suggestion,
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
    final s = suggestion as Map<String, dynamic>? ?? {};
    final categoryName = s['categoryName']?.toString() ?? 'Không xác định';
    final categoryIcon = s['categoryIcon']?.toString() ?? '📝';
    final categoryColor = s['categoryColor']?.toString() ?? '#9CA3AF';
    final currentAvg = _parseDouble(s['currentMonthlyAvg']);
    final suggestedBudget = _parseDouble(s['suggestedBudget']);
    final percentOfIncome = _parseDouble(s['percentOfIncome']);
    final benchmarkIdeal = _parseDouble(s['benchmarkIdeal']);
    final potentialSavings = _parseDouble(s['potentialMonthlySavings']);
    final recommendation = s['recommendation']?.toString() ?? 'maintain';
    final reason = s['reason']?.toString() ?? '';
    final priority = s['priority'] ?? 3;

    Color recColor;
    IconData recIcon;
    String recText;
    Color borderColor;
    Color bgColor;
    
    switch (recommendation) {
      case 'reduce':
        recColor = Colors.red.shade600;
        recIcon = Icons.trending_down;
        recText = 'Nên giảm';
        borderColor = Colors.red.shade200;
        bgColor = Colors.red.shade50;
        break;
      case 'increase':
        recColor = Colors.blue.shade600;
        recIcon = Icons.trending_up;
        recText = 'Có thể tăng';
        borderColor = Colors.blue.shade200;
        bgColor = Colors.blue.shade50;
        break;
      default:
        recColor = Colors.green.shade600;
        recIcon = Icons.check;
        recText = 'Hợp lý';
        borderColor = Colors.green.shade200;
        bgColor = Colors.green.shade50;
    }

    String priorityText;
    Color priorityBgColor;
    Color priorityTextColor;
    
    switch (priority) {
      case 1:
        priorityText = 'Ưu tiên cao';
        priorityBgColor = Colors.red.shade100;
        priorityTextColor = Colors.red.shade700;
        break;
      case 2:
        priorityText = 'Quan trọng';
        priorityBgColor = Colors.orange.shade100;
        priorityTextColor = Colors.orange.shade700;
        break;
      default:
        priorityText = 'Gợi ý';
        priorityBgColor = Colors.blue.shade100;
        priorityTextColor = Colors.blue.shade700;
    }

    // Parse color from hex
    Color parsedColor = Colors.grey;
    try {
      if (categoryColor.startsWith('#')) {
        parsedColor = Color(int.parse(categoryColor.substring(1), radix: 16) + 0xFF000000);
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(12),
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: parsedColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(categoryIcon, style: const TextStyle(fontSize: 24)),
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
                                color: priorityTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Current vs Suggested
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hiện tại', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      const SizedBox(height: 2),
                      Text(
                        formatCurrency(currentAvg),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        '${percentOfIncome.toStringAsFixed(1)}% thu nhập',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, size: 16, color: Colors.grey.shade300),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gợi ý', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      const SizedBox(height: 2),
                      Text(
                        formatCurrency(suggestedBudget),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: recColor,
                        ),
                      ),
                      Text(
                        '~${benchmarkIdeal.toStringAsFixed(0)}% lý tưởng',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Reason
          if (reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reason,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ),
            ),

          // Savings Potential
          if (potentialSavings > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tiết kiệm được:',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${formatCurrency(potentialSavings)}/tháng',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade600,
                          ),
                        ),
                        Text(
                          '${formatCurrency(potentialSavings * 12)}/năm',
                          style: TextStyle(fontSize: 10, color: Colors.green.shade500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Action Badge
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(recIcon, size: 14, color: recColor),
                  const SizedBox(width: 4),
                  Text(
                    recText,
                    style: TextStyle(
                      fontSize: 12,
                      color: recColor,
                      fontWeight: FontWeight.bold,
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
