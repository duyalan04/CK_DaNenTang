import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../config/api.dart';
import '../widgets/anomaly_alert_widget.dart';
import '../widgets/ai_insights_widget.dart';
import '../widgets/savings_suggestions_widget.dart';
import '../widgets/spending_patterns_widget.dart';
import '../widgets/smart_budget_widget.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<dynamic> _byCategory = [];
  List<dynamic> _monthlyTrend = [];
  Map<String, dynamic>? _prediction;
  Map<String, dynamic>? _healthScore;
  bool _isLoading = true;

  final List<Color> _chartColors = [
    Colors.red.shade400,
    Colors.teal.shade400,
    Colors.blue.shade400,
    Colors.green.shade400,
    Colors.orange.shade400,
    Colors.purple.shade400,
    Colors.pink.shade400,
    Colors.indigo.shade400,
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        apiService.getByCategory(),
        apiService.getMonthlyTrend(months: 6),
        apiService.getPrediction(),
        apiService.getHealthScore(),
      ]);
      setState(() {
        _byCategory = results[0] as List<dynamic>;
        _monthlyTrend = results[1] as List<dynamic>;
        _prediction = results[2] as Map<String, dynamic>;
        _healthScore = results[3] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(value);
  }

  String _formatShortCurrency(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo & Phân tích')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Prediction Card
                  if (_prediction != null && _prediction!['prediction'] != null)
                    _buildPredictionCard(),
                  const SizedBox(height: 16),

                  // Health Score Card
                  if (_healthScore != null && _healthScore!['success'] == true)
                    _buildHealthScoreCard(),
                  const SizedBox(height: 16),

                  // AI Insights Widget
                  const AIInsightsWidget(),
                  const SizedBox(height: 16),

                  // Anomaly Alert Widget - PHÁT HIỆN BẤT THƯỜNG
                  const AnomalyAlertWidget(),
                  const SizedBox(height: 16),

                  // Spending Patterns
                  const SpendingPatternsWidget(),
                  const SizedBox(height: 16),

                  // Smart Budget Suggestions (50/30/20)
                  const SmartBudgetWidget(),
                  const SizedBox(height: 16),

                  // Savings Suggestions
                  const SavingsSuggestionsWidget(),
                  const SizedBox(height: 16),

                  // Pie Chart - By Category
                  _buildCategoryChart(),
                  const SizedBox(height: 16),

                  // Line Chart - Monthly Trend
                  _buildTrendChart(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildPredictionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade500, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white),
              SizedBox(width: 8),
              Text('Dự báo chi tiêu tháng tới',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatCurrency(_prediction!['prediction']),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Độ tin cậy: ${_prediction!['confidence'] ?? 0}%',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthScoreCard() {
    final data = _healthScore!['data'];
    final score = data['totalScore'] ?? 0;
    final grade = data['grade'] ?? 'N/A';
    final feedback = data['feedback'] ?? '';

    Color scoreColor;
    if (score >= 80) {
      scoreColor = Colors.green;
    } else if (score >= 60) {
      scoreColor = Colors.blue;
    } else if (score >= 40) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: Colors.red),
                const SizedBox(width: 8),
                const Text('Sức khỏe tài chính',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Grade $grade',
                    style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(scoreColor),
                      ),
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(feedback, style: TextStyle(color: Colors.grey.shade700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart() {
    if (_byCategory.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text('Chưa có dữ liệu chi tiêu', style: TextStyle(color: Colors.grey.shade600)),
          ),
        ),
      );
    }

    final total = _byCategory.fold<double>(0, (sum, c) => sum + (c['total'] ?? 0).toDouble());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chi tiêu theo danh mục',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: _byCategory.asMap().entries.map((entry) {
                    final index = entry.key;
                    final cat = entry.value;
                    final value = (cat['total'] ?? 0).toDouble();
                    final percent = total > 0 ? (value / total * 100) : 0;
                    return PieChartSectionData(
                      value: value,
                      title: '${percent.toStringAsFixed(0)}%',
                      color: _chartColors[index % _chartColors.length],
                      radius: 50,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: _byCategory.asMap().entries.map((entry) {
                final index = entry.key;
                final cat = entry.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _chartColors[index % _chartColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(cat['name'] ?? '', style: const TextStyle(fontSize: 12)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart() {
    if (_monthlyTrend.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text('Chưa có dữ liệu xu hướng', style: TextStyle(color: Colors.grey.shade600)),
          ),
        ),
      );
    }

    final maxY = _monthlyTrend.fold<double>(0, (max, m) {
      final income = (m['income'] ?? 0).toDouble();
      final expense = (m['expense'] ?? 0).toDouble();
      return [max, income, expense].reduce((a, b) => a > b ? a : b);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Xu hướng thu chi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _LegendItem(color: Colors.green, label: 'Thu nhập'),
                const SizedBox(width: 16),
                _LegendItem(color: Colors.red, label: 'Chi tiêu'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) => Text(
                          _formatShortCurrency(value),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _monthlyTrend.length) {
                            final month = _monthlyTrend[index]['month'] ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                month.toString().substring(5),
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    // Income line
                    LineChartBarData(
                      spots: _monthlyTrend.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), (e.value['income'] ?? 0).toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                    // Expense line
                    LineChartBarData(
                      spots: _monthlyTrend.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), (e.value['expense'] ?? 0).toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.red,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
