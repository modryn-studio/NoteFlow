import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing local storage using Hive and SharedPreferences
class LocalStorageService {
  static LocalStorageService? _instance;
  static LocalStorageService get instance =>
      _instance ??= LocalStorageService._();

  LocalStorageService._();

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  /// Initialize local storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize Hive
    await Hive.initFlutter();

    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();

    _isInitialized = true;
  }

  // ============ SharedPreferences Methods ============

  /// Get string value
  String? getString(String key) => _prefs?.getString(key);

  /// Set string value
  Future<bool> setString(String key, String value) async {
    return await _prefs?.setString(key, value) ?? false;
  }

  /// Get bool value
  bool? getBool(String key) => _prefs?.getBool(key);

  /// Set bool value
  Future<bool> setBool(String key, bool value) async {
    return await _prefs?.setBool(key, value) ?? false;
  }

  /// Get int value
  int? getInt(String key) => _prefs?.getInt(key);

  /// Set int value
  Future<bool> setInt(String key, int value) async {
    return await _prefs?.setInt(key, value) ?? false;
  }

  /// Remove a key
  Future<bool> remove(String key) async {
    return await _prefs?.remove(key) ?? false;
  }

  /// Clear all preferences
  Future<bool> clearPreferences() async {
    return await _prefs?.clear() ?? false;
  }

  // ============ App-specific keys ============

  static const String keyFirstLaunch = 'first_launch';
  static const String keyLastSync = 'last_sync';
  static const String keyUserId = 'user_id';

  /// Check if first launch
  bool get isFirstLaunch => getBool(keyFirstLaunch) ?? true;

  /// Mark first launch complete
  Future<void> markFirstLaunchComplete() async {
    await setBool(keyFirstLaunch, false);
  }

  /// Get last sync time
  DateTime? get lastSyncTime {
    final timestamp = getInt(keyLastSync);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  /// Update last sync time
  Future<void> updateLastSyncTime() async {
    await setInt(keyLastSync, DateTime.now().millisecondsSinceEpoch);
  }

  /// Store user ID locally
  Future<void> storeUserId(String userId) async {
    await setString(keyUserId, userId);
  }

  /// Get stored user ID
  String? get storedUserId => getString(keyUserId);

  /// Close all Hive boxes and cleanup resources
  /// Should be called when app is terminating
  Future<void> dispose() async {
    await Hive.close();
  }
}
