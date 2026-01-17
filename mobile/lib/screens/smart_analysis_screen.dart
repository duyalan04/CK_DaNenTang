import 'package:flutter/material.dart';
import '../widgets/ai_insights_widget.dart';
import '../widgets/savings_suggestions_widget.dart';
import '../widgets/smart_budget_widget.dart';
import '../widgets/anomaly_alert_widget.dart';
import '../widgets/health_score_widget.dart';
import '../widgets/prediction_widget.dart';

class SmartAnalysisScreen extends StatefulWidget {
  const SmartAnalysisScreen({super.key});

  @override
  State<SmartAnalysisScreen> createState() => _SmartAnalysisScreenState();
}

class _SmartAnalysisScreenState extends State<SmartAnalysisScreen> {
  final ScrollController _scrollController = ScrollController();
  final Set<int> _loadedWidgets = {0, 1}; // Load first 2 widgets immediately

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Lazy load widgets as user scrolls
    final scrollPercent = _scrollController.position.pixels / 
        (_scrollController.position.maxScrollExtent == 0 ? 1 : _scrollController.position.maxScrollExtent);
    
    if (scrollPercent > 0.1 && !_loadedWidgets.contains(2)) {
      setState(() => _loadedWidgets.add(2));
    }
    if (scrollPercent > 0.3 && !_loadedWidgets.contains(3)) {
      setState(() => _loadedWidgets.add(3));
    }
    if (scrollPercent > 0.5 && !_loadedWidgets.contains(4)) {
      setState(() => _loadedWidgets.add(4));
    }
    if (scrollPercent > 0.7 && !_loadedWidgets.contains(5)) {
      setState(() => _loadedWidgets.add(5));
    }
  }

  Widget _buildPlaceholder() {
    return Card(
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

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
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        cacheExtent: 500, // Cache more items
        children: [
          // Health Score - always loaded
          const HealthScoreWidget(),
          const SizedBox(height: 16),

          // Expense Prediction - always loaded
          const PredictionWidget(),
          const SizedBox(height: 16),

          // AI Insights - lazy
          if (_loadedWidgets.contains(2))
            const AIInsightsWidget()
          else
            _buildPlaceholder(),
          const SizedBox(height: 16),

          // Anomaly Detection - lazy
          if (_loadedWidgets.contains(3))
            const AnomalyAlertWidget()
          else
            _buildPlaceholder(),
          const SizedBox(height: 16),

          // Smart Budget - lazy
          if (_loadedWidgets.contains(4))
            const SmartBudgetWidget()
          else
            _buildPlaceholder(),
          const SizedBox(height: 16),

          // Savings Suggestions - lazy
          if (_loadedWidgets.contains(5))
            const SavingsSuggestionsWidget()
          else
            _buildPlaceholder(),
          const SizedBox(height: 32),
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
                icon: Icons.favorite,
                title: 'Health Score',
                description: 'Điểm sức khỏe tài chính (4 tiêu chí x 25 điểm)',
              ),
              SizedBox(height: 12),
              _FeatureInfo(
                icon: Icons.trending_up,
                title: 'Expense Prediction',
                description: 'Dự báo chi tiêu bằng Linear Regression',
              ),
              SizedBox(height: 12),
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
