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

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
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

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize local storage service (also initializes Hive)
  await LocalStorageService.instance.initialize();

  // Initialize frequency tracker
  await FrequencyTracker.instance.initialize();

  // Initialize analytics service
  await AnalyticsService.instance.initialize();

  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Ensure user is authenticated
  await AuthService.instance.ensureAuthenticated();

  runApp(const NoteFlowApp());
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
