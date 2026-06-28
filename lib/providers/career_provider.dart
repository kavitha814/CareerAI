import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:careerpilot_ai/repositories/career_repository.dart';
import 'package:careerpilot_ai/repositories/hive_career_repository.dart';
import 'package:careerpilot_ai/repositories/firebase_career_repository.dart';
import 'package:careerpilot_ai/models/roadmap.dart';
import 'package:careerpilot_ai/providers/auth_provider.dart';

final careerRepositoryProvider = Provider<CareerRepository>((ref) {
  if (Firebase.apps.isNotEmpty) {
    return FirebaseCareerRepository();
  } else {
    // Note: The Hive boxes must be initialized in main before usage.
    return HiveCareerRepository();
  }
});

final activeRoadmapIdProvider = StateProvider<String?>((ref) => null);
final chatPromptProvider = StateProvider<String?>((ref) => null);

final roadmapsListProvider = FutureProvider<List<CareerRoadmap>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  final repo = ref.watch(careerRepositoryProvider);
  return repo.getRoadmaps(user.id);
});

final activeRoadmapProvider = FutureProvider<CareerRoadmap?>((ref) async {
  final user = ref.watch(authProvider).user;
  final activeId = ref.watch(activeRoadmapIdProvider);
  if (user == null || activeId == null) return null;
  final repo = ref.watch(careerRepositoryProvider);
  return repo.getRoadmapById(user.id, activeId);
});
