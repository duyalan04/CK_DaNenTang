import 'package:flutter/material.dart';
import '../config/api.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  List<dynamic> _recurringList = [];
  Map<String, dynamic>? _forecast;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await apiService.getRecurringForecast();
      setState(() {
        _recurringList = data['recurring'] ?? [];
        _forecast = data['forecast'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddRecurringSheet(onSaved: _loadData),
    );
  }

  Future<void> _deleteRecurring(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Xóa giao dịch định kỳ này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
        ],
      ),
    );
    
    if (confirm == true) {
      await apiService.deleteRecurring(id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao dịch định kỳ'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Forecast card
                  if (_forecast != null) _buildForecastCard(),
                  
                  const SizedBox(height: 20),
                  
                  // List header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Danh sách', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${_recurringList.length} mục', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Recurring list
                  if (_recurringList.isEmpty)
                    _buildEmptyState()
                  else
                    ..._recurringList.map((r) => _buildRecurringItem(r)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildForecastCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dự báo hàng tháng', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildForecastItem('Thu nhập', _forecast!['monthlyIncome'], Colors.green.shade300),
              _buildForecastItem('Chi tiêu', _forecast!['monthlyExpense'], Colors.red.shade300),
              _buildForecastItem('Còn lại', _forecast!['netMonthly'], Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForecastItem(String label, dynamic amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          _formatCurrency(amount),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.repeat, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Chưa có giao dịch định kỳ', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          const Text('Thêm tiền nhà, điện nước, lương...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRecurringItem(Map<String, dynamic> item) {
    final isExpense = item['type'] == 'expense';
    final category = item['categories'];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isExpense ? Colors.red.shade50 : Colors.green.shade50,
          child: Text(
            category?['icon'] ?? '📦',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(item['description'] ?? category?['name'] ?? 'Không tên'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getFrequencyText(item['frequency'], item['day_of_month'], item['day_of_week'])),
            Text('Tiếp theo: ${_formatDate(item['next_occurrence'])}', 
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isExpense ? "-" : "+"}${_formatCurrency(item['amount'])}',
              style: TextStyle(
                color: isExpense ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _deleteRecurring(item['id']),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  String _getFrequencyText(String? freq, int? dayOfMonth, int? dayOfWeek) {
    switch (freq) {
      case 'daily': return 'Hàng ngày';
      case 'weekly': 
        final days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
        return 'Hàng tuần (${days[dayOfWeek ?? 0]})';
      case 'monthly': return 'Hàng tháng (ngày ${dayOfMonth ?? 1})';
      case 'yearly': return 'Hàng năm';
      default: return freq ?? '';
    }
  }

  String _formatCurrency(dynamic amount) {
    double value;
    if (amount == null) {
      value = 0;
    } else if (amount is String) {
      value = double.tryParse(amount) ?? 0;
    } else if (amount is num) {
      value = amount.toDouble();
    } else {
      value = 0;
    }
    return '${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}đ';
  }

  String _formatDate(String? date) {
    if (date == null) return '';
    final d = DateTime.parse(date);
    return '${d.day}/${d.month}/${d.year}';
  }
}

// Bottom sheet để thêm recurring
class AddRecurringSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const AddRecurringSheet({super.key, required this.onSaved});

  @override
  State<AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends State<AddRecurringSheet> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = 'expense';
  String? _categoryId;
  String _frequency = 'monthly';
  int _dayOfMonth = 1;
  int _dayOfWeek = 1;
  List<dynamic> _categories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await apiService.getCategories();
    setState(() => _categories = cats);
  }

  Future<void> _save() async {
    if (_categoryId == null || _amountController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      await apiService.createRecurring({
        'categoryId': _categoryId,
        'amount': double.parse(_amountController.text),
        'type': _type,
        'description': _descriptionController.text,
        'frequency': _frequency,
        'dayOfMonth': _frequency == 'monthly' ? _dayOfMonth : null,
        'dayOfWeek': _frequency == 'weekly' ? _dayOfWeek : null,
        'startDate': DateTime.now().toIso8601String().split('T')[0],
      });
      
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _categories.where((c) => c['type'] == _type).toList();
    
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thêm giao dịch định kỳ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          // Type
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Chi tiêu'),
                  selected: _type == 'expense',
                  onSelected: (_) => setState(() { _type = 'expense'; _categoryId = null; }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Thu nhập'),
                  selected: _type == 'income',
                  onSelected: (_) => setState(() { _type = 'income'; _categoryId = null; }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Category
          DropdownButtonFormField<String>(
            value: _categoryId,
            decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()),
            items: filteredCategories.map<DropdownMenuItem<String>>((c) {
              return DropdownMenuItem(value: c['id'], child: Text('${c['icon'] ?? ''} ${c['name']}'));
            }).toList(),
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 16),
          
          // Amount
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(labelText: 'Số tiền', border: OutlineInputBorder(), prefixText: '₫ '),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          
          // Description
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Mô tả (VD: Tiền nhà)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          
          // Frequency
          DropdownButtonFormField<String>(
            value: _frequency,
            decoration: const InputDecoration(labelText: 'Tần suất', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('Hàng ngày')),
              DropdownMenuItem(value: 'weekly', child: Text('Hàng tuần')),
              DropdownMenuItem(value: 'monthly', child: Text('Hàng tháng')),
              DropdownMenuItem(value: 'yearly', child: Text('Hàng năm')),
            ],
            onChanged: (v) => setState(() => _frequency = v!),
          ),
          const SizedBox(height: 16),
          
          // Day selector
          if (_frequency == 'monthly')
            DropdownButtonFormField<int>(
              value: _dayOfMonth,
              decoration: const InputDecoration(labelText: 'Ngày trong tháng', border: OutlineInputBorder()),
              items: List.generate(28, (i) => DropdownMenuItem(value: i + 1, child: Text('Ngày ${i + 1}'))),
              onChanged: (v) => setState(() => _dayOfMonth = v!),
            ),
          
          if (_frequency == 'weekly')
            DropdownButtonFormField<int>(
              value: _dayOfWeek,
              decoration: const InputDecoration(labelText: 'Ngày trong tuần', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Chủ nhật')),
                DropdownMenuItem(value: 1, child: Text('Thứ 2')),
                DropdownMenuItem(value: 2, child: Text('Thứ 3')),
                DropdownMenuItem(value: 3, child: Text('Thứ 4')),
                DropdownMenuItem(value: 4, child: Text('Thứ 5')),
                DropdownMenuItem(value: 5, child: Text('Thứ 6')),
                DropdownMenuItem(value: 6, child: Text('Thứ 7')),
              ],
              onChanged: (v) => setState(() => _dayOfWeek = v!),
            ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Lưu'),
            ),
          ),
        ],
      ),
    );
  }
}
