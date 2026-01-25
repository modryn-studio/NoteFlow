import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/note_model.dart';
import 'auth_service.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  SupabaseClient get _client => SupabaseConfig.client;
  static const String _notesTable = 'notes';

  String get _userId {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    return userId;
  }

  /// Create a new note
  Future<NoteModel> createNote(String content, List<String> tags) async {
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
  }

  /// Fetch all notes for current user
  Future<List<NoteModel>> fetchNotes() async {
    final response = await _client
        .from(_notesTable)
        .select()
        .eq('user_id', _userId)
        .order('last_accessed', ascending: false);

    return (response as List<dynamic>)
        .map((json) => NoteModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch notes by category
  Future<List<NoteModel>> fetchNotesByCategory(NoteCategory category) async {
    final allNotes = await fetchNotes();
    return allNotes.where((note) => note.category == category).toList();
  }

  /// Update a note (content, tags, timestamps only - frequency managed separately)
  Future<NoteModel> updateNote(NoteModel note) async {
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
  }

  /// Update frequency count and last accessed
  Future<NoteModel> updateFrequency(String noteId) async {
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
  }

  /// Delete a note
  Future<void> deleteNote(String noteId) async {
    await _client
        .from(_notesTable)
        .delete()
        .eq('id', noteId)
        .eq('user_id', _userId);
  }

  /// Search notes by content
  Future<List<NoteModel>> searchNotes(String query) async {
    if (query.isEmpty) {
      return fetchNotes();
    }

    final response = await _client
        .from(_notesTable)
        .select()
        .eq('user_id', _userId)
        .ilike('content', '%$query%')
        .order('last_accessed', ascending: false);

    return (response as List<dynamic>)
        .map((json) => NoteModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
