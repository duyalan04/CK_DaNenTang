import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/main_screen.dart';
import '../screens/login_screen.dart';
import '../screens/add_transaction_screen.dart';
import '../screens/ocr_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/budgets_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/goals_screen.dart';
import '../screens/smart_analysis_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/voice_input_screen.dart';
import '../screens/recurring_screen.dart';
import '../screens/sms_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;
    final isLoginRoute = state.matchedLocation == '/login';

    if (!isLoggedIn && !isLoginRoute) return '/login';
    if (isLoggedIn && isLoginRoute) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/', builder: (context, state) => const MainScreen()),
    GoRoute(path: '/add', builder: (context, state) => const AddTransactionScreen()),
    GoRoute(path: '/ocr', builder: (context, state) => const OcrScreen()),
    GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
    GoRoute(path: '/budgets', builder: (context, state) => const BudgetsScreen()),
    GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
    GoRoute(path: '/goals', builder: (context, state) => const GoalsScreen()),
    GoRoute(path: '/smart', builder: (context, state) => const SmartAnalysisScreen()),
    GoRoute(path: '/transactions', builder: (context, state) => const TransactionsScreen()),
    GoRoute(path: '/voice', builder: (context, state) => const VoiceInputScreen()),
    GoRoute(path: '/recurring', builder: (context, state) => const RecurringScreen()),
    GoRoute(path: '/sms', builder: (context, state) => const SmsScreen()),
  ],
);

