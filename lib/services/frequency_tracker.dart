import 'package:hive_flutter/hive_flutter.dart';
import '../models/note_model.dart';
import 'supabase_service.dart';

/// Service for tracking note access frequency
class FrequencyTracker {
  static FrequencyTracker? _instance;
  static FrequencyTracker get instance => _instance ??= FrequencyTracker._();

  FrequencyTracker._();

  static const String _boxName = 'frequency_tracking';
  Box<int>? _box;

  /// Initialize Hive box for local frequency tracking
  Future<void> initialize() async {
    _box = await Hive.openBox<int>(_boxName);
  }

  /// Get local frequency count for a note
  int getLocalFrequency(String noteId) {
    return _box?.get(noteId) ?? 0;
  }

  /// Increment local frequency count
  Future<void> incrementLocalFrequency(String noteId) async {
    final current = getLocalFrequency(noteId);
    await _box?.put(noteId, current + 1);
  }

  /// Track note open - updates both local and remote
  /// Returns updated note on success, throws on failure
  /// Local tracking is always updated, even if remote fails
  Future<NoteModel> trackNoteOpen(String noteId) async {
    // Update local tracking (always succeeds)
    await incrementLocalFrequency(noteId);

    // Update remote (Supabase) - may fail on network issues
    // Caller should handle errors gracefully
    return await SupabaseService.instance.updateFrequency(noteId);
  }

  /// Get category for a note based on last accessed time
  NoteCategory getCategoryFromTime(DateTime lastAccessed) {
    final now = DateTime.now().toLocal();
    final lastAccessedLocal = lastAccessed.toLocal();
    final difference = now.difference(lastAccessedLocal);

    if (difference.inHours < 24) {
      return NoteCategory.daily;
    } else if (difference.inDays < 7) {
      return NoteCategory.weekly;
    } else if (difference.inDays < 30) {
      return NoteCategory.monthly;
    } else {
      return NoteCategory.archive;
    }
  }

  /// Group notes by category
  Map<NoteCategory, List<NoteModel>> groupNotesByCategory(
      List<NoteModel> notes) {
    final grouped = <NoteCategory, List<NoteModel>>{
      NoteCategory.daily: [],
      NoteCategory.weekly: [],
      NoteCategory.monthly: [],
      NoteCategory.archive: [],
    };

    for (final note in notes) {
      grouped[note.category]!.add(note);
    }

    // Sort each category by frequency count (most accessed first)
    for (final category in grouped.keys) {
      grouped[category]!
          .sort((a, b) => b.frequencyCount.compareTo(a.frequencyCount));
    }

    return grouped;
  }

  /// Get category display name
  static String getCategoryName(NoteCategory category) {
    switch (category) {
      case NoteCategory.daily:
        return 'Daily';
      case NoteCategory.weekly:
        return 'Weekly';
      case NoteCategory.monthly:
        return 'Monthly';
      case NoteCategory.archive:
        return 'Archive';
    }
  }

  /// Get category description
  static String getCategoryDescription(NoteCategory category) {
    switch (category) {
      case NoteCategory.daily:
        return 'Accessed within 24 hours';
      case NoteCategory.weekly:
        return 'Accessed within a week';
      case NoteCategory.monthly:
        return 'Accessed within a month';
      case NoteCategory.archive:
        return 'Not accessed in over a month';
    }
  }

  /// Clear local frequency data
  Future<void> clearLocalData() async {
    await _box?.clear();
  }

  /// Sync local frequency data with remote
  Future<void> syncWithRemote(List<NoteModel> remoteNotes) async {
    for (final note in remoteNotes) {
      final localCount = getLocalFrequency(note.id);
      if (localCount > note.frequencyCount) {
        // Local has more opens, update remote
        // This would be used for offline-first scenarios
      }
    }
  }
}
