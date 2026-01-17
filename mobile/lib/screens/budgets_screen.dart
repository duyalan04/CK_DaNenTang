import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/api.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  List<dynamic> _budgetStatus = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        apiService.getBudgetStatus(year: _selectedYear, month: _selectedMonth),
        apiService.getCategories(),
      ]);
      setState(() {
        _budgetStatus = results[0] as List<dynamic>;
        _categories = (results[1] as List<dynamic>).where((c) => c['type'] == 'expense').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(value);
  }

  void _showAddBudgetDialog() {
    String? selectedCategoryId;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm ngân sách'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Danh mục'),
              items: _categories.map<DropdownMenuItem<String>>((c) {
                return DropdownMenuItem(value: c['id'], child: Text(c['name']));
              }).toList(),
              onChanged: (value) => selectedCategoryId = value,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Số tiền ngân sách'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              if (selectedCategoryId != null && amountController.text.isNotEmpty) {
                try {
                  await apiService.createBudget({
                    'categoryId': selectedCategoryId,
                    'amount': double.parse(amountController.text),
                    'month': _selectedMonth,
                    'year': _selectedYear,
                  });
                  if (mounted) Navigator.pop(context);
                  _loadData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ngân sách'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddBudgetDialog),
        ],
      ),
      body: Column(
        children: [
          // Month/Year Selector
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Tháng',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: List.generate(12, (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('Tháng ${i + 1}'),
                    )),
                    onChanged: (value) {
                      setState(() => _selectedMonth = value!);
                      _loadData();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Năm',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [2024, 2025, 2026].map((y) => DropdownMenuItem(
                      value: y,
                      child: Text('$y'),
                    )).toList(),
                    onChanged: (value) {
                      setState(() => _selectedYear = value!);
                      _loadData();
                    },
                  ),
                ),
              ],
            ),
          ),
          // Budget List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _budgetStatus.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _budgetStatus.length,
                          itemBuilder: (context, index) => _BudgetCard(
                            budget: _budgetStatus[index],
                            formatCurrency: _formatCurrency,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('Chưa có ngân sách nào', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _showAddBudgetDialog,
            icon: const Icon(Icons.add),
            label: const Text('Thêm ngân sách'),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final dynamic budget;
  final String Function(num) formatCurrency;

  const _BudgetCard({required this.budget, required this.formatCurrency});

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final b = budget as Map<String, dynamic>? ?? {};
    final category = b['categories'] as Map<String, dynamic>?;
    final spent = _parseDouble(b['spent']);
    final amount = _parseDouble(b['amount']);
    final percentage = _parseDouble(b['percentage']);
    final remaining = _parseDouble(b['remaining']);
    final colorHex = category?['color']?.toString() ?? '#808080';
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

    Color progressColor;
    if (percentage > 100) {
      progressColor = Colors.red;
    } else if (percentage > 80) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  category?['name'] ?? 'Không xác định',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: progressColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: TextStyle(color: progressColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (percentage / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(progressColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đã chi', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Text(formatCurrency(spent), style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Ngân sách', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Text(formatCurrency(amount), style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Còn lại', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Text(
                      formatCurrency(remaining),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: remaining < 0 ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
