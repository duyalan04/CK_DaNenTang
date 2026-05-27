import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/api.dart';

class SavingsSuggestionsWidget extends StatefulWidget {
  const SavingsSuggestionsWidget({super.key});

  @override
  State<SavingsSuggestionsWidget> createState() =>
      _SavingsSuggestionsWidgetState();
}

class _SavingsSuggestionsWidgetState extends State<SavingsSuggestionsWidget> {
  List<dynamic> _recommendations = [];
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
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final result = await apiService.getSavingsRecommendations();
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _recommendations = result['data']?['recommendations'] ?? [];
          _summary = result['data']?['summary'];
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  double _parseNum(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(value);
  }

  String _formatShort(num value) {
    if (value >= 1000000) {
      final m = value / 1000000;
      return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)}tr';
    }
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.savings_outlined,
                      size: 18, color: Color(0xFF059669)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cơ hội tiết kiệm',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!_isLoading)
                  GestureDetector(
                    onTap: _loadData,
                    child: Icon(Icons.refresh_rounded,
                        size: 18, color: Colors.grey.shade400),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Content
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else if (_hasError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_off_rounded,
                          color: Colors.grey.shade300, size: 36),
                      const SizedBox(height: 8),
                      Text('Không thể tải dữ liệu',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade400)),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Thử lại', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              )
            else if (_recommendations.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.thumb_up_rounded,
                            color: Color(0xFF059669), size: 22),
                      ),
                      const SizedBox(height: 10),
                      const Text('Chi tiêu hợp lý!',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('Chưa cần điều chỉnh',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  // Summary card
                  if (_summary != null) _buildSummaryCard(),
                  const SizedBox(height: 12),

                  // Legend
                  _buildLegend(),
                  const SizedBox(height: 10),

                  // Recommendations
                  ..._recommendations
                      .take(3)
                      .map((rec) => _SavingsItem(
                            recommendation: rec,
                            formatCurrency: _formatCurrency,
                            formatShort: _formatShort,
                          )),

                  if (_recommendations.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton(
                        onPressed: () => _showAllRecommendations(context),
                        child: Text(
                          'Xem thêm ${_recommendations.length - 3} gợi ý →',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),

                  // Footer
                  if (_summary != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Dựa trên chi tiêu TB ${_formatCurrency(_parseNum(_summary!['totalMonthlyExpense']))}/tháng',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade300),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final yearlySaving =
        _parseNum(_summary!['totalPotentialYearlySavings']);
    final monthlySaving = yearlySaving / 12;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bạn có thể tiết kiệm mỗi tháng',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(monthlySaving),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '≈ ${_formatCurrency(yearlySaving)}/năm',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.flag_rounded,
                color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _LegendDot(color: Colors.red.shade400, label: 'Ưu tiên cao'),
        const SizedBox(width: 12),
        _LegendDot(color: Colors.amber.shade500, label: 'Quan trọng'),
        const SizedBox(width: 12),
        _LegendDot(color: const Color(0xFF059669), label: 'Gợi ý'),
      ],
    );
  }

  void _showAllRecommendations(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.savings_outlined,
                      color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  const Text('Tất cả gợi ý tiết kiệm',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _recommendations.length,
                itemBuilder: (context, index) => _SavingsItem(
                  recommendation: _recommendations[index],
                  formatCurrency: _formatCurrency,
                  formatShort: _formatShort,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// — Subwidgets —

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
      ],
    );
  }
}

class _SavingsItem extends StatelessWidget {
  final dynamic recommendation;
  final String Function(num) formatCurrency;
  final String Function(num) formatShort;

  const _SavingsItem({
    required this.recommendation,
    required this.formatCurrency,
    required this.formatShort,
  });

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rec = recommendation as Map<String, dynamic>? ?? {};
    final category = rec['category'] as Map<String, dynamic>?;
    final name = category?['name']?.toString() ??
        rec['categoryName']?.toString() ??
        'Không xác định';
    final icon = category?['icon']?.toString() ?? '📦';
    final colorHex = category?['color']?.toString() ?? '#9CA3AF';
    final spending = _parseDouble(rec['currentMonthlySpending']);
    final reduction = _parseDouble(rec['suggestedReduction']);
    final yearlySaving = _parseDouble(rec['potentialYearlySavings']);
    final monthlySaving = yearlySaving / 12;
    final priority = _parseInt(rec['priority']);
    final tip = rec['tip']?.toString() ?? '';
    final targetSpending = spending * (1 - reduction / 100);

    // Parse category color
    Color parsedColor = Colors.grey;
    try {
      if (colorHex.startsWith('#')) {
        parsedColor =
            Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
      }
    } catch (_) {}

    // Priority dot color
    Color dotColor;
    switch (priority) {
      case 1:
        dotColor = Colors.red.shade400;
        break;
      case 2:
        dotColor = Colors.amber.shade500;
        break;
      default:
        dotColor = const Color(0xFF059669);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: parsedColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),

          // Main content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + priority dot
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: dotColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // Spending flow: current → target
                Row(
                  children: [
                    Text(
                      '${formatShort(spending)}/th',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 12, color: Colors.grey.shade300),
                    ),
                    Text(
                      '${formatShort(targetSpending)}/th',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '-${reduction.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade400),
                    ),
                  ],
                ),

                // Tip
                if (tip.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    tip,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Savings badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  'Tiết kiệm',
                  style: TextStyle(
                    fontSize: 9,
                    color: const Color(0xFF059669).withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${formatShort(monthlySaving)}/th',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
