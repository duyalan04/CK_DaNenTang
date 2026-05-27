import 'package:flutter/material.dart';
import '../config/api.dart';

class AIInsightsWidget extends StatefulWidget {
  const AIInsightsWidget({super.key});

  @override
  State<AIInsightsWidget> createState() => _AIInsightsWidgetState();
}

class _AIInsightsWidgetState extends State<AIInsightsWidget> {
  List<dynamic> _insights = [];
  Map<String, dynamic>? _basedOn;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await apiService.getInsights(forceRefresh: forceRefresh);
      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _insights = result['data']?['insights'] ?? [];
          _basedOn = result['data']?['basedOn'];
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  List<_InsightViewModel> get _items {
    return _insights
        .map((insight) => _InsightViewModel.fromInsight(insight))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
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
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phân tích thông minh',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _basedOn == null
                          ? 'Đọc dữ liệu thu chi gần đây để tìm điểm đáng chú ý.'
                          : '${_basedOn!['transactionCount'] ?? 0} giao dịch, ${_basedOn!['period'] ?? ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed:
                    _isLoading ? null : () => _loadData(forceRefresh: true),
                tooltip: 'Làm mới',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const _InsightsLoadingState()
          else if (_hasError)
            _InsightsErrorState(onRetry: _loadData)
          else if (_insights.isEmpty)
            const _InsightsEmptyState()
          else ...[
            _InsightBrief(items: _items),
            const SizedBox(height: 12),
            ..._items.asMap().entries.map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key == _items.length - 1 ? 0 : 10,
                    ),
                    child: _InsightCard(item: entry.value),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _InsightBrief extends StatelessWidget {
  final List<_InsightViewModel> items;

  const _InsightBrief({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highPriorityCount =
        items.where((item) => item.priority == _InsightPriority.high).length;
    final opportunityCount =
        items.where((item) => item.kind == _InsightKind.opportunity).length;
    final primaryMessage = highPriorityCount > 0
        ? '$highPriorityCount điểm cần ưu tiên trong tháng này'
        : opportunityCount > 0
            ? '$opportunityCount cơ hội tối ưu tài chính'
            : 'Tình hình đang ổn, tiếp tục theo dõi đều';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.insights_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              primaryMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final _InsightViewModel item;

  const _InsightCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: item.color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _InsightChip(
                          label: item.kind.label,
                          icon: item.kind.icon,
                          color: item.color,
                        ),
                        _InsightChip(
                          label: item.priority.label,
                          icon: Icons.priority_high,
                          color: item.priority.color,
                        ),
                        if (item.metric != null)
                          _InsightChip(
                            label: item.metric!,
                            icon: Icons.data_usage,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.description,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.task_alt, size: 18, color: item.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.action,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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

class _InsightChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _InsightChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightViewModel {
  final String title;
  final String description;
  final String action;
  final String? metric;
  final _InsightKind kind;
  final _InsightPriority priority;
  final IconData icon;
  final Color color;

  const _InsightViewModel({
    required this.title,
    required this.description,
    required this.action,
    required this.metric,
    required this.kind,
    required this.priority,
    required this.icon,
    required this.color,
  });

  factory _InsightViewModel.fromInsight(dynamic insight) {
    final map = insight is Map<String, dynamic> ? insight : null;
    final rawContent = (map?['content'] ?? insight).toString().trim();
    final cleaned = _cleanContent(rawContent);
    final kind = _InsightKind.fromText(cleaned);
    final priority = _InsightPriority.fromText(cleaned);
    final metric = _extractMetric(cleaned);
    final title = (map?['title']?.toString().trim().isNotEmpty ?? false)
        ? map!['title'].toString().trim()
        : _buildTitle(cleaned, kind);

    return _InsightViewModel(
      title: title,
      description: cleaned,
      action: _buildAction(cleaned, kind),
      metric: metric,
      kind: kind,
      priority: priority,
      icon: kind.icon,
      color: priority == _InsightPriority.high
          ? const Color(0xFFB42318)
          : kind.color,
    );
  }

  static String _cleanContent(String value) {
    return value
        .replaceFirst(RegExp(r'^[\-\*\d\.\)\s]+'), '')
        .replaceFirst(RegExp(r'^[^\wÀ-ỹ]+'), '')
        .trim();
  }

  static String _buildTitle(String text, _InsightKind kind) {
    final lower = text.toLowerCase();
    if (lower.contains('tiết kiệm')) return 'Tiết kiệm nổi bật';
    if (lower.contains('chi tiêu') || lower.contains('danh mục')) {
      return 'Chi tiêu cần chú ý';
    }
    if (lower.contains('giao dịch')) return 'Tần suất giao dịch';
    if (lower.contains('thu nhập')) return 'Nguồn thu nhập';
    if (lower.contains('đầu tư') || lower.contains('thu nhập thụ động')) {
      return 'Cơ hội tăng trưởng';
    }
    return kind.defaultTitle;
  }

  static String _buildAction(String text, _InsightKind kind) {
    final lower = text.toLowerCase();
    if (lower.contains('khác') || lower.contains('phân loại')) {
      return 'Hành động: phân loại lại các khoản “Khác” lớn nhất trước.';
    }
    if (lower.contains('tiết kiệm') && lower.contains('phân bổ')) {
      return 'Hành động: chia khoản tiết kiệm thành quỹ dự phòng, mục tiêu và đầu tư.';
    }
    if (lower.contains('giao dịch') || lower.contains('ghi chép')) {
      return 'Hành động: ghi giao dịch đều hơn để AI nhận diện thói quen chính xác.';
    }
    if (lower.contains('thu nhập')) {
      return 'Hành động: theo dõi từng nguồn thu để biết nguồn nào ổn định nhất.';
    }
    if (lower.contains('đầu tư') || lower.contains('thu nhập thụ động')) {
      return 'Hành động: chỉ dùng phần tiền nhàn rỗi sau khi đã có quỹ dự phòng.';
    }
    return kind.defaultAction;
  }

  static String? _extractMetric(String text) {
    final moneyMatch = RegExp(r'\d[\d\.,]*\s*(?:đ|₫|vnd|VND)').firstMatch(text);
    if (moneyMatch != null) return moneyMatch.group(0);

    final percentMatch = RegExp(r'\d+(?:[\.,]\d+)?\s*%').firstMatch(text);
    if (percentMatch != null) return percentMatch.group(0);

    final monthMatch = RegExp(r'\d+\s*tháng').firstMatch(text.toLowerCase());
    if (monthMatch != null) return monthMatch.group(0);

    return null;
  }
}

enum _InsightKind {
  saving(
    label: 'Tiết kiệm',
    defaultTitle: 'Điểm tiết kiệm',
    defaultAction: 'Hành động: duy trì nhịp tiết kiệm và đặt mục tiêu cụ thể.',
    icon: Icons.savings_outlined,
    color: Color(0xFF16835A),
  ),
  risk(
    label: 'Rủi ro',
    defaultTitle: 'Điểm cần kiểm soát',
    defaultAction: 'Hành động: kiểm tra lại nhóm chi tiêu này trong tuần.',
    icon: Icons.warning_amber_rounded,
    color: Color(0xFFB45309),
  ),
  opportunity(
    label: 'Cơ hội',
    defaultTitle: 'Cơ hội tối ưu',
    defaultAction: 'Hành động: chọn một việc nhỏ có thể thử ngay tháng này.',
    icon: Icons.trending_up,
    color: Color(0xFF2563EB),
  ),
  habit(
    label: 'Thói quen',
    defaultTitle: 'Thói quen tài chính',
    defaultAction: 'Hành động: theo dõi thêm để biến insight thành kế hoạch.',
    icon: Icons.analytics_outlined,
    color: Color(0xFF7C3AED),
  );

  final String label;
  final String defaultTitle;
  final String defaultAction;
  final IconData icon;
  final Color color;

  const _InsightKind({
    required this.label,
    required this.defaultTitle,
    required this.defaultAction,
    required this.icon,
    required this.color,
  });

  factory _InsightKind.fromText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('tiết kiệm') || lower.contains('quỹ')) {
      return _InsightKind.saving;
    }
    if (lower.contains('cắt giảm') ||
        lower.contains('chiếm toàn bộ') ||
        lower.contains('cần') ||
        lower.contains('rủi ro') ||
        lower.contains('không cần thiết')) {
      return _InsightKind.risk;
    }
    if (lower.contains('đầu tư') ||
        lower.contains('thu nhập thụ động') ||
        lower.contains('cơ hội') ||
        lower.contains('tăng')) {
      return _InsightKind.opportunity;
    }
    return _InsightKind.habit;
  }
}

enum _InsightPriority {
  high(label: 'Ưu tiên cao', color: Color(0xFFB42318)),
  medium(label: 'Nên theo dõi', color: Color(0xFFB45309)),
  low(label: 'Ổn định', color: Color(0xFF16835A));

  final String label;
  final Color color;

  const _InsightPriority({
    required this.label,
    required this.color,
  });

  factory _InsightPriority.fromText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('toàn bộ') ||
        lower.contains('cắt giảm') ||
        lower.contains('không cần thiết') ||
        lower.contains('cần xem xét')) {
      return _InsightPriority.high;
    }
    if (lower.contains('nên') ||
        lower.contains('có thể') ||
        lower.contains('xem xét') ||
        lower.contains('phân bổ')) {
      return _InsightPriority.medium;
    }
    return _InsightPriority.low;
  }
}

class _InsightsLoadingState extends StatelessWidget {
  const _InsightsLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 10),
          Text(
            'AI đang phân tích dữ liệu...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _InsightsErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          const Expanded(child: Text('Không thể tải phân tích')),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _InsightsEmptyState extends StatelessWidget {
  const _InsightsEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'Chưa đủ dữ liệu để phân tích',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Hãy ghi thêm giao dịch để nhận nhận xét cá nhân hóa hơn.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
