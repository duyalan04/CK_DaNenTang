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
  String? _error;

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
        apiService.getSummary(),
        apiService.getTransactions(),
      ]);

      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _transactions = results[1] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(value);
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? 'Bạn';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Xin chào, $userName', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
            const Text('Expense Tracker', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
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
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Lỗi: $_error'),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _loadData, child: const Text('Thử lại')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary Cards
                      _SummarySection(
                        income: _summary?['totalIncome'] ?? 0,
                        expense: _summary?['totalExpense'] ?? 0,
                        balance: _summary?['balance'] ?? 0,
                        formatCurrency: _formatCurrency,
                      ),
                      const SizedBox(height: 24),

                      // Quick Actions
                      const Text('Thao tác nhanh', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.add,
                              label: 'Thêm giao dịch',
                              color: Colors.blue,
                              onTap: () async {
                                await context.push('/add');
                                _loadData();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.camera_alt,
                              label: 'Quét hóa đơn',
                              color: Colors.orange,
                              onTap: () async {
                                await context.push('/ocr');
                                _loadData();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.smart_toy,
                              label: 'Hỏi AI',
                              color: Colors.purple,
                              onTap: () => context.push('/chat'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Recent Transactions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Giao dịch gần đây', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () => context.push('/transactions'),
                            child: const Text('Xem tất cả'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_transactions.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                const Text('Chưa có giao dịch nào'),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: () async {
                                    await context.push('/add');
                                    _loadData();
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Thêm giao dịch đầu tiên'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._transactions.take(10).map((t) => _TransactionTile(
                              transaction: t,
                              formatCurrency: _formatCurrency,
                            )),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/add');
          _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm'),
        backgroundColor: Colors.teal,
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final num income;
  final num expense;
  final num balance;
  final String Function(num) formatCurrency;

  const _SummarySection({
    required this.income,
    required this.expense,
    required this.balance,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Balance Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade400, Colors.teal.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Số dư hiện tại', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                formatCurrency(balance),
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Income & Expense Row
        Row(
          children: [
            Expanded(
              child: _MiniSummaryCard(
                title: 'Thu nhập',
                amount: formatCurrency(income),
                icon: Icons.arrow_downward,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniSummaryCard(
                title: 'Chi tiêu',
                amount: formatCurrency(expense),
                icon: Icons.arrow_upward,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniSummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;

  const _MiniSummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
    final colorHex = category?['color'] ?? '#808080';
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(
            isExpense ? Icons.arrow_upward : Icons.arrow_downward,
            color: color,
            size: 20,
          ),
        ),
        title: Text(category?['name'] ?? 'Không xác định'),
        subtitle: Text(
          transaction['description'] ?? transaction['transaction_date'] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '${isExpense ? '-' : '+'}${formatCurrency(transaction['amount'])}',
          style: TextStyle(
            color: isExpense ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
