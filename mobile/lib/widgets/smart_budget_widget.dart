import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../config/api.dart';

class SmartBudgetWidget extends StatefulWidget {
  const SmartBudgetWidget({super.key});

  @override
  State<SmartBudgetWidget> createState() => _SmartBudgetWidgetState();
}

class _SmartBudgetWidgetState extends State<SmartBudgetWidget> {
  List<dynamic> _suggestions = [];
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final result = await apiService.getBudgetSuggestions();
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _suggestions = result['data']?['suggestions'] ?? [];
          _summary = result['data']?['summary'];
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() { _hasError = true; _isLoading = false; });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() { _hasError = true; _isLoading = false; });
      }
    }
  }

  String _fmt(num value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(value);
  }

  String _fmtShort(num value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}tr';
    if (value >= 1000) return '${(value / 1000).round()}k';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: Colors.teal.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ngân sách thông minh',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text('Phân tích 3 tháng · Quy tắc 50/30/20',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: _isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.refresh, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: _isLoading ? null : _loadData,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_hasError)
            _ErrorState(onRetry: _loadData)
          else ...[
            // Donut + Legend
            if (_summary != null) _OverviewSection(summary: _summary!, fmt: _fmt, fmtShort: _fmtShort),

            // Quick stats
            if (_summary != null && ((_summary!['needsAdjustment'] ?? 0) > 0 || (_summary!['potentialMonthlySavings'] ?? 0) > 0))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if ((_summary!['needsAdjustment'] ?? 0) > 0)
                      Expanded(child: _QuickStat(
                        icon: Icons.tune, color: Colors.amber,
                        text: '${_summary!['needsAdjustment']} mục cần giảm',
                      )),
                    if ((_summary!['needsAdjustment'] ?? 0) > 0 && (_summary!['potentialMonthlySavings'] ?? 0) > 0)
                      const SizedBox(width: 8),
                    if ((_summary!['potentialMonthlySavings'] ?? 0) > 0)
                      Expanded(child: _QuickStat(
                        icon: Icons.savings_outlined, color: Colors.green,
                        text: 'Tiết kiệm ~${_fmtShort(_summary!['potentialMonthlySavings'])}/tháng',
                      )),
                  ],
                ),
              ),

            const SizedBox(height: 12),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),

            // Suggestions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _suggestions.isNotEmpty
                ? _SuggestionsList(
                    suggestions: _suggestions,
                    monthlyIncome: (_summary?['monthlyIncome'] ?? 0).toDouble(),
                    fmt: _fmt, fmtShort: _fmtShort,
                  )
                : _EmptyState(),
            ),
          ],

          // Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Text('Dựa trên chi tiêu 3 tháng gần đây',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

// ── Overview with mini donut ──
class _OverviewSection extends StatelessWidget {
  final Map<String, dynamic> summary;
  final String Function(num) fmt;
  final String Function(num) fmtShort;

  const _OverviewSection({required this.summary, required this.fmt, required this.fmtShort});

  @override
  Widget build(BuildContext context) {
    final income = (summary['monthlyIncome'] ?? 0).toDouble();
    final essentials = (summary['essentials'] ?? 0).toDouble();
    final wants = (summary['wants'] ?? 0).toDouble();
    final savings = (summary['savings'] ?? 0).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Mini donut
          SizedBox(
            width: 90, height: 90,
            child: CustomPaint(
              painter: _DonutPainter(essentials: essentials, wants: wants, savings: savings, income: income),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Thu nhập', style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
                    Text(fmtShort(income),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Legend
          Expanded(
            child: Column(
              children: [
                _LegendRow(color: const Color(0xFF3b82f6), label: 'Thiết yếu 50%', amount: fmt(essentials)),
                const SizedBox(height: 8),
                _LegendRow(color: const Color(0xFFf97316), label: 'Mong muốn 30%', amount: fmt(wants)),
                const SizedBox(height: 8),
                _LegendRow(color: const Color(0xFF22c55e), label: 'Tiết kiệm 20%', amount: fmt(savings)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String amount;

  const _LegendRow({required this.color, required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const Spacer(),
        Text(amount, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ── Donut Painter ──
class _DonutPainter extends CustomPainter {
  final double essentials, wants, savings, income;
  _DonutPainter({required this.essentials, required this.wants, required this.savings, required this.income});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 8.0;
    const gapAngle = 0.06;
    final total = income > 0 ? income : 1;

    final segments = [
      (essentials / total, const Color(0xFF3b82f6)),
      (wants / total, const Color(0xFFf97316)),
      (savings / total, const Color(0xFF22c55e)),
    ];

    double startAngle = -math.pi / 2;
    for (final (fraction, color) in segments) {
      final sweepAngle = fraction * 2 * math.pi - gapAngle;
      if (sweepAngle > 0) {
        final paint = Paint()
          ..color = color ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth ..strokeCap = StrokeCap.round;
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, paint);
      }
      startAngle += fraction * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── Suggestion List ──
class _SuggestionsList extends StatelessWidget {
  final List<dynamic> suggestions;
  final double monthlyIncome;
  final String Function(num) fmt;
  final String Function(num) fmtShort;

  const _SuggestionsList({required this.suggestions, required this.monthlyIncome, required this.fmt, required this.fmtShort});

  @override
  Widget build(BuildContext context) {
    final reduce = suggestions.where((s) => s['recommendation'] == 'reduce').toList();
    final others = suggestions.where((s) => s['recommendation'] != 'reduce').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reduce.isNotEmpty) ...[
          Text('CẦN ĐIỀU CHỈNH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
            color: Colors.grey.shade500, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          ...reduce.map((s) => _SuggestionTile(s: s, income: monthlyIncome, fmt: fmt, fmtShort: fmtShort)),
        ],
        if (others.isNotEmpty) ...[
          if (reduce.isNotEmpty) const SizedBox(height: 12),
          Text('ĐANG HỢP LÝ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
            color: Colors.grey.shade500, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          ...others.map((s) => _SuggestionTile(s: s, income: monthlyIncome, fmt: fmt, fmtShort: fmtShort)),
        ],
      ],
    );
  }
}

class _SuggestionTile extends StatefulWidget {
  final dynamic s;
  final double income;
  final String Function(num) fmt;
  final String Function(num) fmtShort;

  const _SuggestionTile({required this.s, required this.income, required this.fmt, required this.fmtShort});

  @override
  State<_SuggestionTile> createState() => _SuggestionTileState();
}

class _SuggestionTileState extends State<_SuggestionTile> {
  bool _expanded = false;

  double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.s as Map<String, dynamic>? ?? {};
    final name = s['categoryName']?.toString() ?? '';
    final icon = s['categoryIcon']?.toString() ?? '📝';
    final colorStr = s['categoryColor']?.toString() ?? '#9CA3AF';
    final current = _d(s['currentMonthlyAvg']);
    final suggested = _d(s['suggestedBudget']);
    final pct = _d(s['percentOfIncome']);
    final rec = s['recommendation']?.toString() ?? 'maintain';
    final reason = s['reason']?.toString() ?? '';
    final savings = _d(s['potentialMonthlySavings']);
    final priority = s['priority'] ?? 3;

    final isReduce = rec == 'reduce';
    final isIncrease = rec == 'increase';
    final tagColor = isReduce ? Colors.red : isIncrease ? Colors.blue : Colors.green;
    final tagIcon = isReduce ? Icons.trending_down : isIncrease ? Icons.trending_up : Icons.check;
    final tagText = isReduce ? 'Giảm' : isIncrease ? 'Tăng' : 'OK';

    Color parsedColor = Colors.grey;
    try {
      if (colorStr.startsWith('#')) {
        parsedColor = Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
      }
    } catch (_) {}

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _expanded ? tagColor.shade50.withValues(alpha: 0.3) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _expanded ? tagColor.shade200 : Colors.transparent),
        ),
        child: Column(
          children: [
            // Main row
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: parsedColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), overflow: TextOverflow.ellipsis)),
                          if (priority == 1) ...[
                            const SizedBox(width: 4),
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                          ],
                        ],
                      ),
                      Text('${pct.toStringAsFixed(1)}% · ${widget.fmt(current)}/tháng',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: tagColor.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tagIcon, size: 12, color: tagColor.shade600),
                      const SizedBox(width: 3),
                      Text(tagText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tagColor.shade700)),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: Colors.grey.shade400),
              ],
            ),

            // Expanded
            if (_expanded) ...[
              const SizedBox(height: 10),
              // Comparison bars
              _CompBar(label: 'Đang chi', value: current, max: widget.income, color: Colors.grey.shade400, fmt: widget.fmtShort),
              const SizedBox(height: 4),
              _CompBar(label: 'Nên chi', value: suggested, max: widget.income, color: isReduce ? Colors.green.shade500 : Colors.blue.shade500, fmt: widget.fmtShort),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('💡 $reason', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3)),
              ],
              if (savings > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.savings_outlined, size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 6),
                      Text('Tiết kiệm ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      Text(widget.fmt(savings), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.green.shade700)),
                      Text('/tháng', style: TextStyle(fontSize: 10, color: Colors.green.shade500)),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CompBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;
  final String Function(num) fmt;

  const _CompBar({required this.label, required this.value, required this.max, required this.color, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final pct = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(width: 44, child: Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500), textAlign: TextAlign.right)),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(3)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(width: 40, child: Text(fmt(value), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.right)),
      ],
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final MaterialColor color;
  final String text;

  const _QuickStat({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color.shade600),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.shade700))),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade300),
          const SizedBox(height: 8),
          const Text('Không thể tải gợi ý'),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
              child: Icon(Icons.check, color: Colors.green.shade500, size: 28),
            ),
            const SizedBox(height: 8),
            const Text('Chi tiêu hợp lý!', style: TextStyle(fontWeight: FontWeight.w700)),
            Text('Không cần điều chỉnh', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
