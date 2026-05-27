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

      if (!mounted) return;
      setState(() {
        _budgetStatus = results[0];
        _categories = results[1]
            .where((c) => c['type'] == 'expense')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    ).format(value);
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, double> get _summary {
    final totalBudget = _budgetStatus.fold<double>(
      0,
      (sum, item) => sum + _parseDouble(item['amount']),
    );
    final totalSpent = _budgetStatus.fold<double>(
      0,
      (sum, item) => sum + _parseDouble(item['spent']),
    );
    final remaining = totalBudget - totalSpent;
    final usage = totalBudget > 0 ? (totalSpent / totalBudget * 100) : 0.0;
    final needAttention = _budgetStatus.where((item) {
      final percentage = _parseDouble(item['percentage']);
      final itemRemaining = _parseDouble(item['remaining']);
      return percentage >= 80 || itemRemaining < 0;
    }).length.toDouble();

    return {
      'budget': totalBudget,
      'spent': totalSpent,
      'remaining': remaining,
      'usage': usage,
      'attention': needAttention,
    };
  }

  Future<void> _showBudgetSheet({Map<String, dynamic>? budget}) async {
    final shouldReload = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BudgetFormSheet(
        budget: budget,
        categories: _categories,
        month: _selectedMonth,
        year: _selectedYear,
        formatCurrency: _formatCurrency,
        parseDouble: _parseDouble,
      ),
    );

    if (shouldReload == true && mounted) {
      _loadData();
    }
  }

  Future<void> _deleteBudget(Map<String, dynamic> budget) async {
    final category = budget['categories'] as Map<String, dynamic>?;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa ngân sách?'),
          content: Text(
            'Bạn muốn xóa ngân sách ${category?['name'] ?? 'này'} trong tháng $_selectedMonth/$_selectedYear?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await apiService.deleteBudget(budget['id'].toString());
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Ngân sách',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showBudgetSheet(),
            tooltip: 'Thêm ngân sách',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _PeriodSelector(
                  selectedMonth: _selectedMonth,
                  selectedYear: _selectedYear,
                  onMonthChanged: (value) {
                    setState(() => _selectedMonth = value);
                    _loadData();
                  },
                  onYearChanged: (value) {
                    setState(() => _selectedYear = value);
                    _loadData();
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _SummaryPanel(
                  summary: _summary,
                  formatCurrency: _formatCurrency,
                  budgetCount: _budgetStatus.length,
                ),
              ),
            ),
            if (_isLoading)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.builder(
                  itemCount: 3,
                  itemBuilder: (context, index) => const _BudgetSkeleton(),
                ),
              )
            else if (_budgetStatus.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(colorScheme),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Danh mục ngân sách',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${_budgetStatus.length} mục',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.builder(
                  itemCount: _budgetStatus.length,
                  itemBuilder: (context, index) => _BudgetCard(
                    budget: _budgetStatus[index] as Map<String, dynamic>,
                    formatCurrency: _formatCurrency,
                    onEdit: (budget) => _showBudgetSheet(budget: budget),
                    onDelete: _deleteBudget,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 34,
              color: Colors.teal.shade700,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Chưa có ngân sách tháng này',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Tạo hạn mức cho ăn uống, di chuyển hoặc mua sắm để theo dõi chi tiêu dễ hơn.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _showBudgetSheet(),
            icon: const Icon(Icons.add),
            label: const Text('Tạo ngân sách đầu tiên'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetFormSheet extends StatefulWidget {
  final Map<String, dynamic>? budget;
  final List<dynamic> categories;
  final int month;
  final int year;
  final String Function(num) formatCurrency;
  final double Function(dynamic) parseDouble;

  const _BudgetFormSheet({
    required this.budget,
    required this.categories,
    required this.month,
    required this.year,
    required this.formatCurrency,
    required this.parseDouble,
  });

  @override
  State<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<_BudgetFormSheet> {
  late final TextEditingController _amountController;
  String? _selectedCategoryId;
  bool _isSaving = false;

  bool get _isEditing => widget.budget != null;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.budget?['category_id']?.toString();
    _amountController = TextEditingController(
      text: _isEditing
          ? widget.parseDouble(widget.budget?['amount']).round().toString()
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.teal.shade700, width: 1.5),
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (_selectedCategoryId == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn danh mục và nhập số tiền hợp lệ')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        await apiService.updateBudget(
          widget.budget!['id'].toString(),
          {'amount': amount},
        );
      } else {
        await apiService.createBudget({
          'categoryId': _selectedCategoryId,
          'amount': amount,
          'month': widget.month,
          'year': widget.year,
        });
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomInset + 16,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing ? 'Chỉnh sửa ngân sách' : 'Thêm ngân sách',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tháng ${widget.month}/${widget.year}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isEditing)
              _LockedCategoryTile(budget: widget.budget!)
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId,
                decoration: _fieldDecoration(
                  label: 'Danh mục',
                  icon: Icons.category_outlined,
                ),
                items: widget.categories.map<DropdownMenuItem<String>>((c) {
                  return DropdownMenuItem(
                    value: c['id'].toString(),
                    child: Text(c['name']?.toString() ?? 'Danh mục'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedCategoryId = value);
                },
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              decoration: _fieldDecoration(
                label: 'Hạn mức ngân sách',
                icon: Icons.payments_outlined,
                hint: 'Ví dụ: 1000000',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 18),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _amountController,
              builder: (context, value, _) {
                final amount = double.tryParse(value.text) ?? 0;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Giá trị: ${widget.formatCurrency(amount)}',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: Icon(_isEditing ? Icons.save_outlined : Icons.add),
                label: Text(
                  _isSaving
                      ? 'Đang lưu...'
                      : _isEditing
                          ? 'Cập nhật'
                          : 'Lưu ngân sách',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final int selectedMonth;
  final int selectedYear;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;

  const _PeriodSelector({
    required this.selectedMonth,
    required this.selectedYear,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = List.generate(5, (index) => now.year - 2 + index);

    return Row(
      children: [
        Expanded(
          child: _FilterDropdown<int>(
            label: 'Tháng',
            value: selectedMonth,
            items: List.generate(12, (i) => i + 1),
            itemLabel: (value) => 'Tháng $value',
            onChanged: onMonthChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FilterDropdown<int>(
            label: 'Năm',
            value: selectedYear,
            items: years,
            itemLabel: (value) => '$value',
            onChanged: onYearChanged,
          ),
        ),
      ],
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.teal.shade700, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabel(item),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final Map<String, double> summary;
  final String Function(num) formatCurrency;
  final int budgetCount;

  const _SummaryPanel({
    required this.summary,
    required this.formatCurrency,
    required this.budgetCount,
  });

  @override
  Widget build(BuildContext context) {
    final totalBudget = summary['budget'] ?? 0;
    final spent = summary['spent'] ?? 0;
    final remaining = summary['remaining'] ?? 0;
    final usage = summary['usage'] ?? 0;
    final progress = (usage / 100).clamp(0.0, 1.0);
    final progressColor = remaining < 0
        ? Colors.red.shade600
        : usage >= 80
            ? Colors.orange.shade700
            : Colors.teal.shade700;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.insights_outlined,
                  color: Colors.teal.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng quan tháng',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '$budgetCount danh mục đang theo dõi',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${usage.round()}%',
                  style: TextStyle(
                    color: progressColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Ngân sách',
                  value: formatCurrency(totalBudget),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'Đã chi',
                  value: formatCurrency(spent),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'Còn lại',
                  value: formatCurrency(remaining),
                  valueColor:
                      remaining < 0 ? Colors.red.shade700 : Colors.green.shade700,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool alignEnd;

  const _SummaryMetric({
    required this.label,
    required this.value,
    this.valueColor,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.grey.shade900,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final Map<String, dynamic> budget;
  final String Function(num) formatCurrency;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;

  const _BudgetCard({
    required this.budget,
    required this.formatCurrency,
    required this.onEdit,
    required this.onDelete,
  });

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Color _parseColor(String? value) {
    try {
      return Color(int.parse((value ?? '#2563EB').replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = budget['categories'] as Map<String, dynamic>?;
    final spent = _parseDouble(budget['spent']);
    final amount = _parseDouble(budget['amount']);
    final percentage = amount > 0 ? (spent / amount * 100) : 0.0;
    final remaining = _parseDouble(budget['remaining']);
    final color = _parseColor(category?['color']?.toString());
    final statusColor = remaining < 0
        ? Colors.red.shade600
        : percentage >= 80
            ? Colors.orange.shade700
            : Colors.green.shade700;
    final statusLabel = remaining < 0
        ? 'Vượt mức'
        : percentage >= 80
            ? 'Cần chú ý'
            : 'An toàn';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category?['name']?.toString() ?? 'Không xác định',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit(budget);
                  if (value == 'delete') onDelete(budget);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Sửa'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Xóa', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (percentage / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation(statusColor),
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${percentage.round()}%',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BudgetMetric(
                  label: 'Đã chi',
                  value: formatCurrency(spent),
                ),
              ),
              Expanded(
                child: _BudgetMetric(
                  label: 'Ngân sách',
                  value: formatCurrency(amount),
                  center: true,
                ),
              ),
              Expanded(
                child: _BudgetMetric(
                  label: 'Còn lại',
                  value: formatCurrency(remaining),
                  alignEnd: true,
                  valueColor: remaining < 0
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool center;
  final bool alignEnd;

  const _BudgetMetric({
    required this.label,
    required this.value,
    this.valueColor,
    this.center = false,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = alignEnd
        ? CrossAxisAlignment.end
        : center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd
              ? Alignment.centerRight
              : center
                  ? Alignment.center
                  : Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.grey.shade900,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _LockedCategoryTile extends StatelessWidget {
  final Map<String, dynamic> budget;

  const _LockedCategoryTile({required this.budget});

  Color _parseColor(String? value) {
    try {
      return Color(int.parse((value ?? '#2563EB').replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = budget['categories'] as Map<String, dynamic>?;
    final color = _parseColor(category?['color']?.toString());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category?['name']?.toString() ?? 'Danh mục',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Icon(Icons.lock_outline, size: 18, color: Colors.grey.shade500),
        ],
      ),
    );
  }
}

class _BudgetSkeleton extends StatelessWidget {
  const _BudgetSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 156,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
