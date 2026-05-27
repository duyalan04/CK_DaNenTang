import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../config/api.dart';

enum _GoalFilter { active, completed, all }

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _currencyFormatter = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  List<dynamic> _goals = [];
  bool _isLoading = true;
  _GoalFilter _filter = _GoalFilter.active;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await apiService.getGoals();
      if (!mounted) return;
      setState(() {
        _goals = result['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Không thể tải mục tiêu: $e', isError: true);
    }
  }

  String _formatCurrency(num value) => _currencyFormatter.format(value);

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '')) ?? 0;
    return 0;
  }

  bool _isCompleted(Map<String, dynamic> goal) {
    return _parseDouble(goal['progress']) >= 100 ||
        goal['status'] == 'completed';
  }

  List<Map<String, dynamic>> get _typedGoals {
    return _goals
        .map((goal) => goal as Map<String, dynamic>? ?? <String, dynamic>{})
        .toList();
  }

  List<Map<String, dynamic>> get _visibleGoals {
    final goals = _typedGoals;
    switch (_filter) {
      case _GoalFilter.active:
        return goals.where((goal) => !_isCompleted(goal)).toList();
      case _GoalFilter.completed:
        return goals.where(_isCompleted).toList();
      case _GoalFilter.all:
        return goals;
    }
  }

  _GoalSummary get _summary {
    double current = 0;
    double target = 0;
    int completed = 0;
    int urgent = 0;

    for (final goal in _typedGoals) {
      current += _parseDouble(goal['current_amount']);
      target += _parseDouble(goal['target_amount']);
      if (_isCompleted(goal)) completed += 1;

      final daysRemaining = goal['daysRemaining'];
      if (!_isCompleted(goal) && daysRemaining is num && daysRemaining <= 30) {
        urgent += 1;
      }
    }

    final progress =
        target <= 0 ? 0.0 : (current / target * 100).clamp(0.0, 100.0);
    return _GoalSummary(
      totalGoals: _typedGoals.length,
      completedGoals: completed,
      urgentGoals: urgent,
      currentAmount: current,
      targetAmount: target,
      progress: progress,
    );
  }

  Future<void> _showGoalSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _GoalFormSheet(formatCurrency: _formatCurrency),
    );

    if (created == true) {
      _loadData();
      _showSnackBar('Đã tạo mục tiêu mới');
    }
  }

  Future<void> _showContributeSheet(Map<String, dynamic> goal) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ContributionSheet(
        goal: goal,
        formatCurrency: _formatCurrency,
      ),
    );

    if (added == true) {
      _loadData();
      _showSnackBar('Đã cập nhật tiết kiệm');
    }
  }

  Future<void> _deleteGoal(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa mục tiêu?'),
        content:
            const Text('Mục tiêu và lịch sử tiết kiệm liên quan sẽ bị xóa.'),
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
      ),
    );

    if (confirm != true) return;

    try {
      await apiService.deleteGoal(id);
      _loadData();
      _showSnackBar('Đã xóa mục tiêu');
    } catch (e) {
      _showSnackBar('Không thể xóa mục tiêu: $e', isError: true);
    }
  }

  Future<void> _showSuggestions() async {
    // Use a separate key to safely dismiss the loading dialog
    final navigatorContext = Navigator.of(context, rootNavigator: true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const _LoadingDialog(message: 'Đang phân tích dữ liệu...'),
    );

    try {
      final result = await apiService.getGoalSuggestions();
      if (mounted) navigatorContext.pop();

      final suggestions = result['data']?['suggestions'] ?? [];
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => _SuggestionsSheet(
          suggestions: suggestions,
          formatCurrency: _formatCurrency,
        ),
      );
    } catch (e) {
      if (mounted) navigatorContext.pop();
      _showSnackBar('Không thể lấy gợi ý: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mục tiêu tài chính'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: _showSuggestions,
            tooltip: 'Gợi ý mục tiêu',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _GoalsHeader(
                        summary: _summary,
                        formatCurrency: _formatCurrency,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _GoalFilterBar(
                        selected: _filter,
                        activeCount: _typedGoals
                            .where((goal) => !_isCompleted(goal))
                            .length,
                        completedCount: _summary.completedGoals,
                        totalCount: _summary.totalGoals,
                        onChanged: (filter) => setState(() => _filter = filter),
                      ),
                    ),
                  ),
                  if (_goals.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyGoalsState(onCreate: _showGoalSheet),
                    )
                  else if (_visibleGoals.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyFilteredState(
                        title: _filter == _GoalFilter.completed
                            ? 'Chưa hoàn thành mục tiêu nào'
                            : 'Không có mục tiêu trong bộ lọc này',
                        onCreate: _showGoalSheet,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      sliver: SliverList.separated(
                        itemCount: _visibleGoals.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _GoalCard(
                          goal: _visibleGoals[index],
                          formatCurrency: _formatCurrency,
                          onContribute: () =>
                              _showContributeSheet(_visibleGoals[index]),
                          onDelete: () =>
                              _deleteGoal(_visibleGoals[index]['id']),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                      child: SizedBox(height: theme.visualDensity.vertical.clamp(0, double.infinity))),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGoalSheet,
        icon: const Icon(Icons.add),
        label: const Text('Mục tiêu'),
      ),
    );
  }
}

class _GoalSummary {
  final int totalGoals;
  final int completedGoals;
  final int urgentGoals;
  final double currentAmount;
  final double targetAmount;
  final double progress;

  const _GoalSummary({
    required this.totalGoals,
    required this.completedGoals,
    required this.urgentGoals,
    required this.currentAmount,
    required this.targetAmount,
    required this.progress,
  });
}

class _GoalsHeader extends StatelessWidget {
  final _GoalSummary summary;
  final String Function(num) formatCurrency;

  const _GoalsHeader({
    required this.summary,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = (summary.targetAmount - summary.currentAmount)
        .clamp(0, double.infinity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng tiến độ',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withOpacity(0.72),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${summary.progress.toStringAsFixed(0)}%',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.78),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${summary.completedGoals}/${summary.totalGoals} xong',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: summary.progress / 100,
              minHeight: 12,
              backgroundColor: theme.colorScheme.surface.withOpacity(0.58),
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Đã có',
                  value: formatCurrency(summary.currentAmount),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryMetric(
                  label: 'Còn thiếu',
                  value: formatCurrency(remaining),
                ),
              ),
            ],
          ),
          if (summary.urgentGoals > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 18,
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.78),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${summary.urgentGoals} mục tiêu còn dưới 30 ngày',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer
                          .withOpacity(0.82),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.82),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalFilterBar extends StatelessWidget {
  final _GoalFilter selected;
  final int activeCount;
  final int completedCount;
  final int totalCount;
  final ValueChanged<_GoalFilter> onChanged;

  const _GoalFilterBar({
    required this.selected,
    required this.activeCount,
    required this.completedCount,
    required this.totalCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_GoalFilter>(
      segments: [
        ButtonSegment(
          value: _GoalFilter.active,
          icon: const Icon(Icons.flag_outlined),
          label: Text('Đang làm ($activeCount)'),
        ),
        ButtonSegment(
          value: _GoalFilter.completed,
          icon: const Icon(Icons.check_circle_outline),
          label: Text('Xong ($completedCount)'),
        ),
        ButtonSegment(
          value: _GoalFilter.all,
          icon: const Icon(Icons.list_alt_outlined),
          label: Text('Tất cả ($totalCount)'),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (value) => onChanged(value.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: const VisualDensity(horizontal: -2, vertical: 0),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
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

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '')) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _parseDouble(goal['progress']);
    final current = _parseDouble(goal['current_amount']);
    final target = _parseDouble(goal['target_amount']);
    final monthlyNeeded = _parseDouble(goal['monthlyNeeded']);
    final daysRemaining = goal['daysRemaining'];
    final completed = progress >= 100 || goal['status'] == 'completed';
    final overdue = daysRemaining is num && daysRemaining < 0 && !completed;
    final urgent = daysRemaining is num &&
        daysRemaining <= 30 &&
        daysRemaining >= 0 &&
        !completed;
    final status = _GoalStatus.from(
        completed: completed, overdue: overdue, urgent: urgent);
    final remaining = (target - current).clamp(0, double.infinity);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: status.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(status.icon, color: status.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal['name']?.toString() ?? 'Mục tiêu không tên',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _StatusChip(status: status),
                          if (daysRemaining != null)
                            _SoftChip(
                              icon: Icons.event_outlined,
                              label: daysRemaining is num && daysRemaining >= 0
                                  ? '${daysRemaining.toInt()} ngày'
                                  : 'Quá hạn',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Tùy chọn',
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline),
                          SizedBox(width: 10),
                          Text('Xóa'),
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatCurrency(current),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: status.color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${progress.clamp(0, 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: status.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (progress / 100).clamp(0.0, 1.0),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(status.color),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _CardMetric(
                    label: 'Mục tiêu',
                    value: formatCurrency(target),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CardMetric(
                    label: 'Còn thiếu',
                    value: formatCurrency(remaining),
                  ),
                ),
              ],
            ),
            if (!completed && monthlyNeeded > 0) ...[
              const SizedBox(height: 10),
              _MonthlyPlan(
                amount: formatCurrency(monthlyNeeded),
                color: status.color,
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: completed
                  ? FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Đã hoàn thành'),
                    )
                  : FilledButton.icon(
                      onPressed: onContribute,
                      icon: const Icon(Icons.add),
                      label: const Text('Cập nhật tiết kiệm'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalStatus {
  final String label;
  final IconData icon;
  final Color color;

  const _GoalStatus({
    required this.label,
    required this.icon,
    required this.color,
  });

  factory _GoalStatus.from({
    required bool completed,
    required bool overdue,
    required bool urgent,
  }) {
    if (completed) {
      return const _GoalStatus(
        label: 'Hoàn thành',
        icon: Icons.check_circle,
        color: Color(0xFF16835A),
      );
    }
    if (overdue) {
      return const _GoalStatus(
        label: 'Quá hạn',
        icon: Icons.error_outline,
        color: Color(0xFFC2410C),
      );
    }
    if (urgent) {
      return const _GoalStatus(
        label: 'Sắp đến hạn',
        icon: Icons.schedule,
        color: Color(0xFFB45309),
      );
    }
    return const _GoalStatus(
      label: 'Đang theo dõi',
      icon: Icons.flag,
      color: Color(0xFF0F766E),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final _GoalStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: status.color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SoftChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CardMetric extends StatelessWidget {
  final String label;
  final String value;

  const _CardMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyPlan extends StatelessWidget {
  final String amount;
  final Color color;

  const _MonthlyPlan({
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.savings_outlined, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nên tiết kiệm $amount/tháng',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalFormSheet extends StatefulWidget {
  final String Function(num) formatCurrency;

  const _GoalFormSheet({required this.formatCurrency});

  @override
  State<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<_GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _deadline;
  int? _selectedMonths;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date != null) {
      setState(() {
        _deadline = date;
        _selectedMonths = null; // clear chip selection when manually picking
      });
    }
  }

  void _selectDuration(int months) {
    final now = DateTime.now();
    setState(() {
      _selectedMonths = months;
      _deadline = DateTime(now.year, now.month + months, now.day);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await apiService.createGoal({
        'name': _nameController.text.trim(),
        'targetAmount': double.parse(_amountController.text),
        'deadline': _deadline?.toIso8601String().split('T')[0],
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tạo mục tiêu: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tạo mục tiêu',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Tên mục tiêu',
                prefixIcon: Icon(Icons.flag_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty)
                  return 'Nhập tên mục tiêu';
                if (value.trim().length < 3) return 'Tên cần ít nhất 3 ký tự';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Số tiền mục tiêu',
                prefixIcon: Icon(Icons.payments_outlined),
                suffixText: 'VND',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                if (amount == null || amount <= 0) return 'Nhập số tiền hợp lệ';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Thời hạn',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DurationChip(
                  label: '1 tháng',
                  months: 1,
                  isSelected: _selectedMonths == 1,
                  onTap: () => _selectDuration(1),
                ),
                _DurationChip(
                  label: '3 tháng',
                  months: 3,
                  isSelected: _selectedMonths == 3,
                  onTap: () => _selectDuration(3),
                ),
                _DurationChip(
                  label: '6 tháng',
                  months: 6,
                  isSelected: _selectedMonths == 6,
                  onTap: () => _selectDuration(6),
                ),
                _DurationChip(
                  label: '1 năm',
                  months: 12,
                  isSelected: _selectedMonths == 12,
                  onTap: () => _selectDuration(12),
                ),
                _DurationChip(
                  label: '2 năm',
                  months: 24,
                  isSelected: _selectedMonths == 24,
                  onTap: () => _selectDuration(24),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _pickDeadline,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Hoặc chọn ngày cụ thể',
                  prefixIcon: const Icon(Icons.event_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: _deadline != null
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() {
                            _deadline = null;
                            _selectedMonths = null;
                          }),
                        )
                      : null,
                ),
                child: Text(
                  _deadline == null
                      ? 'Chưa chọn'
                      : DateFormat('dd/MM/yyyy').format(_deadline!),
                  style: TextStyle(
                    color: _deadline == null ? Colors.grey.shade400 : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_isSaving ? 'Đang lưu' : 'Tạo mục tiêu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributionSheet extends StatefulWidget {
  final Map<String, dynamic> goal;
  final String Function(num) formatCurrency;

  const _ContributionSheet({
    required this.goal,
    required this.formatCurrency,
  });

  @override
  State<_ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends State<_ContributionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isSaving = false;

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '')) ?? 0;
    return 0;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _setAmount(int amount) {
    _amountController.text = amount.toString();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await apiService.contributeToGoal(widget.goal['id'], {
        'amount': double.parse(_amountController.text),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể cập nhật: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final target = _parseDouble(widget.goal['target_amount']);
    final current = _parseDouble(widget.goal['current_amount']);
    final remaining = (target - current).clamp(0, double.infinity);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.goal['name']?.toString() ?? 'Cập nhật tiết kiệm',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Còn thiếu ${widget.formatCurrency(remaining)}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),

            // Quick amount chips
            Text(
              'Chọn nhanh',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickAmountChip(label: '500K', value: 500000, onTap: () => _setAmount(500000)),
                _QuickAmountChip(label: '1 tr', value: 1000000, onTap: () => _setAmount(1000000)),
                _QuickAmountChip(label: '2 tr', value: 2000000, onTap: () => _setAmount(2000000)),
                _QuickAmountChip(label: '3 tr', value: 3000000, onTap: () => _setAmount(3000000)),
                _QuickAmountChip(label: '5 tr', value: 5000000, onTap: () => _setAmount(5000000)),
                _QuickAmountChip(label: '10 tr', value: 10000000, onTap: () => _setAmount(10000000)),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Hoặc nhập số tiền',
                prefixIcon: Icon(Icons.savings_outlined),
                suffixText: 'VND',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                if (amount == null || amount <= 0) return 'Nhập số tiền hợp lệ';
                return null;
              },
            ),
            const SizedBox(height: 10),

            // Helpful note
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ghi nhận số tiền bạn đã để dành, không chuyển tiền thật.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_isSaving ? 'Đang lưu' : 'Cập nhật tiết kiệm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionsSheet extends StatelessWidget {
  final dynamic suggestions;
  final String Function(num) formatCurrency;

  const _SuggestionsSheet({
    required this.suggestions,
    required this.formatCurrency,
  });

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '')) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = suggestions is List ? suggestions as List : const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gợi ý mục tiêu',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Chưa có gợi ý phù hợp')),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final suggestion =
                      items[index] as Map<String, dynamic>? ?? {};
                  final amount = _parseDouble(suggestion['targetAmount']);

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion['name']?.toString() ?? 'Mục tiêu đề xuất',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SoftChip(
                              icon: Icons.payments_outlined,
                              label: formatCurrency(amount),
                            ),
                            _SoftChip(
                              icon: Icons.calendar_month_outlined,
                              label: '${suggestion['months'] ?? 0} tháng',
                            ),
                          ],
                        ),
                        if ((suggestion['reason']?.toString() ?? '')
                            .isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            suggestion['reason'].toString(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyGoalsState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyGoalsState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag_outlined, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Chưa có mục tiêu',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Tách khoản tiết kiệm thành từng đích đến để theo dõi tiến độ rõ hơn.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Tạo mục tiêu đầu tiên'),
          ),
        ],
      ),
    );
  }
}

class _EmptyFilteredState extends StatelessWidget {
  final String title;
  final VoidCallback onCreate;

  const _EmptyFilteredState({
    required this.title,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined,
              size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Tạo mục tiêu'),
          ),
        ],
      ),
    );
  }
}

class _LoadingDialog extends StatelessWidget {
  final String message;

  const _LoadingDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final int months;
  final bool isSelected;
  final VoidCallback onTap;

  const _DurationChip({
    required this.label,
    required this.months,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.12) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accent : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? accent : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onTap;

  const _QuickAmountChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
