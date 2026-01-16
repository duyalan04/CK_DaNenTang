import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/add_transaction_screen.dart';
import '../screens/ocr_screen.dart';
import '../screens/chat_screen.dart';

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
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/add', builder: (context, state) => const AddTransactionScreen()),
    GoRoute(path: '/ocr', builder: (context, state) => const OcrScreen()),
    GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
  ],
);

