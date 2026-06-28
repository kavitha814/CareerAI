import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logging/logging.dart';
import 'package:careerpilot_ai/core/theme/app_theme.dart';
import 'package:careerpilot_ai/core/router/app_router.dart';
import 'package:careerpilot_ai/providers/theme_provider.dart';
import 'package:careerpilot_ai/repositories/hive_career_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up genui logging listener
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('[GENUI] ${record.level.name}: ${record.message}');
    if (record.error != null) {
      debugPrint('[GENUI] Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      debugPrint('[GENUI] StackTrace: ${record.stackTrace}');
    }
  });
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Try initializing Firebase
  try {
    // We wrap this to catch missing Firebase configuration files
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase could not initialize: $e');
    debugPrint('CareerPilot AI will run in offline/local mock database mode.');
  }

  // Set up local Hive boxes
  final hiveRepo = HiveCareerRepository();
  await hiveRepo.init();

  runApp(
    const ProviderScope(
      child: CareerPilotApp(),
    ),
  );
}

class CareerPilotApp extends ConsumerWidget {
  const CareerPilotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'CareerPilot AI',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
