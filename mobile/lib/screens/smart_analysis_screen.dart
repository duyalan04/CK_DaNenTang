import 'package:flutter/material.dart';
import '../widgets/ai_insights_widget.dart';
import '../widgets/savings_suggestions_widget.dart';
import '../widgets/spending_patterns_widget.dart';
import '../widgets/smart_budget_widget.dart';
import '../widgets/anomaly_alert_widget.dart';

class SmartAnalysisScreen extends StatelessWidget {
  const SmartAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phân tích thông minh'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          // AI Insights
          AIInsightsWidget(),
          SizedBox(height: 16),

          // Anomaly Detection
          AnomalyAlertWidget(),
          SizedBox(height: 16),

          // Spending Patterns
          SpendingPatternsWidget(),
          SizedBox(height: 16),

          // Smart Budget Suggestions (50/30/20)
          SmartBudgetWidget(),
          SizedBox(height: 16),

          // Savings Suggestions
          SavingsSuggestionsWidget(),
          SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.purple),
            SizedBox(width: 8),
            Text('Tính năng AI'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _FeatureInfo(
                icon: Icons.auto_awesome,
                title: 'AI Insights',
                description: 'Phân tích bởi Groq LLM (Llama 3.3 70B)',
              ),
              SizedBox(height: 12),
              _FeatureInfo(
                icon: Icons.warning_amber,
                title: 'Anomaly Detection',
                description: 'Thuật toán Z-score phát hiện giao dịch bất thường',
              ),
              SizedBox(height: 12),
              _FeatureInfo(
                icon: Icons.insights,
                title: 'Spending Patterns',
                description: 'Phát hiện mẫu chi tiêu theo ngày/tuần',
              ),
              SizedBox(height: 12),
              _FeatureInfo(
                icon: Icons.auto_fix_high,
                title: 'Smart Budget',
                description: 'Gợi ý ngân sách theo quy tắc 50/30/20',
              ),
              SizedBox(height: 12),
              _FeatureInfo(
                icon: Icons.savings,
                title: 'Savings Suggestions',
                description: 'Phân tích và gợi ý tiết kiệm theo category',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

class _FeatureInfo extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureInfo({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.purple),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
    );
  }
}
