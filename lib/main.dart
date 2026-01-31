import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'services/local_storage_service.dart';
import 'services/local_database_service.dart';
import 'services/frequency_tracker.dart';
import 'services/analytics_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Critical path only - parallel initialization of essential services
  await Future.wait([
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
    LocalStorageService.instance.initialize(), // Hive for frequency tracking
    LocalDatabaseService.instance.initialize(), // SQLite for notes
  ]);

  // Migrate data from Hive to Drift (one-time)
  await _migrateHiveToDrift();

  // Set system UI overlay style for dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.deepIndigo,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Launch app immediately with local data
  runApp(const NoteFlowApp());

  // Initialize remaining services in background
  _initializeBackgroundServices();
}

/// One-time migration from Hive cache to Drift SQLite
Future<void> _migrateHiveToDrift() async {
  final prefs = await SharedPreferences.getInstance();
  final migrated = prefs.getBool('drift_initialized') ?? false;
  
  if (migrated) return;
  
  try {
    // Get cached notes from Hive
    final cachedNotes = LocalStorageService.instance.getCachedNotes();
    
    if (cachedNotes.isNotEmpty) {
      debugPrint('Migrating ${cachedNotes.length} notes from Hive to Drift...');
      final imported = await LocalDatabaseService.instance.importNotes(cachedNotes);
      debugPrint('Migration complete: $imported notes imported');
    }
    
    await prefs.setBool('drift_initialized', true);
  } catch (e) {
    debugPrint('Migration error (will retry on next launch): $e');
    // Don't mark as complete so it retries next launch
  }
}

/// Initialize non-critical services in background after app launches
Future<void> _initializeBackgroundServices() async {
  try {
    // Run independent services in parallel
    await Future.wait([
      FrequencyTracker.instance.initialize(),
      AnalyticsService.instance.initialize(),
    ]);
    
    // Note: Supabase and Auth removed - local-first architecture
  } catch (e) {
    // Log error but don't block app - offline mode will work
    debugPrint('Background initialization error: $e');
  }
}

class NoteFlowApp extends StatefulWidget {
  const NoteFlowApp({super.key});

  @override
  State<NoteFlowApp> createState() => _NoteFlowAppState();
}

class _NoteFlowAppState extends State<NoteFlowApp> with WidgetsBindingObserver {
  bool _isDisposed = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeServices();
    super.dispose();
  }

  /// Safely dispose services only once
  void _disposeServices() {
    if (_isDisposed) return;
    _isDisposed = true;
    LocalStorageService.instance.dispose();
    AnalyticsService.instance.dispose();
    FrequencyTracker.instance.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // App is being terminated, cleanup resources
      _disposeServices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
