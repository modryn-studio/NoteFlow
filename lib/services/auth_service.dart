import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  AuthService._();

  SupabaseClient get _client => SupabaseConfig.client;

  /// Get current user
  User? get currentUser => _client.auth.currentUser;

  /// Get current user ID
  String? get currentUserId => currentUser?.id;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Sign in anonymously
  Future<AuthResponse> signInAnonymously() async {
    try {
      final response = await _client.auth.signInAnonymously();
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Ensure user is authenticated (auto sign-in if needed)
  Future<User?> ensureAuthenticated() async {
    if (isAuthenticated) {
      return currentUser;
    }

    // Try to restore session
    final session = _client.auth.currentSession;
    if (session != null) {
      return currentUser;
    }

    // Sign in anonymously
    final response = await signInAnonymously();
    return response.user;
  }
}
