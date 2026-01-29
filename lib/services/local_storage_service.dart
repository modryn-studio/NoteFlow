import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_model.dart';

/// Service for managing local storage using Hive and SharedPreferences
class LocalStorageService {
  static LocalStorageService? _instance;
  static LocalStorageService get instance =>
      _instance ??= LocalStorageService._();

  LocalStorageService._();

  SharedPreferences? _prefs;
  Box<NoteModel>? _notesBox;
  bool _isInitialized = false;

  static const String _notesBoxName = 'notes_cache';

  /// Initialize local storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize Hive
    await Hive.initFlutter();

    // Register NoteModel adapter if not already registered
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(NoteModelAdapter());
    }

    // Open notes cache box
    _notesBox = await Hive.openBox<NoteModel>(_notesBoxName);

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
  static const String keyPendingNoteIds = 'pending_note_ids'; // Notes waiting to sync to server
  static const String keyPendingUpdateIds = 'pending_update_ids'; // Notes with edits waiting to sync
  static const String keyPendingDeleteIds = 'pending_delete_ids'; // Notes waiting to be deleted from server

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

  // ============ Notes Cache Methods ============

  /// Save notes to local cache
  /// Preserves notes that are pending sync (haven't been uploaded yet)
  Future<void> saveNotes(List<NoteModel> notes) async {
    // Get pending note IDs before clearing - these need to be preserved
    final pendingCreateIds = getPendingNoteIds();
    final pendingUpdateIds = getPendingUpdateIds();
    final pendingNotes = <String, NoteModel>{};
    
    // Save pending notes before clearing
    for (final id in [...pendingCreateIds, ...pendingUpdateIds]) {
      final note = getCachedNote(id);
      if (note != null) {
        pendingNotes[id] = note;
      }
    }
    
    // Clear and save server notes
    await _notesBox?.clear();
    for (final note in notes) {
      // Only save server version if we don't have pending local changes
      if (!pendingNotes.containsKey(note.id)) {
        await _notesBox?.put(note.id, note);
      }
    }
    
    // Restore pending notes (local changes take priority)
    for (final note in pendingNotes.values) {
      await _notesBox?.put(note.id, note);
    }
  }

  /// Get all cached notes
  List<NoteModel> getCachedNotes() {
    return _notesBox?.values.toList() ?? [];
  }

  /// Save single note to cache
  Future<void> saveNote(NoteModel note) async {
    await _notesBox?.put(note.id, note);
  }

  /// Delete note from cache
  Future<void> deleteNoteFromCache(String noteId) async {
    await _notesBox?.delete(noteId);
  }

  /// Get single note from cache
  NoteModel? getCachedNote(String noteId) {
    return _notesBox?.get(noteId);
  }

  /// Check if we have cached notes
  bool get hasCachedNotes => (_notesBox?.length ?? 0) > 0;

  // ============ Pending Notes Sync Tracking ============

  /// Get list of note IDs that are pending sync to server
  List<String> getPendingNoteIds() {
    final idsString = getString(keyPendingNoteIds);
    if (idsString == null || idsString.isEmpty) return [];
    return idsString.split(',');
  }

  /// Add a note ID to the pending sync list
  Future<void> addPendingNoteId(String noteId) async {
    final pending = getPendingNoteIds();
    if (!pending.contains(noteId)) {
      pending.add(noteId);
      await setString(keyPendingNoteIds, pending.join(','));
    }
  }

  /// Remove a note ID from the pending sync list (after successful sync)
  Future<void> removePendingNoteId(String noteId) async {
    final pending = getPendingNoteIds();
    pending.remove(noteId);
    await setString(keyPendingNoteIds, pending.join(','));
  }

  /// Get all pending notes that need to be synced
  List<NoteModel> getPendingNotes() {
    final pendingIds = getPendingNoteIds();
    final notes = <NoteModel>[];
    for (final id in pendingIds) {
      final note = getCachedNote(id);
      if (note != null) {
        notes.add(note);
      }
    }
    return notes;
  }

  // ============ Pending Updates Tracking ============

  /// Get list of note IDs that have pending updates
  List<String> getPendingUpdateIds() {
    final idsString = getString(keyPendingUpdateIds);
    if (idsString == null || idsString.isEmpty) return [];
    return idsString.split(',');
  }

  /// Add a note ID to the pending updates list
  Future<void> addPendingUpdateId(String noteId) async {
    final pending = getPendingUpdateIds();
    if (!pending.contains(noteId)) {
      pending.add(noteId);
      await setString(keyPendingUpdateIds, pending.join(','));
    }
  }

  /// Remove a note ID from the pending updates list
  Future<void> removePendingUpdateId(String noteId) async {
    final pending = getPendingUpdateIds();
    pending.remove(noteId);
    await setString(keyPendingUpdateIds, pending.join(','));
  }

  /// Get all notes with pending updates
  List<NoteModel> getPendingUpdates() {
    final pendingIds = getPendingUpdateIds();
    final notes = <NoteModel>[];
    for (final id in pendingIds) {
      final note = getCachedNote(id);
      if (note != null) {
        notes.add(note);
      }
    }
    return notes;
  }

  // ============ Pending Deletions Tracking ============

  /// Get list of note IDs that are pending deletion from server
  List<String> getPendingDeleteIds() {
    final idsString = getString(keyPendingDeleteIds);
    if (idsString == null || idsString.isEmpty) return [];
    return idsString.split(',');
  }

  /// Add a note ID to the pending deletions list
  Future<void> addPendingDeleteId(String noteId) async {
    final pending = getPendingDeleteIds();
    if (!pending.contains(noteId)) {
      pending.add(noteId);
      await setString(keyPendingDeleteIds, pending.join(','));
    }
  }

  /// Remove a note ID from the pending deletions list
  Future<void> removePendingDeleteId(String noteId) async {
    final pending = getPendingDeleteIds();
    pending.remove(noteId);
    await setString(keyPendingDeleteIds, pending.join(','));
  }

  /// Close all Hive boxes and cleanup resources
  /// Should be called when app is terminating
  Future<void> dispose() async {
    await Hive.close();
  }
}
