import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception thrown when Supabase configuration is invalid
class SupabaseConfigException implements Exception {
  final String message;
  SupabaseConfigException(this.message);

  @override
  String toString() => 'SupabaseConfigException: $message';
}

class SupabaseConfig {
  static String get supabaseUrl {
    // Check for dart-define override first (for environment switching)
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    
    // Fall back to .env file
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw SupabaseConfigException(
        'SUPABASE_URL is not configured in .env file or --dart-define',
      );
    }
    return url;
  }

  static String get supabaseKey {
    // Check for dart-define override first (for environment switching)
    const envKey = String.fromEnvironment('SUPABASE_KEY');
    if (envKey.isNotEmpty) {
      return envKey;
    }
    
    // Fall back to .env file
    final key = dotenv.env['SUPABASE_KEY'];
    if (key == null || key.isEmpty) {
      throw SupabaseConfigException(
        'SUPABASE_KEY is not configured in .env file or --dart-define',
      );
    }
    return key;
  }

  static String get environment {
    const env = String.fromEnvironment('ENV', defaultValue: 'dev');
    return env;
  }

  static Future<void> initialize() async {
    // Validate config before initializing
    final url = supabaseUrl;
    final key = supabaseKey;

    print('🔧 Initializing Supabase in ${environment.toUpperCase()} environment');
    print('🔗 URL: $url');

    await Supabase.initialize(url: url, anonKey: key);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
