import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../config/api.dart';

class HealthScoreWidget extends StatefulWidget {
  const HealthScoreWidget({super.key});

  @override
  State<HealthScoreWidget> createState() => _HealthScoreWidgetState();
}

class _HealthScoreWidgetState extends State<HealthScoreWidget>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  bool _hasError = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final result = await apiService.getHealthScore();
      if (result['success'] == true) {
        setState(() {
          _data = result['data'];
          _isLoading = false;
        });
        _animationController.forward(from: 0);
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
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(value);
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  num _parseNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text('Đang tính điểm...', style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    if (_hasError || _data == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              const Expanded(child: Text('Không thể tải điểm sức khỏe')),
              TextButton(onPressed: _loadData, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    final totalScore = _parseInt(_data!['totalScore']);
    final grade = _data!['grade']?.toString() ?? 'D';
    final feedback = _data!['feedback']?.toString() ?? '';
    final improvements = List<String>.from(_data!['improvements'] ?? []);
    final breakdown = _data!['breakdown'] as Map<String, dynamic>?;
    final summary = _data!['summary'] as Map<String, dynamic>?;
    final scoreColor = _getScoreColor(totalScore);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.red.shade400),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Điểm sức khỏe tài chính',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Grade $grade',
                    style: TextStyle(
                      color: scoreColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Circular Score
            Center(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return _CircularScore(
                    score: (totalScore * _animation.value).round(),
                    color: scoreColor,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Feedback
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: scoreColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feedback,
                      style: TextStyle(color: scoreColor.withOpacity(0.8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Breakdown
            if (breakdown != null) ...[
              const Text('Chi tiết điểm',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _BreakdownItem(
                label: breakdown['savingsRate']?['label']?.toString() ?? 'Tiết kiệm',
                score: _parseInt(breakdown['savingsRate']?['score']),
                maxScore: 25,
                value: breakdown['savingsRate']?['value']?.toString() ?? '',
                color: Colors.green,
              ),
              _BreakdownItem(
                label: breakdown['budgetCompliance']?['label']?.toString() ?? 'Ngân sách',
                score: _parseInt(breakdown['budgetCompliance']?['score']),
                maxScore: 25,
                value: breakdown['budgetCompliance']?['value']?.toString() ?? '',
                color: Colors.blue,
              ),
              _BreakdownItem(
                label: breakdown['spendingStability']?['label']?.toString() ?? 'Ổn định',
                score: _parseInt(breakdown['spendingStability']?['score']),
                maxScore: 25,
                value: breakdown['spendingStability']?['value']?.toString() ?? '',
                color: Colors.orange,
              ),
              _BreakdownItem(
                label: breakdown['diversification']?['label']?.toString() ?? 'Đa dạng',
                score: _parseInt(breakdown['diversification']?['score']),
                maxScore: 25,
                value: breakdown['diversification']?['value']?.toString() ?? '',
                color: Colors.purple,
              ),
            ],

            // Improvements
            if (improvements.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Cần cải thiện',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...improvements.map((tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      tip,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  )),
            ],

            // Summary
            if (summary != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryItem(
                    label: 'Thu nhập',
                    value: _formatCurrency(_parseNum(summary['income'])),
                    color: Colors.green,
                  ),
                  _SummaryItem(
                    label: 'Chi tiêu',
                    value: _formatCurrency(_parseNum(summary['expense'])),
                    color: Colors.red,
                  ),
                  _SummaryItem(
                    label: 'Tiết kiệm',
                    value: _formatCurrency(_parseNum(summary['savings'])),
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class _CircularScore extends StatelessWidget {
  final int score;
  final Color color;

  const _CircularScore({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        children: [
          // Background circle
          CustomPaint(
            size: const Size(140, 140),
            painter: _CirclePainter(
              progress: 1.0,
              color: Colors.grey.shade200,
              strokeWidth: 12,
            ),
          ),
          // Progress circle
          CustomPaint(
            size: const Size(140, 140),
            painter: _CirclePainter(
              progress: score / 100,
              color: color,
              strokeWidth: 12,
            ),
          ),
          // Score text
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  '/ 100',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CirclePainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CirclePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _BreakdownItem extends StatelessWidget {
  final String label;
  final int score;
  final int maxScore;
  final String value;
  final Color color;

  const _BreakdownItem({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              Text('$score/$maxScore',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: score / maxScore,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
          if (value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(value,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
