import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screen.dart';
import '../features/discussion/discussion_screen.dart';
import '../features/home/home_screen.dart';
import '../features/morning/morning_screen.dart';
import '../features/reflection/reflection_screen.dart';
import '../features/tomorrow_plan/tomorrow_plan_screen.dart';
import 'auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final loggedIn = auth.asData?.value != null;
      final onAuth = state.matchedLocation == '/auth';
      if (!loggedIn && !onAuth) return '/auth';
      if (loggedIn && onAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/reflection',
        builder: (context, state) => const ReflectionScreen(),
      ),
      GoRoute(
        path: '/discussion/:sessionId',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return DiscussionScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/plan/:sessionId',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return TomorrowPlanScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/morning',
        builder: (context, state) => const MorningScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('ページが見つかりません: ${state.error}')),
    ),
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _ref.listen<AsyncValue<User?>>(authStateProvider, (_, _) {
      notifyListeners();
    });
  }

  final Ref _ref;
}
