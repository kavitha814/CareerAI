import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:careerpilot_ai/providers/auth_provider.dart';

import 'package:careerpilot_ai/features/onboarding/presentation/splash_screen.dart';
import 'package:careerpilot_ai/features/onboarding/presentation/onboarding_screen.dart';
import 'package:careerpilot_ai/features/authentication/presentation/login_screen.dart';
import 'package:careerpilot_ai/features/dashboard/presentation/dashboard_screen.dart';
import 'package:careerpilot_ai/features/ai_chat/presentation/ai_chat_screen.dart';
import 'package:careerpilot_ai/features/roadmap/presentation/roadmap_screen.dart';
import 'package:careerpilot_ai/features/profile/presentation/profile_screen.dart';
import 'package:careerpilot_ai/features/settings/presentation/settings_screen.dart';
import 'package:careerpilot_ai/features/dashboard/presentation/main_navigation_screen.dart';
import 'package:careerpilot_ai/features/roadmap/presentation/roadmaps_list_screen.dart';

/// Notifier to bridge Riverpod auth states with GoRouter's refreshListenable
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    // Listen to changes in the authProvider state and trigger refresh
    _ref.listen<AuthState>(
      authProvider,
      (previous, next) {
        notifyListeners();
      },
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ref.read(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: routerNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoading = authState.isLoading;
      final isLoggedIn = authState.user != null;
      final onboardingCompleted = authState.onboardingCompleted;

      final subLocation = state.uri.path;

      // 1. While auth state is initializing, stay on splash screen
      if (isLoading) {
        return subLocation == '/' ? null : '/';
      }

      // 2. If user is NOT logged in
      if (!isLoggedIn) {
        // Allow being on the login screen, redirect all other requests to /login
        if (subLocation == '/login') {
          return null;
        }
        return '/login';
      }

      // 3. If user IS logged in but onboarding is not completed
      if (!onboardingCompleted) {
        // Allow being on onboarding, redirect all other requests to /onboarding
        if (subLocation == '/onboarding') {
          return null;
        }
        return '/onboarding';
      }

      // 4. If user IS logged in and onboarding is completed
      // If they are on guest routes (Splash, Login, Onboarding), send them to dashboard
      if (subLocation == '/' || subLocation == '/login' || subLocation == '/onboarding') {
        return '/dashboard';
      }

      // Allow access to the target sub-location
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/roadmaps',
                builder: (context, state) => const RoadmapsListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const AiChatScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/roadmap/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return RoadmapScreen(roadmapId: id);
        },
      ),
    ],
  );
});
