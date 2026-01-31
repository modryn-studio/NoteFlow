import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'services/local_storage_service.dart';
import 'services/frequency_tracker.dart';
import 'services/analytics_service.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Critical path only - parallel initialization of essential services
  await Future.wait([
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
    dotenv.load(fileName: '.env'),
    LocalStorageService.instance.initialize(), // Need this for cached notes
  ]);

  // Set system UI overlay style for dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.deepIndigo,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Launch app immediately with cached data
  runApp(const NoteFlowApp());

  // Initialize remaining services in background
  _initializeBackgroundServices();
}

/// Initialize non-critical services in background after app launches
Future<void> _initializeBackgroundServices() async {
  try {
    // Run independent services in parallel
    await Future.wait([
      FrequencyTracker.instance.initialize(),
      AnalyticsService.instance.initialize(),
      SupabaseConfig.initialize(),
    ]);

    // Authenticate user (requires Supabase to be initialized first)
    await AuthService.instance.ensureAuthenticated();
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
