import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/api.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<dynamic> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await apiService.getGoals();
      setState(() {
        _goals = result['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(value);
  }

  void _showAddGoalDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    DateTime? deadline;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tạo mục tiêu mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Tên mục tiêu'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Số tiền mục tiêu'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hạn hoàn thành'),
                  subtitle: Text(deadline != null
                      ? DateFormat('dd/MM/yyyy').format(deadline!)
                      : 'Chưa chọn'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (date != null) {
                      setDialogState(() => deadline = date);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
                  try {
                    await apiService.createGoal({
                      'name': nameController.text,
                      'targetAmount': double.parse(amountController.text),
                      'deadline': deadline?.toIso8601String().split('T')[0],
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
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
  }

  void _showContributeDialog(Map<String, dynamic> goal) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Góp tiền: ${goal['name']}'),
        content: TextField(
          controller: amountController,
          decoration: const InputDecoration(labelText: 'Số tiền góp'),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              if (amountController.text.isNotEmpty) {
                try {
                  await apiService.contributeToGoal(goal['id'], {
                    'amount': double.parse(amountController.text),
                  });
                  if (mounted) Navigator.pop(context);
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Đã góp tiền thành công!'), backgroundColor: Colors.green),
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
            },
            child: const Text('Góp'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mục tiêu tài chính'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: _showAISuggestions,
            tooltip: 'AI gợi ý',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _goals.length,
                    itemBuilder: (context, index) => _GoalCard(
                      goal: _goals[index],
                      formatCurrency: _formatCurrency,
                      onContribute: () => _showContributeDialog(_goals[index]),
                      onDelete: () => _deleteGoal(_goals[index]['id']),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddGoalDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tạo mục tiêu'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('Chưa có mục tiêu nào', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Hãy tạo mục tiêu để bắt đầu tiết kiệm!',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _showAddGoalDialog,
            icon: const Icon(Icons.add),
            label: const Text('Tạo mục tiêu đầu tiên'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGoal(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa mục tiêu này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await apiService.deleteGoal(id);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showAISuggestions() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('AI đang phân tích...'),
          ],
        ),
      ),
    );

    try {
      final result = await apiService.getGoalSuggestions();
      if (mounted) Navigator.pop(context);

      final suggestions = result['data']?['suggestions'] ?? [];

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber),
                SizedBox(width: 8),
                Text('AI Gợi ý mục tiêu'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final s = suggestions[index];
                  return Card(
                    child: ListTile(
                      title: Text(s['name'] ?? ''),
                      subtitle: Text(
                        '${_formatCurrency(s['targetAmount'] ?? 0)} - ${s['months'] ?? 0} tháng\n${s['reason'] ?? ''}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _GoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  final String Function(num) formatCurrency;
  final VoidCallback onContribute;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.formatCurrency,
    required this.onContribute,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (goal['progress'] ?? 0).toDouble();
    final current = (goal['current_amount'] ?? 0).toDouble();
    final target = (goal['target_amount'] ?? 0).toDouble();
    final daysRemaining = goal['daysRemaining'];
    final isOnTrack = goal['isOnTrack'] ?? true;

    Color progressColor;
    if (progress >= 100) {
      progressColor = Colors.green;
    } else if (isOnTrack) {
      progressColor = Colors.blue;
    } else {
      progressColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: progressColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.flag, color: progressColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (daysRemaining != null)
                        Text(
                          daysRemaining > 0 ? 'Còn $daysRemaining ngày' : 'Đã hết hạn',
                          style: TextStyle(
                            fontSize: 12,
                            color: daysRemaining > 0 ? Colors.grey : Colors.red,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatCurrency(current), style: TextStyle(color: progressColor, fontWeight: FontWeight.bold)),
                Text('${progress.toStringAsFixed(1)}%', style: TextStyle(color: progressColor)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (progress / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(progressColor),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mục tiêu: ${formatCurrency(target)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                if (goal['monthlyNeeded'] != null && goal['monthlyNeeded'] > 0)
                  Text(
                    'Cần ${formatCurrency(goal['monthlyNeeded'])}/tháng',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: progress >= 100
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Đã hoàn thành! 🎉', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: onContribute,
                      icon: const Icon(Icons.add),
                      label: const Text('Góp tiền'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
