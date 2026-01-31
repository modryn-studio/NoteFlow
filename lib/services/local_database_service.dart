import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/note_model.dart';

/// Local-first database service using Drift (SQLite)
/// Replaces SupabaseService for all CRUD operations
/// No network dependency - all operations are instant and offline-capable
class LocalDatabaseService {
  static LocalDatabaseService? _instance;
  static LocalDatabaseService get instance => _instance ??= LocalDatabaseService._();

  LocalDatabaseService._();

  late final AppDatabase _db;
  bool _isInitialized = false;
  String? _localUserId;

  /// Check if database is initialized
  bool get isInitialized => _isInitialized;

  /// Get the local user ID (generated on first launch, stored in SharedPreferences)
  String get localUserId {
    if (_localUserId == null) {
      throw StateError('LocalDatabaseService not initialized. Call initialize() first.');
    }
    return _localUserId!;
  }

  /// Initialize the database
  Future<void> initialize() async {
    if (_isInitialized) return;

    _db = AppDatabase();
    
    // Get or generate local user ID
    final prefs = await SharedPreferences.getInstance();
    _localUserId = prefs.getString('local_user_id');
    if (_localUserId == null) {
      _localUserId = const Uuid().v4();
      await prefs.setString('local_user_id', _localUserId!);
      debugPrint('Generated new local user ID: $_localUserId');
    } else {
      debugPrint('Using existing local user ID: $_localUserId');
    }

    _isInitialized = true;
    debugPrint('LocalDatabaseService initialized');
  }

  // ============ CREATE ============

  /// Create a new note
  /// Returns the created NoteModel immediately (no network delay)
  Future<NoteModel> createNote(String? title, String content, List<String> tags) async {
    final now = DateTime.now().toUtc();
    final id = const Uuid().v4();

    final noteCompanion = NotesCompanion(
      id: Value(id),
      title: Value(title),
      content: Value(content),
      tags: Value(jsonEncode(tags)),
      frequencyCount: const Value(0),
      lastAccessed: Value(now),
      lastEdited: Value(now),
      createdAt: Value(now),
    );

    await _db.insertNote(noteCompanion);

    return NoteModel(
      id: id,
      userId: localUserId,
      title: title,
      content: content,
      tags: tags,
      frequencyCount: 0,
      lastAccessed: now,
      lastEdited: now,
      createdAt: now,
    );
  }

  // ============ READ ============

  /// Fetch all notes ordered by last accessed (most recent first)
  /// Returns immediately from local SQLite database
  Future<List<NoteModel>> fetchNotes({bool forceRefresh = false}) async {
    // forceRefresh is ignored in local-first mode (no remote to refresh from)
    final notes = await _db.getAllNotes();
    return notes.map(_noteFromDrift).toList();
  }

  /// Fetch notes by category
  Future<List<NoteModel>> fetchNotesByCategory(NoteCategory category) async {
    final allNotes = await fetchNotes();
    return allNotes.where((note) => note.category == category).toList();
  }

  /// Get a single note by ID
  Future<NoteModel?> getNoteById(String noteId) async {
    final note = await _db.getNoteById(noteId);
    return note != null ? _noteFromDrift(note) : null;
  }

  /// Search notes by content, title, or tags
  /// Fully local search, instant results
  Future<List<NoteModel>> searchNotes(String query) async {
    final notes = await _db.searchNotes(query);
    return notes.map(_noteFromDrift).toList();
  }

  /// Check if a note exists
  Future<bool> noteExists(String noteId) async {
    return await _db.noteExists(noteId);
  }

  // ============ UPDATE ============

  /// Update a note (content, tags, timestamps)
  /// Returns updated NoteModel immediately
  Future<NoteModel> updateNote(NoteModel note) async {
    final now = DateTime.now().toUtc();
    
    final noteCompanion = NotesCompanion(
      id: Value(note.id),
      title: Value(note.title),
      content: Value(note.content),
      tags: Value(jsonEncode(note.tags)),
      lastAccessed: Value(note.lastAccessed),
      lastEdited: Value(now), // Always update lastEdited on save
    );

    await _db.updateNote(noteCompanion);

    return note.copyWith(lastEdited: now);
  }

  /// Update frequency count and last accessed time
  /// Works offline (unlike old SupabaseService.updateFrequency)
  Future<NoteModel> updateFrequency(String noteId) async {
    final note = await _db.getNoteById(noteId);
    if (note == null) {
      throw Exception('Note not found: $noteId');
    }

    final now = DateTime.now().toUtc();
    await _db.incrementFrequency(noteId);

    return _noteFromDrift(note).copyWith(
      frequencyCount: note.frequencyCount + 1,
      lastAccessed: now,
    );
  }

  // ============ DELETE ============

  /// Delete a note by ID
  Future<void> deleteNote(String noteId) async {
    await _db.deleteNoteById(noteId);
    debugPrint('Deleted note: $noteId');
  }

  /// Batch delete multiple notes
  /// Works offline (unlike old SupabaseService.batchDeleteNotes)
  Future<List<String>> batchDeleteNotes(
    List<String> noteIds, {
    void Function(int deleted, int total)? onProgress,
  }) async {
    final deletedIds = <String>[];
    
    for (int i = 0; i < noteIds.length; i++) {
      try {
        await _db.deleteNoteById(noteIds[i]);
        deletedIds.add(noteIds[i]);
        onProgress?.call(i + 1, noteIds.length);
      } catch (e) {
        debugPrint('Failed to delete note ${noteIds[i]}: $e');
      }
    }
    
    debugPrint('Batch deleted ${deletedIds.length}/${noteIds.length} notes');
    return deletedIds;
  }

  // ============ MIGRATION ============

  /// Import notes from a list (used for Hive→Drift migration)
  Future<int> importNotes(List<NoteModel> notes) async {
    int imported = 0;
    
    for (final note in notes) {
      try {
        // Check if note already exists
        if (await _db.noteExists(note.id)) {
          debugPrint('Note ${note.id} already exists, skipping');
          continue;
        }

        final noteCompanion = NotesCompanion(
          id: Value(note.id),
          title: Value(note.title),
          content: Value(note.content),
          tags: Value(jsonEncode(note.tags)),
          frequencyCount: Value(note.frequencyCount),
          lastAccessed: Value(note.lastAccessed),
          lastEdited: Value(note.lastEdited),
          createdAt: Value(note.createdAt),
        );

        await _db.insertNote(noteCompanion);
        imported++;
      } catch (e) {
        debugPrint('Failed to import note ${note.id}: $e');
      }
    }

    debugPrint('Imported $imported/${notes.length} notes from migration');
    return imported;
  }

  // ============ UTILITIES ============

  /// Get count of all notes
  Future<int> getNotesCount() async {
    return await _db.getNotesCount();
  }

  /// Convert Drift Note to NoteModel
  NoteModel _noteFromDrift(Note note) {
    List<String> tagsList;
    try {
      final decoded = jsonDecode(note.tags);
      tagsList = (decoded as List).cast<String>();
    } catch (e) {
      tagsList = [];
    }

    return NoteModel(
      id: note.id,
      userId: localUserId,
      title: note.title,
      content: note.content,
      tags: tagsList,
      frequencyCount: note.frequencyCount,
      lastAccessed: note.lastAccessed,
      lastEdited: note.lastEdited,
      createdAt: note.createdAt,
    );
  }

  /// Close the database connection
  Future<void> close() async {
    await _db.close();
    _isInitialized = false;
  }
}
