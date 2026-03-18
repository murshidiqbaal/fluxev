import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/signup_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/charging_session/presentation/screens/charging_session_screen.dart';
import '../features/charging_session/presentation/screens/qr_scanner_screen.dart';
import '../features/map/presentation/screens/map_screen.dart';
import '../features/reviews/presentation/screens/reviews_screen.dart';
import '../features/stations/presentation/screens/station_detail_screen.dart';
import '../features/wallet/presentation/screens/transaction_history_screen.dart';
import '../features/wallet/presentation/screens/wallet_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const map = '/map';
  static const stationDetail = '/station/:id';
  static const qrScanner = '/scan';
  static const chargingSession = '/session/:sessionId';
  static const wallet = '/wallet';
  static const transactionHistory = '/wallet/history';
  static const reviews = '/station/:id/reviews';
  static const adminDashboard = '/admin';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      // Don't redirect while checking auth state
      if (authState.isLoading) return null;

      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup ||
          state.matchedLocation == AppRoutes.splash;

      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;

      // If logged in and on login/signup, go to map
      if (isLoggedIn &&
          (state.matchedLocation == AppRoutes.login ||
              state.matchedLocation == AppRoutes.signup)) {
        return AppRoutes.map;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.map,
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: AppRoutes.stationDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return StationDetailScreen(stationId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.qrScanner,
        builder: (context, state) => const QrScannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.chargingSession,
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return ChargingSessionScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: AppRoutes.wallet,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: AppRoutes.transactionHistory,
        builder: (context, state) => const TransactionHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.reviews,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReviewsScreen(stationId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
