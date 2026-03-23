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
import '../features/reservations/presentation/screens/reservation_screen.dart';
import '../features/reservations/presentation/screens/my_reservations_screen.dart';
import '../features/wallet/presentation/screens/transaction_history_screen.dart';
import '../features/wallet/presentation/screens/wallet_screen.dart';
import '../features/profile/presentation/screens/profile_setup_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/providers/profile_provider.dart';

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
  static const reserve = '/reserve';
  static const myReservations = '/my-reservations';
  static const profileSetup = '/profile-setup';
  static const profile = '/profile';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final profileAsync = ref.watch(profileProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      if (authState.isLoading || profileAsync.isLoading) return null;

      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final hasProfile = profileAsync.valueOrNull != null;

      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup ||
          state.matchedLocation == AppRoutes.splash;

      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;

      // If logged in
      if (isLoggedIn) {
        // 1. If no profile and not on setup page, go to setup
        if (!hasProfile && state.matchedLocation != AppRoutes.profileSetup) {
          return AppRoutes.profileSetup;
        }

        // 2. If has profile and on setup page or auth routes, go to map
        if (hasProfile && (state.matchedLocation == AppRoutes.profileSetup || isAuthRoute)) {
          return AppRoutes.map;
        }
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
      GoRoute(
        path: AppRoutes.reserve,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ReservationScreen(
            stationId: extra['stationId'],
            stationName: extra['stationName'],
            connectorId: extra['connectorId'],
            connectorType: extra['connectorType'],
            pricePerKwh: extra['pricePerKwh'],
          );
        },
      ),
      GoRoute(
        path: AppRoutes.myReservations,
        builder: (context, state) => const MyReservationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
