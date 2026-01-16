import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../config/api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _summary;
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final summary = await apiService.getSummary();
      final transactions = await apiService.getTransactions();
      setState(() {
        _summary = summary;
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Thu nhập',
                          amount: _formatCurrency(_summary?['totalIncome'] ?? 0),
                          color: Colors.green,
                          icon: Icons.trending_up,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Chi tiêu',
                          amount: _formatCurrency(_summary?['totalExpense'] ?? 0),
                          color: Colors.red,
                          icon: Icons.trending_down,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    title: 'Số dư',
                    amount: _formatCurrency(_summary?['balance'] ?? 0),
                    color: Colors.blue,
                    icon: Icons.account_balance_wallet,
                  ),
                  const SizedBox(height: 24),
                  const Text('Giao dịch gần đây', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ..._transactions.take(10).map((t) => _TransactionTile(
                        transaction: t,
                        formatCurrency: _formatCurrency,
                      )),
                ],
              ),
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'chat',
            onPressed: () => context.push('/chat'),
            backgroundColor: Colors.purple,
            child: const Icon(Icons.smart_toy, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'ocr',
            onPressed: () => context.push('/ocr'),
            child: const Icon(Icons.camera_alt),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: () async {
              await context.push('/add');
              _loadData();
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({required this.title, required this.amount, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.grey)),
                  Text(amount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final String Function(num) formatCurrency;

  const _TransactionTile({required this.transaction, required this.formatCurrency});

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction['type'] == 'expense';
    final category = transaction['categories'];

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(int.parse((category?['color'] ?? '#808080').replaceFirst('#', '0xFF'))),
          child: Icon(Icons.category, color: Colors.white, size: 20),
        ),
        title: Text(category?['name'] ?? 'Unknown'),
        subtitle: Text(transaction['description'] ?? ''),
        trailing: Text(
          '${isExpense ? '-' : '+'}${formatCurrency(transaction['amount'])}',
          style: TextStyle(color: isExpense ? Colors.red : Colors.green, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
