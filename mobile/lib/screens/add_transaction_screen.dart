import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/api.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = 'expense';
  String? _categoryId;
  List<dynamic> _categories = [];
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await apiService.getCategories();
    setState(() => _categories = categories);
  }

  Future<void> _submit() async {
    if (_categoryId == null || _amountController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await apiService.createTransaction({
        'categoryId': _categoryId,
        'amount': double.parse(_amountController.text),
        'type': _type,
        'description': _descriptionController.text,
        'transactionDate': _selectedDate.toIso8601String().split('T')[0],
      });

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _categories.where((c) => c['type'] == _type).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Thêm giao dịch')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Type selector
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Chi tiêu'),
                  selected: _type == 'expense',
                  onSelected: (_) => setState(() {
                    _type = 'expense';
                    _categoryId = null;
                  }),
                  selectedColor: Colors.red.shade100,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Thu nhập'),
                  selected: _type == 'income',
                  onSelected: (_) => setState(() {
                    _type = 'income';
                    _categoryId = null;
                  }),
                  selectedColor: Colors.green.shade100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _categoryId,
            decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()),
            items: filteredCategories.map<DropdownMenuItem<String>>((c) {
              return DropdownMenuItem(value: c['id'], child: Text(c['name']));
            }).toList(),
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(labelText: 'Số tiền', border: OutlineInputBorder(), prefixText: '₫ '),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Ngày'),
            subtitle: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) setState(() => _selectedDate = date);
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
