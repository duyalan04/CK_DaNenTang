import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/api.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<dynamic> _transactions = [];
  List<dynamic> _filteredTransactions = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;
  String? _error;

  // Filters
  String _typeFilter = 'all'; // all, income, expense
  String? _categoryFilter;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        apiService.getTransactions(),
        apiService.getCategories(),
      ]);

      setState(() {
        _transactions = results[0] as List<dynamic>;
        _categories = results[1] as List<dynamic>;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    _filteredTransactions = _transactions.where((item) {
      final t = item as Map<String, dynamic>? ?? {};
      // Type filter
      if (_typeFilter != 'all' && t['type'] != _typeFilter) return false;

      // Category filter
      if (_categoryFilter != null && t['category_id'] != _categoryFilter) return false;

      // Date range filter
      if (_dateRange != null) {
        final date = DateTime.tryParse(t['transaction_date']?.toString() ?? '');
        if (date == null) return false;
        if (date.isBefore(_dateRange!.start) || date.isAfter(_dateRange!.end)) return false;
      }

      return true;
    }).toList();
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(value);
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _applyFilters();
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _typeFilter = 'all';
      _categoryFilter = null;
      _dateRange = null;
      _applyFilters();
    });
  }

  num get _totalIncome => _filteredTransactions
      .where((item) => (item as Map<String, dynamic>?)?['type'] == 'income')
      .fold<num>(0, (sum, item) => sum + ((item as Map<String, dynamic>?)?['amount'] as num? ?? 0));

  num get _totalExpense => _filteredTransactions
      .where((item) => (item as Map<String, dynamic>?)?['type'] == 'expense')
      .fold<num>(0, (sum, item) => sum + ((item as Map<String, dynamic>?)?['amount'] as num? ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tất cả giao dịch'),
        actions: [
          if (_typeFilter != 'all' || _categoryFilter != null || _dateRange != null)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Xóa bộ lọc',
              onPressed: _clearFilters,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : Column(
                  children: [
                    _buildFilterBar(),
                    _buildSummaryBar(),
                    Expanded(child: _buildTransactionList()),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Lỗi: $_error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: _loadData, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Type filter chips
            FilterChip(
              label: const Text('Tất cả'),
              selected: _typeFilter == 'all',
              onSelected: (_) => setState(() { _typeFilter = 'all'; _applyFilters(); }),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Thu nhập'),
              selected: _typeFilter == 'income',
              selectedColor: Colors.green.shade100,
              onSelected: (_) => setState(() { _typeFilter = 'income'; _applyFilters(); }),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Chi tiêu'),
              selected: _typeFilter == 'expense',
              selectedColor: Colors.red.shade100,
              onSelected: (_) => setState(() { _typeFilter = 'expense'; _applyFilters(); }),
            ),
            const SizedBox(width: 16),
            // Category dropdown
            PopupMenuButton<String?>(
              initialValue: _categoryFilter,
              onSelected: (value) => setState(() { _categoryFilter = value; _applyFilters(); }),
              itemBuilder: (context) => [
                const PopupMenuItem(value: null, child: Text('Tất cả danh mục')),
                ..._categories.map((c) => PopupMenuItem(
                  value: c['id'],
                  child: Text(c['name'] ?? ''),
                )),
              ],
              child: Chip(
                avatar: const Icon(Icons.category, size: 18),
                label: Text(_categoryFilter == null
                    ? 'Danh mục'
                    : _categories.firstWhere((c) => c['id'] == _categoryFilter, orElse: () => {'name': 'Danh mục'})['name']),
              ),
            ),
            const SizedBox(width: 8),
            // Date range
            ActionChip(
              avatar: const Icon(Icons.date_range, size: 18),
              label: Text(_dateRange == null
                  ? 'Chọn ngày'
                  : '${DateFormat('dd/MM').format(_dateRange!.start)} - ${DateFormat('dd/MM').format(_dateRange!.end)}'),
              onPressed: _selectDateRange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text('${_filteredTransactions.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Giao dịch', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          Column(
            children: [
              Text(_formatCurrency(_totalIncome), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
              Text('Thu nhập', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          Column(
            children: [
              Text(_formatCurrency(_totalExpense), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
              Text('Chi tiêu', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_filteredTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Không có giao dịch nào'),
            if (_typeFilter != 'all' || _categoryFilter != null || _dateRange != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: _clearFilters, child: const Text('Xóa bộ lọc')),
            ],
          ],
        ),
      );
    }

    // Group by date
    final grouped = <String, List<dynamic>>{};
    for (final t in _filteredTransactions) {
      final tMap = t as Map<String, dynamic>? ?? {};
      final date = tMap['transaction_date']?.toString().split('T')[0] ?? 'Không rõ';
      grouped.putIfAbsent(date, () => []).add(t);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final date = sortedDates[index];
          final transactions = grouped[date]!;
          final dateObj = DateTime.tryParse(date);
          final dateStr = dateObj != null ? DateFormat('EEEE, dd/MM/yyyy', 'vi').format(dateObj) : date;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(dateStr, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              ),
              ...transactions.map((t) => _TransactionCard(
                transaction: t,
                formatCurrency: _formatCurrency,
                onRefresh: _loadData,
              )),
            ],
          );
        },
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final dynamic transaction;
  final String Function(num) formatCurrency;
  final VoidCallback onRefresh;

  const _TransactionCard({
    required this.transaction,
    required this.formatCurrency,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final t = transaction as Map<String, dynamic>? ?? {};
    final isExpense = t['type'] == 'expense';
    final category = t['categories'] as Map<String, dynamic>?;
    final colorHex = category?['color']?.toString() ?? '#808080';
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    final amount = (t['amount'] ?? 0) as num;
    final description = t['description']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Text(
            category?['icon']?.toString() ?? (isExpense ? '💸' : '💰'),
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          category?['name']?.toString() ?? 'Không xác định',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: description.isNotEmpty
            ? Text(description, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isExpense ? '-' : '+'}${formatCurrency(amount)}',
              style: TextStyle(
                color: isExpense ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
