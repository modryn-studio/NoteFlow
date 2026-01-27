import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/note_model.dart';
import 'auth_service.dart';

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
  Future<NoteModel> createNote(String content, List<String> tags) async {
    return _withRetry(() async {
      final note = NoteModel(
        userId: _userId,
        content: content,
        tags: tags,
      );

      final response = await _client
          .from(_notesTable)
          .insert(note.toInsertJson())
          .select()
          .single();

      return NoteModel.fromJson(response);
    });
  }

  /// Fetch all notes for current user
  Future<List<NoteModel>> fetchNotes() async {
    return _withRetry(() async {
      final response = await _client
          .from(_notesTable)
          .select()
          .eq('user_id', _userId)
          .order('last_accessed', ascending: false);

      return (response as List<dynamic>)
          .map((json) => NoteModel.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }

  /// Fetch notes by category
  Future<List<NoteModel>> fetchNotesByCategory(NoteCategory category) async {
    final allNotes = await fetchNotes();
    return allNotes.where((note) => note.category == category).toList();
  }

  /// Update a note (content, tags, timestamps only - frequency managed separately)
  Future<NoteModel> updateNote(NoteModel note) async {
    return _withRetry(() async {
      final response = await _client
          .from(_notesTable)
          .update({
            'content': note.content,
            'tags': note.tags,
            // Don't update frequency_count here - it's managed by updateFrequency()
            'last_accessed': note.lastAccessed.toIso8601String(),
            'last_edited': note.lastEdited.toIso8601String(),
          })
          .eq('id', note.id)
          .eq('user_id', _userId)
          .select()
          .single();

      return NoteModel.fromJson(response);
    });
  }

  /// Update frequency count and last accessed
  Future<NoteModel> updateFrequency(String noteId) async {
    return _withRetry(() async {
      // First get current note
      final currentResponse = await _client
          .from(_notesTable)
          .select()
          .eq('id', noteId)
          .eq('user_id', _userId)
          .single();

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

      return NoteModel.fromJson(response);
    });
  }

  /// Delete a note
  Future<void> deleteNote(String noteId) async {
    return _withRetry(() async {
      await _client
          .from(_notesTable)
          .delete()
          .eq('id', noteId)
          .eq('user_id', _userId);
    });
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
        await _client
            .from(_notesTable)
            .delete()
            .eq('id', noteId)
            .eq('user_id', userId);
      } catch (e) {
        // Log the error and continue with remaining notes
        failedIds.add(noteId);
        // ignore: avoid_print
        print('ERROR: Failed to delete note $noteId: $e');
      }
      
      // Report progress
      onProgress?.call(i + 1, noteIds.length);
    }
    
    return failedIds;
  }

  /// Search notes by content
  Future<List<NoteModel>> searchNotes(String query) async {
    if (query.isEmpty) {
      return fetchNotes();
    }

    return _withRetry(() async {
      final response = await _client
          .from(_notesTable)
          .select()
          .eq('user_id', _userId)
          .ilike('content', '%$query%')
          .order('last_accessed', ascending: false);

      return (response as List<dynamic>)
          .map((json) => NoteModel.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }
}
