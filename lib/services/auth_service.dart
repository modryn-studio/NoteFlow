import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import 'local_storage_service.dart';

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
      
      // Store user ID locally to prevent creating duplicate users
      if (response.user != null) {
        await LocalStorageService.instance.storeUserId(response.user!.id);
        debugPrint('Created new anonymous user: ${response.user!.id}');
      }
      
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
    // Clear stored user ID
    await LocalStorageService.instance.remove(LocalStorageService.keyUserId);
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Ensure user is authenticated (auto sign-in if needed)
  Future<User?> ensureAuthenticated() async {
    // Check if already authenticated
    if (isAuthenticated) {
      debugPrint('User already authenticated: ${currentUser!.id}');
      return currentUser;
    }

    // Try to restore session from Supabase storage
    final session = _client.auth.currentSession;
    if (session != null) {
      debugPrint('Session restored for user: ${session.user.id}');
      return session.user;
    }

    // Check if we have a stored user ID (prevents creating duplicates)
    final storedUserId = LocalStorageService.instance.storedUserId;
    if (storedUserId != null) {
      debugPrint('⚠️ WARNING: User ID exists ($storedUserId) but session lost!');
      debugPrint('This means the user was logged out. Creating new anonymous user...');
      // Session was lost but we had a user before
      // In production, you might want to show a "session expired" message
      // For now, we'll create a new user (data is still in Supabase for old user)
    }

    // No existing session - sign in anonymously
    debugPrint('No existing session found, creating new anonymous user...');
    final response = await signInAnonymously();
    return response.user;
  }
}
