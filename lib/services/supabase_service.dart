import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/note_model.dart';
import 'analytics_service.dart';
import 'auth_service.dart';
import 'local_storage_service.dart';

/// Custom exception for authentication failures
class AuthenticationException implements Exception {
  final String message;
  AuthenticationException(this.message);
  
  @override
  String toString() => message;
}

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  SupabaseClient get _client => SupabaseConfig.client;
  static const String _notesTable = 'notes';
  
  /// Default timeout for Supabase operations
  static const Duration _timeout = Duration(seconds: 15);
  
  /// Maximum retry attempts for failed operations
  static const int _maxRetries = 3;
  
  /// Flag to prevent concurrent background syncs
  bool _isSyncing = false;
  
  /// Circuit breaker: consecutive sync failures before backing off
  int _consecutiveSyncFailures = 0;
  static const int _maxConsecutiveFailures = 3;
  DateTime? _circuitBreakerResetTime;

  String get _userId {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      throw AuthenticationException('User not authenticated. Please sign in again.');
    }
    return userId;
  }

  /// Retry wrapper for Supabase operations with exponential backoff
  Future<T> _withRetry<T>(Future<T> Function() operation, {int maxRetries = _maxRetries}) async {
    int attempt = 0;
    while (true) {
      try {
        attempt++;
        return await operation().timeout(_timeout);
      } on TimeoutException {
        if (attempt >= maxRetries) {
          throw Exception('Request timed out after $maxRetries attempts');
        }
        // Exponential backoff: 1s, 2s, 4s
        await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
      } on AuthenticationException {
        // Don't retry auth errors
        rethrow;
      } catch (e) {
        // Only retry on network-like errors
        if (attempt >= maxRetries || !_isRetryableError(e)) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
      }
    }
  }

  /// Check if error is retryable (network issues, timeouts)
  bool _isRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
           errorString.contains('timeout') ||
           errorString.contains('connection') ||
           errorString.contains('socket');
  }

  /// Create a new note
  /// Saves locally immediately (works offline)
  /// Syncs to Supabase in background
  Future<NoteModel> createNote(String? title, String content, List<String> tags) async {
    final note = NoteModel(
      userId: _userId,
      title: title,
      content: content,
      tags: tags,
    );
    
    // Save to local cache immediately
    await LocalStorageService.instance.saveNote(note);
    
    // Mark as pending BEFORE attempting sync (crash-safe)
    await LocalStorageService.instance.addPendingNoteId(note.id);
    
    // Try to sync to Supabase (don't block if offline)
    try {
      final result = await _withRetry(() async {
        final response = await _client
            .from(_notesTable)
            .insert(note.toInsertJson())
            .select()
            .single();

        return NoteModel.fromJson(response);
      });

      // Update local cache with server response (has server-generated ID if needed)
      await LocalStorageService.instance.saveNote(result);
      // Remove from pending list since sync succeeded
      await LocalStorageService.instance.removePendingNoteId(note.id);
      return result;
    } catch (e) {
      // If sync fails (offline), note is already in pending list (added before attempt)
      // Leave it there to be synced when back online
      debugPrint('Note saved locally, will sync when online: $e');
      return note;
    }
  }

  /// Fetch all notes for current user
  /// Loads from local cache immediately (works offline)
  /// Syncs with Supabase in background when online
  Future<List<NoteModel>> fetchNotes({bool forceRefresh = false}) async {
    // Always load from cache first for instant response
    final cachedNotes = LocalStorageService.instance.getCachedNotes();
    
    // If we have cached notes and not forcing refresh, return them immediately
    if (!forceRefresh && cachedNotes.isNotEmpty) {
      // Sync in background without blocking
      _syncNotesInBackground();
      return cachedNotes;
    }
    
    // If no cache or forcing refresh, try to fetch from Supabase
    try {
      final notes = await _withRetry(() async {
        final response = await _client
            .from(_notesTable)
            .select()
            .eq('user_id', _userId)
            .order('last_accessed', ascending: false);

        return (response as List<dynamic>)
            .map((json) => NoteModel.fromJson(json as Map<String, dynamic>))
            .toList();
      });
      
      // Save to local cache
      await LocalStorageService.instance.saveNotes(notes);
      return notes;
    } catch (e) {
      // If fetch fails (offline/error), return cached notes if available
      if (cachedNotes.isNotEmpty) {
        return cachedNotes;
      }
      // No cache and can't fetch - rethrow error
      rethrow;
    }
  }
  
  /// Sync notes in background without blocking UI
  /// Uses a flag to prevent concurrent sync operations
  void _syncNotesInBackground() {
    // Prevent concurrent syncs
    if (_isSyncing) return;
    
    // Circuit breaker: if too many recent failures, wait before retrying
    if (_circuitBreakerResetTime != null) {
      if (DateTime.now().isBefore(_circuitBreakerResetTime!)) {
        debugPrint('Circuit breaker active, skipping sync until $_circuitBreakerResetTime');
        return;
      }
      // Reset circuit breaker
      _circuitBreakerResetTime = null;
      _consecutiveSyncFailures = 0;
    }
    
    _isSyncing = true;
    
    _withRetry(() async {
      final response = await _client
          .from(_notesTable)
          .select()
          .eq('user_id', _userId)
          .order('last_accessed', ascending: false);

      final notes = (response as List<dynamic>)
          .map((json) => NoteModel.fromJson(json as Map<String, dynamic>))
          .toList();
      
      await LocalStorageService.instance.saveNotes(notes);
      
      // After syncing down, try to sync up any pending local changes
      await _syncPendingNotes();
      await _syncPendingUpdates();
      await _syncPendingDeletions();
      await _syncAnalytics();
      
      // Success - reset failure counter
      _consecutiveSyncFailures = 0;
    }).catchError((e) {
      // Track consecutive failures for circuit breaker
      _consecutiveSyncFailures++;
      if (_consecutiveSyncFailures >= _maxConsecutiveFailures) {
        // Back off for 30 seconds after repeated failures
        _circuitBreakerResetTime = DateTime.now().add(const Duration(seconds: 30));
        debugPrint('Circuit breaker triggered after $_consecutiveSyncFailures failures');
      }
      debugPrint('Background sync failed: $e');
    }).whenComplete(() {
      _isSyncing = false;
    });
  }

  /// Sync pending notes that were created offline
  Future<void> _syncPendingNotes() async {
    final pendingNotes = LocalStorageService.instance.getPendingNotes();
    if (pendingNotes.isEmpty) return;
    
    debugPrint('Syncing ${pendingNotes.length} pending notes to server...');
    
    for (final note in pendingNotes) {
      try {
        // Try to insert the note to Supabase
        await _client
            .from(_notesTable)
            .insert(note.toInsertJson())
            .select()
            .single();
        
        // Success! Remove from pending list
        await LocalStorageService.instance.removePendingNoteId(note.id);
        debugPrint('Synced pending note ${note.id}');
      } catch (e) {
        // If sync fails, leave in pending list for next attempt
        debugPrint('Failed to sync pending note ${note.id}: $e');
      }
    }
  }

  /// Sync pending updates that were made offline
  Future<void> _syncPendingUpdates() async {
    final pendingUpdates = LocalStorageService.instance.getPendingUpdates();
    if (pendingUpdates.isEmpty) return;
    
    debugPrint('Syncing ${pendingUpdates.length} pending updates to server...');
    
    for (final note in pendingUpdates) {
      try {
        // Check if server version is newer (conflict detection)
        final serverResponse = await _client
            .from(_notesTable)
            .select('last_edited')
            .eq('id', note.id)
            .eq('user_id', _userId)
            .maybeSingle();
        
        if (serverResponse != null) {
          final serverLastEdited = DateTime.parse(serverResponse['last_edited'] as String);
          // Only push update if local is newer or equal (within 1 second tolerance)
          if (note.lastEdited.isBefore(serverLastEdited.subtract(const Duration(seconds: 1)))) {
            // Server has newer version - don't overwrite, fetch server version instead
            debugPrint('Conflict detected for ${note.id}: server is newer, skipping local update');
            await LocalStorageService.instance.removePendingUpdateId(note.id);
            continue;
          }
        }
        
        await _client
            .from(_notesTable)
            .update({
              'title': note.title,
              'content': note.content,
              'tags': note.tags,
              'last_accessed': note.lastAccessed.toIso8601String(),
              'last_edited': note.lastEdited.toIso8601String(),
            })
            .eq('id', note.id)
            .eq('user_id', _userId);
        
        // Success! Remove from pending list
        await LocalStorageService.instance.removePendingUpdateId(note.id);
        debugPrint('Synced pending update ${note.id}');
      } catch (e) {
        // If sync fails, leave in pending list for next attempt
        debugPrint('Failed to sync pending update ${note.id}: $e');
      }
    }
  }

  /// Sync pending deletions that were made offline
  Future<void> _syncPendingDeletions() async {
    final pendingDeleteIds = LocalStorageService.instance.getPendingDeleteIds();
    if (pendingDeleteIds.isEmpty) return;
    
    debugPrint('Syncing ${pendingDeleteIds.length} pending deletions to server...');
    
    for (final noteId in pendingDeleteIds) {
      try {
        await _client
            .from(_notesTable)
            .delete()
            .eq('id', noteId)
            .eq('user_id', _userId);
        
        // Success! Remove from pending list
        await LocalStorageService.instance.removePendingDeleteId(noteId);
        debugPrint('Synced pending deletion $noteId');
      } catch (e) {
        // If sync fails, leave in pending list for next attempt
        debugPrint('Failed to sync pending deletion $noteId: $e');
      }
    }
  }

  /// Sync analytics events (tag corrections)
  Future<void> _syncAnalytics() async {
    try {
      final syncedCount = await AnalyticsService.instance.syncToSupabase();
      if (syncedCount > 0) {
        debugPrint('Synced $syncedCount analytics events');
      }
    } catch (e) {
      debugPrint('Failed to sync analytics: $e');
    }
  }

  /// Fetch notes by category
  Future<List<NoteModel>> fetchNotesByCategory(NoteCategory category) async {
    final allNotes = await fetchNotes();
    return allNotes.where((note) => note.category == category).toList();
  }

  /// Update a note (content, tags, timestamps only - frequency managed separately)
  /// Updates locally immediately (works offline)
  /// Syncs to Supabase in background
  Future<NoteModel> updateNote(NoteModel note) async {
    // Save to local cache immediately
    await LocalStorageService.instance.saveNote(note);
    
    // Mark as pending update BEFORE attempting sync (crash-safe)
    await LocalStorageService.instance.addPendingUpdateId(note.id);
    
    // Try to sync to Supabase
    try {
      final result = await _withRetry(() async {
        final response = await _client
            .from(_notesTable)
            .update({
              'title': note.title,
              'content': note.content,
              'tags': note.tags,
              'last_accessed': note.lastAccessed.toIso8601String(),
              'last_edited': note.lastEdited.toIso8601String(),
            })
            .eq('id', note.id)
            .eq('user_id', _userId)
            .select()
            .single();

        return NoteModel.fromJson(response);
      });
      
      await LocalStorageService.instance.saveNote(result);
      // Remove from pending updates since sync succeeded
      await LocalStorageService.instance.removePendingUpdateId(note.id);
      return result;
    } catch (e) {
      // If sync fails, note is already in pending list (added before attempt)
      debugPrint('Note updated locally, will sync when online: $e');
      return note;
    }
  }

  /// Update frequency count and last accessed
  Future<NoteModel> updateFrequency(String noteId) async {
    return _withRetry(() async {
      // First get current note - use maybeSingle to handle deleted notes
      final currentResponse = await _client
          .from(_notesTable)
          .select()
          .eq('id', noteId)
          .eq('user_id', _userId)
          .maybeSingle();

      // Note might have been deleted between opening and tracking
      if (currentResponse == null) {
        throw Exception('Note not found - may have been deleted');
      }

      final currentNote = NoteModel.fromJson(currentResponse);

      // Update with incremented count
      final response = await _client
          .from(_notesTable)
          .update({
            'frequency_count': currentNote.frequencyCount + 1,
            'last_accessed': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', noteId)
          .eq('user_id', _userId)
          .select()
          .single();

      final updatedNote = NoteModel.fromJson(response);
      
      // Update local cache with new frequency count
      await LocalStorageService.instance.saveNote(updatedNote);
      
      return updatedNote;
    });
  }

  /// Delete a note
  /// Deletes locally immediately (works offline)
  /// Syncs to Supabase in background
  Future<void> deleteNote(String noteId) async {
    // Delete from local cache immediately
    await LocalStorageService.instance.deleteNoteFromCache(noteId);
    
    // Remove from pending creates/updates since we're deleting
    await LocalStorageService.instance.removePendingNoteId(noteId);
    await LocalStorageService.instance.removePendingUpdateId(noteId);
    
    // Mark as pending delete BEFORE attempting sync (crash-safe)
    await LocalStorageService.instance.addPendingDeleteId(noteId);
    
    // Try to sync deletion to Supabase
    try {
      await _withRetry(() async {
        await _client
            .from(_notesTable)
            .delete()
            .eq('id', noteId)
            .eq('user_id', _userId);
      });
      // Success - remove from pending deletes
      await LocalStorageService.instance.removePendingDeleteId(noteId);
    } catch (e) {
      // If sync fails, note is already in pending list (added before attempt)
      debugPrint('Note deleted locally, will sync when online: $e');
    }
  }

  /// Batch delete notes with progress callback
  /// Returns a list of failed note IDs (if any)
  /// Throws if network is offline or auth expired (checked upfront)
  Future<List<String>> batchDeleteNotes(
    List<String> noteIds, {
    void Function(int current, int total)? onProgress,
  }) async {
    if (noteIds.isEmpty) return [];

    // Check auth upfront
    final userId = _userId; // This throws if not authenticated
    
    // Check network connectivity by making a simple query
    try {
      await _client.from(_notesTable).select('id').limit(1).timeout(
        const Duration(seconds: 5),
      );
    } on TimeoutException {
      throw Exception('Network appears to be offline. Please check your connection.');
    } catch (e) {
      if (e.toString().contains('network') || 
          e.toString().contains('connection') ||
          e.toString().contains('socket')) {
        throw Exception('Network appears to be offline. Please check your connection.');
      }
      // Auth errors should be rethrown
      if (e is AuthenticationException) rethrow;
    }

    final failedIds = <String>[];
    
    for (int i = 0; i < noteIds.length; i++) {
      final noteId = noteIds[i];
      
      try {
        // Delete from server
        await _client
            .from(_notesTable)
            .delete()
            .eq('id', noteId)
            .eq('user_id', userId);
        
        // Success - also delete from local cache and clean up pending lists
        await LocalStorageService.instance.deleteNoteFromCache(noteId);
        await LocalStorageService.instance.removePendingNoteId(noteId);
        await LocalStorageService.instance.removePendingUpdateId(noteId);
        await LocalStorageService.instance.removePendingDeleteId(noteId);
      } catch (e) {
        // Log the error and continue with remaining notes
        failedIds.add(noteId);
        debugPrint('ERROR: Failed to delete note $noteId: $e');
      }
      
      // Report progress
      onProgress?.call(i + 1, noteIds.length);
    }
    
    return failedIds;
  }

  /// Search notes by content
  /// Searches local cache (works offline)
  Future<List<NoteModel>> searchNotes(String query) async {
    if (query.isEmpty) {
      return fetchNotes();
    }

    // Search in local cache
    final allNotes = LocalStorageService.instance.getCachedNotes();
    final searchLower = query.toLowerCase();
    
    return allNotes.where((note) {
      return note.content.toLowerCase().contains(searchLower) ||
             (note.title?.toLowerCase().contains(searchLower) ?? false) ||
             note.tags.any((tag) => tag.toLowerCase().contains(searchLower));
    }).toList();
  }
}
