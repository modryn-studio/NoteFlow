import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

/// Notes table - stores all user notes locally
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().nullable()();
  TextColumn get content => text()();
  TextColumn get tags => text()(); // JSON array stored as string
  IntColumn get frequencyCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAccessed => dateTime()();
  DateTimeColumn get lastEdited => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The main database class for NoteFlow local storage
@DriftDatabase(tables: [Notes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ============ CRUD Operations ============

  /// Fetch all notes ordered by last accessed (most recent first)
  Future<List<Note>> getAllNotes() async {
    return await (select(notes)
          ..orderBy([(t) => OrderingTerm.desc(t.lastAccessed)]))
        .get();
  }

  /// Fetch a single note by ID
  Future<Note?> getNoteById(String id) async {
    return await (select(notes)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Create a new note
  Future<void> insertNote(NotesCompanion note) async {
    await into(notes).insert(note);
  }

  /// Update an existing note
  Future<void> updateNote(NotesCompanion note) async {
    await (update(notes)..where((t) => t.id.equals(note.id.value))).write(note);
  }

  /// Delete a note by ID
  Future<void> deleteNoteById(String id) async {
    await (delete(notes)..where((t) => t.id.equals(id))).go();
  }

  /// Delete multiple notes by IDs
  Future<void> deleteNotesByIds(List<String> ids) async {
    await (delete(notes)..where((t) => t.id.isIn(ids))).go();
  }

  /// Search notes by content, title, or tags
  /// Uses SQL LIKE for better performance with large datasets
  Future<List<Note>> searchNotes(String query) async {
    if (query.isEmpty) return getAllNotes();
    
    final pattern = '%${query.toLowerCase()}%';
    return await (select(notes)
          ..where((t) =>
              t.content.lower().like(pattern) |
              t.title.lower().like(pattern) |
              t.tags.lower().like(pattern))
          ..orderBy([(t) => OrderingTerm.desc(t.lastAccessed)]))
        .get();
  }

  /// Update frequency count for a note
  Future<void> incrementFrequency(String id) async {
    final note = await getNoteById(id);
    if (note != null) {
      await (update(notes)..where((t) => t.id.equals(id))).write(
        NotesCompanion(
          frequencyCount: Value(note.frequencyCount + 1),
          lastAccessed: Value(DateTime.now().toUtc()),
        ),
      );
    }
  }

  /// Check if a note exists
  Future<bool> noteExists(String id) async {
    final note = await getNoteById(id);
    return note != null;
  }

  /// Get count of all notes
  Future<int> getNotesCount() async {
    final count = await (selectOnly(notes)..addColumns([notes.id.count()])).getSingle();
    return count.read(notes.id.count()) ?? 0;
  }
}

/// Opens a connection to the SQLite database
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'noteflow.db'));
    return NativeDatabase.createInBackground(file);
  });
}

// ============ Helper Extensions ============

/// Extension to convert between Drift Note and JSON tags
extension NoteTagsExtension on Note {
  /// Parse tags from JSON string
  List<String> get tagsList {
    try {
      final decoded = jsonDecode(tags);
      if (decoded is List) {
        return decoded.cast<String>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

/// Extension to create NotesCompanion from values
extension NotesCompanionHelper on NotesCompanion {
  /// Create a companion for insert with all required fields
  static NotesCompanion create({
    required String id,
    String? title,
    required String content,
    required List<String> tags,
    int frequencyCount = 0,
    DateTime? lastAccessed,
    DateTime? lastEdited,
    DateTime? createdAt,
  }) {
    final now = DateTime.now().toUtc();
    return NotesCompanion(
      id: Value(id),
      title: Value(title),
      content: Value(content),
      tags: Value(jsonEncode(tags)),
      frequencyCount: Value(frequencyCount),
      lastAccessed: Value(lastAccessed ?? now),
      lastEdited: Value(lastEdited ?? now),
      createdAt: Value(createdAt ?? now),
    );
  }
}
