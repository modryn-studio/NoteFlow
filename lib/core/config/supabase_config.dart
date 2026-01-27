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
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw SupabaseConfigException(
        'SUPABASE_URL is not configured in .env file',
      );
    }
    return url;
  }

  static String get supabaseKey {
    final key = dotenv.env['SUPABASE_KEY'];
    if (key == null || key.isEmpty) {
      throw SupabaseConfigException(
        'SUPABASE_KEY is not configured in .env file',
      );
    }
    return key;
  }

  static Future<void> initialize() async {
    // Validate config before initializing
    final url = supabaseUrl;
    final key = supabaseKey;

    await Supabase.initialize(url: url, anonKey: key);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
