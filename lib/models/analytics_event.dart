import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'analytics_event.g.dart';

/// Tracks tag corrections made by users for ML training
@HiveType(typeId: 2)
class TagCorrectionEvent extends HiveObject {
  @HiveField(0)
  late String eventId;
  
  @HiveField(1)
  late String noteId;
  
  @HiveField(2)
  late String noteContent; // First 100 chars for ML training
  
  @HiveField(3)
  late List<String> originalTags; // Auto-generated tags
  
  @HiveField(4)
  late List<String> finalTags; // User-corrected tags
  
  @HiveField(5)
  late List<String> addedTags; // finalTags - originalTags
  
  @HiveField(6)
  late List<String> removedTags; // originalTags - finalTags
  
  @HiveField(7)
  late DateTime timestamp;
  
  @HiveField(8)
  late String userId;
  
  @HiveField(9)
  late bool synced; // Synced to Supabase?

  TagCorrectionEvent();

  /// Factory constructor for creating new events
  TagCorrectionEvent.create({
    required this.noteId,
    required String fullContent,
    required this.originalTags,
    required this.finalTags,
    required this.userId,
  }) {
    eventId = const Uuid().v4();
    // Store first 100 chars for ML training context
    noteContent = fullContent.length > 100 
        ? fullContent.substring(0, 100) 
        : fullContent;
    addedTags = finalTags.where((t) => !originalTags.contains(t)).toList();
    removedTags = originalTags.where((t) => !finalTags.contains(t)).toList();
    timestamp = DateTime.now().toUtc();
    synced = false;
  }

  /// Check if there were any changes
  bool get hasChanges => addedTags.isNotEmpty || removedTags.isNotEmpty;

  /// Convert to JSON for Supabase sync
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': eventId,
      'user_id': userId,
      'note_id': noteId,
      'note_content': noteContent,
      'original_tags': originalTags,
      'final_tags': finalTags,
      'added_tags': addedTags,
      'removed_tags': removedTags,
      'created_at': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'TagCorrectionEvent(noteId: $noteId, removed: $removedTags, added: $addedTags)';
  }
}
