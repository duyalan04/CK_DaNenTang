import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/api.dart';

class SpendingPatternsWidget extends StatefulWidget {
  const SpendingPatternsWidget({super.key});

  @override
  State<SpendingPatternsWidget> createState() => _SpendingPatternsWidgetState();
}

class _SpendingPatternsWidgetState extends State<SpendingPatternsWidget> {
  Map<String, dynamic>? _patterns;
  List<dynamic> _insights = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final result = await apiService.getSpendingPatterns();
      if (result['success'] == true) {
        setState(() {
          _patterns = result['data']?['patterns'];
          _insights = result['data']?['insights'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.insights, color: Colors.indigo.shade600),
                const SizedBox(width: 8),
                const Text('Mẫu chi tiêu',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (!_isLoading)
                  IconButton(
                    icon: Icon(Icons.refresh, size: 20, color: Colors.grey.shade600),
                    onPressed: _loadData,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Content
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_hasError)
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(height: 8),
                    const Text('Không thể tải dữ liệu'),
                    TextButton(onPressed: _loadData, child: const Text('Thử lại')),
                  ],
                ),
              )
            else if (_patterns == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Cần thêm dữ liệu để phân tích'),
                ),
              )
            else
              Column(
                children: [
                  // Peak Spending Day & Week
                  Row(
                    children: [
                      Expanded(
                        child: _PatternCard(
                          icon: Icons.calendar_today,
                          iconColor: Colors.blue,
                          title: 'Ngày chi nhiều nhất',
                          value: _patterns!['peakSpendingDay']?['day'] ?? 'N/A',
                          subtitle: 'TB: ${_formatCurrency(_patterns!['peakSpendingDay']?['avgAmount'] ?? 0)}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PatternCard(
                          icon: Icons.date_range,
                          iconColor: Colors.orange,
                          title: 'Tuần chi nhiều nhất',
                          value: _patterns!['peakSpendingWeek']?['description'] ?? 'N/A',
                          subtitle: 'Tuần ${_patterns!['peakSpendingWeek']?['week'] ?? 0}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Day of Week Chart
                  if (_patterns!['byDayOfWeek'] != null) ...[
                    const Text('Chi tiêu theo ngày trong tuần',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _DayOfWeekChart(data: _patterns!['byDayOfWeek']),
                    const SizedBox(height: 16),
                  ],

                  // Top Categories
                  if (_patterns!['topCategories'] != null &&
                      (_patterns!['topCategories'] as List).isNotEmpty) ...[
                    const Text('Top danh mục chi tiêu',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    ...(_patterns!['topCategories'] as List).take(3).map((cat) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(cat['name'] ?? '', style: const TextStyle(fontSize: 13))),
                              Text(
                                _formatCurrency(cat['total'] ?? 0),
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        )),
                  ],

                  // Insights
                  if (_insights.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    ..._insights.map((insight) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            insight.toString(),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        )),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  const _PatternCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _DayOfWeekChart extends StatelessWidget {
  final List<dynamic> data;

  const _DayOfWeekChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxTotal = data.fold<double>(0, (max, d) => 
        (d['total'] ?? 0).toDouble() > max ? (d['total'] ?? 0).toDouble() : max);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: data.map((d) {
        final total = (d['total'] ?? 0).toDouble();
        final height = maxTotal > 0 ? (total / maxTotal * 60) : 0.0;
        final day = (d['day'] ?? '').toString();
        final shortDay = day.length > 2 ? day.substring(0, 2) : day;

        return Column(
          children: [
            Container(
              width: 24,
              height: 60,
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 24,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.indigo.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(shortDay, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        );
      }).toList(),
    );
  }
}
