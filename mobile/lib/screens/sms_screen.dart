import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/api.dart';

class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key});

  @override
  State<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> {
  List<Map<String, dynamic>> _smsList = [];
  List<Map<String, dynamic>> _parsedTransactions = [];
  bool _isLoading = false;
  bool _hasPermission = false;
  String _statusMessage = '';

  static const platform = MethodChannel('com.example.expense_tracker/sms');

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    try {
      final bool result = await platform.invokeMethod('checkSmsPermission');
      setState(() => _hasPermission = result);
      if (result) {
        _loadSms();
      }
    } on PlatformException {
      setState(() => _hasPermission = false);
    }
  }

  Future<void> _requestPermission() async {
    try {
      final bool result = await platform.invokeMethod('requestSmsPermission');
      setState(() => _hasPermission = result);
      if (result) {
        _loadSms();
      }
    } on PlatformException catch (e) {
      setState(() => _statusMessage = 'Không thể xin quyền: ${e.message}');
    }
  }

  Future<void> _loadSms() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang đọc tin nhắn...';
    });

    try {
      // Lấy SMS từ native code
      final List<dynamic> messages = await platform.invokeMethod('getBankingSms');
      
      setState(() {
        _smsList = messages.cast<Map<String, dynamic>>();
        _statusMessage = 'Tìm thấy ${_smsList.length} tin nhắn ngân hàng';
      });

      // Parse SMS bằng AI
      if (_smsList.isNotEmpty) {
        await _parseSmsMessages();
      }
    } on PlatformException catch (e) {
      setState(() => _statusMessage = 'Lỗi: ${e.message}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _parseSmsMessages() async {
    setState(() => _statusMessage = 'Đang phân tích tin nhắn...');
    
    try {
      final parsed = await apiService.parseBankingSms(_smsList);
      setState(() {
        _parsedTransactions = List<Map<String, dynamic>>.from(parsed);
        _statusMessage = 'Nhận diện ${_parsedTransactions.length} giao dịch';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Lỗi phân tích: $e');
    }
  }

  Future<void> _saveTransaction(Map<String, dynamic> transaction) async {
    try {
      await apiService.createTransaction({
        'categoryId': transaction['categoryId'],
        'amount': transaction['amount'],
        'type': transaction['type'],
        'description': transaction['description'],
        'transactionDate': transaction['date'] ?? DateTime.now().toIso8601String().split('T')[0],
      });
      
      setState(() {
        _parsedTransactions.remove(transaction);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveAllTransactions() async {
    int saved = 0;
    for (final t in _parsedTransactions) {
      try {
        await apiService.createTransaction({
          'categoryId': t['categoryId'],
          'amount': t['amount'],
          'type': t['type'],
          'description': t['description'],
          'transactionDate': t['date'] ?? DateTime.now().toIso8601String().split('T')[0],
        });
        saved++;
      } catch (_) {}
    }
    
    setState(() => _parsedTransactions.clear());
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu $saved giao dịch!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Banking'),
        actions: [
          if (_parsedTransactions.isNotEmpty)
            TextButton.icon(
              onPressed: _saveAllTransactions,
              icon: const Icon(Icons.save_alt, color: Colors.white),
              label: const Text('Lưu tất cả', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: !_hasPermission
          ? _buildPermissionRequest()
          : _isLoading
              ? _buildLoading()
              : _buildContent(),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sms, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 24),
            const Text(
              'Cần quyền đọc SMS',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Ứng dụng cần quyền đọc tin nhắn để tự động nhận diện giao dịch từ SMS ngân hàng',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _requestPermission,
              icon: const Icon(Icons.security),
              label: const Text('Cấp quyền'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_statusMessage),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_parsedTransactions.isEmpty && _smsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Không tìm thấy tin nhắn ngân hàng'),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadSms,
              icon: const Icon(Icons.refresh),
              label: const Text('Quét lại'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSms,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(child: Text(_statusMessage)),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Parsed transactions
          if (_parsedTransactions.isNotEmpty) ...[
            const Text('Giao dịch nhận diện', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._parsedTransactions.map((t) => _buildTransactionCard(t)),
          ],
          
          const SizedBox(height: 20),
          
          // Raw SMS
          ExpansionTile(
            title: Text('Tin nhắn gốc (${_smsList.length})'),
            children: _smsList.map((sms) => ListTile(
              title: Text(sms['sender'] ?? 'Unknown'),
              subtitle: Text(sms['body'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Text(sms['date'] ?? ''),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final isExpense = transaction['type'] == 'expense';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpense ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isExpense ? 'Chi tiêu' : 'Thu nhập',
                    style: TextStyle(
                      color: isExpense ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${isExpense ? "-" : "+"}${_formatCurrency(transaction['amount'])}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isExpense ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(transaction['description'] ?? '', style: const TextStyle(fontSize: 16)),
            if (transaction['date'] != null)
              Text(transaction['date'], style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _parsedTransactions.remove(transaction)),
                  child: const Text('Bỏ qua'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _saveTransaction(transaction),
                  child: const Text('Lưu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
}
