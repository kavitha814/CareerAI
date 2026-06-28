import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:careerpilot_ai/models/user_profile.dart';
import 'package:careerpilot_ai/providers/career_provider.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthState {
  final UserProfile? user;
  final bool isLoading;
  final bool onboardingCompleted;
  final String? errorMessage;

  AuthState({
    this.user,
    this.isLoading = false,
    this.onboardingCompleted = false,
    this.errorMessage,
  });

  AuthState copyWith({
    UserProfile? user,
    bool? isLoading,
    bool? onboardingCompleted,
    String? errorMessage,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  static const String _settingsBoxName = 'settings_box';
  static const String _onboardingKey = 'onboarding_completed';

  AuthNotifier(this._ref) : super(AuthState(isLoading: true)) {
    _initAuth();
  }

  Future<void> _initAuth() async {
    final box = await Hive.openBox(_settingsBoxName);
    final onboardingCompleted = box.get(_onboardingKey, defaultValue: false) as bool;

    if (Firebase.apps.isEmpty) {
      // Offline / Local / Mock Mode
      final savedUser = await _ref.read(careerRepositoryProvider).getUserProfile('guest_user');
      state = AuthState(
        user: savedUser,
        isLoading: false,
        onboardingCompleted: onboardingCompleted,
      );
      return;
    }

    // Firebase Mode
    fb_auth.FirebaseAuth.instance.authStateChanges().listen((fbUser) async {
      if (fbUser == null) {
        state = AuthState(
          user: null,
          isLoading: false,
          onboardingCompleted: onboardingCompleted,
        );
      } else {
        final repo = _ref.read(careerRepositoryProvider);
        var profile = await repo.getUserProfile(fbUser.uid);
        if (profile == null) {
          profile = UserProfile(
            id: fbUser.uid,
            email: fbUser.email ?? 'user@careerpilot.ai',
            displayName: fbUser.displayName ?? fbUser.email?.split('@').first ?? 'Career Pilot',
            currentSkills: [],
            targetSkills: [],
            streak: 1,
            roadmapsCompleted: 0,
            certificatesCount: 0,
            aiUsageCount: 0,
            age: 18,
            preferredLanguages: ['English'],
          );
          await repo.saveUserProfile(profile);
        }
        state = AuthState(
          user: profile,
          isLoading: false,
          onboardingCompleted: onboardingCompleted,
        );
      }
    });
  }

  Future<void> completeOnboarding() async {
    final box = Hive.box(_settingsBoxName);
    await box.put(_onboardingKey, true);
    state = state.copyWith(onboardingCompleted: true);
  }

  Future<void> loginAsGuest() async {
    state = state.copyWith(isLoading: true);
    final repo = _ref.read(careerRepositoryProvider);
    
    // Create or retrieve guest user profile
    var guestProfile = await repo.getUserProfile('guest_user');
    if (guestProfile == null) {
      guestProfile = UserProfile(
        id: 'guest_user',
        email: 'guest@careerpilot.ai',
        displayName: 'Guest Pilot',
        currentSkills: ['HTML', 'CSS', 'Basic Programming'],
        targetSkills: ['Flutter', 'Dart', 'Clean Architecture'],
        streak: 1,
        roadmapsCompleted: 0,
        certificatesCount: 0,
        aiUsageCount: 1,
        isGuest: true,
        age: 22,
        preferredLanguages: ['English'],
      );
      await repo.saveUserProfile(guestProfile);
    }
    
    state = state.copyWith(
      user: guestProfile,
      isLoading: false,
    );
  }

  Future<void> loginWithEmail(
    String email,
    String password, {
    required bool isRegistering,
    String? displayName,
    int? age,
    List<String>? preferredLanguages,
  }) async {
    state = state.copyWith(isLoading: true);
    
    if (Firebase.apps.isEmpty) {
      // Mock email login
      final profile = UserProfile(
        id: 'mock_${email.hashCode}',
        email: email,
        displayName: displayName ?? email.split('@').first,
        currentSkills: ['Dart', 'Widgets'],
        targetSkills: ['Flutter Architect'],
        streak: 3,
        roadmapsCompleted: 1,
        certificatesCount: 1,
        aiUsageCount: 5,
        age: age ?? 18,
        preferredLanguages: preferredLanguages ?? ['English'],
      );
      await _ref.read(careerRepositoryProvider).saveUserProfile(profile);
      state = state.copyWith(user: profile, isLoading: false);
      return;
    }

    try {
      if (isRegistering) {
        final userCredential = await fb_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
        final fbUser = userCredential.user;
        if (fbUser != null) {
          final profile = UserProfile(
            id: fbUser.uid,
            email: fbUser.email ?? email,
            displayName: displayName ?? fbUser.displayName ?? fbUser.email?.split('@').first ?? 'Career Pilot',
            currentSkills: [],
            targetSkills: [],
            streak: 1,
            roadmapsCompleted: 0,
            certificatesCount: 0,
            aiUsageCount: 0,
            age: age ?? 18,
            preferredLanguages: preferredLanguages ?? ['English'],
          );
          await _ref.read(careerRepositoryProvider).saveUserProfile(profile);
        }
      } else {
        await fb_auth.FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Authentication error',
      );
    }
  }

  Future<void> loginWithGoogle() async {
    // If offline, just login as Guest
    if (Firebase.apps.isEmpty) {
      await loginAsGuest();
      return;
    }
    // Implement Google Sign-In placeholder or logic
    // Since Google Sign-In requires external configurations, in standard debug mode we can bypass it.
    await loginAsGuest();
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    if (Firebase.apps.isNotEmpty) {
      await fb_auth.FirebaseAuth.instance.signOut();
    }
    state = state.copyWith(
      isLoading: false,
      clearUser: true,
    );
  }

  // Update user skills or properties
  Future<void> updateUserProfile(UserProfile updatedProfile) async {
    await _ref.read(careerRepositoryProvider).saveUserProfile(updatedProfile);
    state = state.copyWith(user: updatedProfile);
  }
}
