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

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return 'Không rõ';
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatDateTime(String? value) {
    if (value == null || value.isEmpty) return 'Không rõ';
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return DateFormat('dd/MM/yyyy · HH:mm').format(date.toLocal());
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
                formatDate: _formatDate,
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
  final String Function(String?) formatDate;
  final VoidCallback onRefresh;

  const _TransactionCard({
    required this.transaction,
    required this.formatCurrency,
    required this.formatDate,
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
    final ocrData = t['ocr_data'] as Map<String, dynamic>?;
    final hasReceipt = ocrData != null;

    // Lấy giờ từ created_at (TIMESTAMPTZ)
    final createdAt = DateTime.tryParse(t['created_at']?.toString() ?? '');
    final timeStr = createdAt != null
        ? DateFormat('HH:mm').format(createdAt.toLocal())
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showTransactionDetails(context, t),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
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
            ? Row(
                children: [
                  if (hasReceipt) ...[
                    Icon(Icons.receipt_long, size: 14, color: Colors.teal.shade700),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
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
            if (timeStr != null)
              Text(
                timeStr,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, Map<String, dynamic> transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TransactionDetailSheet(
        transaction: transaction,
        formatCurrency: formatCurrency,
        formatDate: formatDate,
      ),
    );
  }
}

class _TransactionDetailSheet extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final String Function(num) formatCurrency;
  final String Function(String?) formatDate;

  const _TransactionDetailSheet({
    required this.transaction,
    required this.formatCurrency,
    required this.formatDate,
  });

  Map<String, dynamic> get _ocrData {
    final data = transaction['ocr_data'];
    return data is Map<String, dynamic> ? data : {};
  }

  Map<String, dynamic> get _aiAnalysis {
    final data = _ocrData['aiAnalysis'];
    return data is Map<String, dynamic> ? data : {};
  }

  List<dynamic> get _receiptItems {
    final receiptItems = _ocrData['receiptItems'];
    final aiItems = _aiAnalysis['items'];
    final extractedItems = _ocrData['extractedItems'];

    if (receiptItems is List && receiptItems.isNotEmpty) return receiptItems;
    if (aiItems is List && aiItems.isNotEmpty) return aiItems;
    if (extractedItems is List) {
      return extractedItems.map((name) => {'name': name, 'quantity': 1}).toList();
    }
    return [];
  }

  String? _stringValue(List<String> keys) {
    for (final key in keys) {
      final value = _ocrData[key] ?? _aiAnalysis[key] ?? transaction[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  num _numValue(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      return num.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  String _formatDateWithTime(String? dateStr, String? createdAtStr) {
    final date = DateTime.tryParse(dateStr ?? '');
    final createdAt = DateTime.tryParse(createdAtStr ?? '');
    final formattedDate = date != null
        ? DateFormat('dd/MM/yyyy').format(date)
        : (dateStr ?? 'Không rõ');
    if (createdAt != null) {
      final timeStr = DateFormat('HH:mm').format(createdAt.toLocal());
      return '$formattedDate · $timeStr';
    }
    return formattedDate;
  }

  @override
  Widget build(BuildContext context) {
    final category = transaction['categories'] as Map<String, dynamic>?;
    final isExpense = transaction['type'] == 'expense';
    final amount = _numValue(transaction['amount']);
    final items = _receiptItems;
    final storeName = _stringValue(['storeName', 'rawText']) ?? 'Giao dịch';
    final invoiceNumber = _stringValue(['invoiceNumber']);
    final receiptDate = _stringValue(['receiptDate', 'date', 'transaction_date']);
    final receiptTime = _stringValue(['receiptTime', 'time']);
    final totalAmount = _numValue(_ocrData['totalAmount'] ?? _aiAnalysis['totalAmount'] ?? amount);
    final hasReceipt = _ocrData.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: hasReceipt ? Colors.teal.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      hasReceipt ? Icons.receipt_long : Icons.payments_outlined,
                      color: hasReceipt ? Colors.teal.shade700 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasReceipt ? storeName : (category?['name'] ?? 'Giao dịch'),
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasReceipt
                              ? 'Chi tiết hóa đơn đã quét'
                              : (transaction['description']?.toString() ?? ''),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isExpense ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _DetailMetric(
                        label: 'Số tiền',
                        value: '${isExpense ? '-' : '+'}${formatCurrency(amount)}',
                        color: isExpense ? Colors.red.shade700 : Colors.green.shade700,
                      ),
                    ),
                    Expanded(
                      child: _DetailMetric(
                        label: 'Danh mục',
                        value: category?['name']?.toString() ?? 'Không xác định',
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _InfoPanel(
                rows: [
                  _InfoRowData('Ngày giao dịch', _formatDateWithTime(
                    transaction['transaction_date']?.toString(),
                    transaction['created_at']?.toString(),
                  )),
                  if (hasReceipt) _InfoRowData('Ngày trên hóa đơn', '${formatDate(receiptDate)}${receiptTime != null ? ' $receiptTime' : ''}'),
                  if (invoiceNumber != null) _InfoRowData('Mã hóa đơn', invoiceNumber),
                  if (hasReceipt) _InfoRowData('Tổng hóa đơn', formatCurrency(totalAmount)),
                  if ((transaction['description']?.toString() ?? '').isNotEmpty)
                    _InfoRowData('Mô tả', transaction['description'].toString()),
                ],
              ),
              const SizedBox(height: 18),
              if (hasReceipt) ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Sản phẩm trong hóa đơn',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${items.length} mục',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Giao dịch này có dữ liệu OCR nhưng chưa lưu danh sách sản phẩm chi tiết.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  )
                else
                  ...items.map((item) => _ReceiptItemTile(
                        item: item,
                        formatCurrency: formatCurrency,
                      )),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DetailMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool alignEnd;

  const _DetailMetric({
    required this.label,
    required this.value,
    this.color,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: color ?? Colors.grey.shade900,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _InfoRowData {
  final String label;
  final String value;

  const _InfoRowData(this.label, this.value);
}

class _InfoPanel extends StatelessWidget {
  final List<_InfoRowData> rows;

  const _InfoPanel({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 116,
                  child: Text(
                    row.label,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ReceiptItemTile extends StatelessWidget {
  final dynamic item;
  final String Function(num) formatCurrency;

  const _ReceiptItemTile({
    required this.item,
    required this.formatCurrency,
  });

  num _numValue(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      return num.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final data = item is Map<String, dynamic> ? item as Map<String, dynamic> : {'name': item.toString()};
    final name = data['name']?.toString() ?? 'Sản phẩm';
    final quantity = _numValue(data['quantity'] ?? 1);
    final total = _numValue(data['total'] ?? data['unitPrice']);
    final unitPrice = _numValue(data['unitPrice']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.shopping_bag_outlined, color: Colors.teal.shade700, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  unitPrice > 0
                      ? 'SL: ${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)} x ${formatCurrency(unitPrice)}'
                      : 'SL: ${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            total > 0 ? formatCurrency(total) : '',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
