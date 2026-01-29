import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';

part 'note_model.g.dart';

enum NoteCategory {
  daily,
  weekly,
  monthly,
  archive,
}

/// Constants for note model calculations
class NoteModelConstants {
  /// Tolerance in seconds for comparing timestamps (to account for processing time)
  static const int timestampToleranceSeconds = 2;
  
  /// Hours threshold for considering a note as "new"
  static const int newNoteHoursThreshold = 12;
  
  /// Hours threshold for considering a note as "recently updated"
  static const int recentlyUpdatedHoursThreshold = 12;
  
  /// Maximum length for display title
  static const int maxDisplayTitleLength = 30;
  
  /// Days thresholds for categories
  static const int dailyHoursThreshold = 24;
  static const int weeklyDaysThreshold = 7;
  static const int monthlyDaysThreshold = 30;
}

@HiveType(typeId: 1)
class NoteModel extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String userId;
  @HiveField(2)
  final String? title;  // Optional custom title
  @HiveField(3)
  final String content;
  @HiveField(4)
  final List<String> tags;
  @HiveField(5)
  final int frequencyCount;
  @HiveField(6)
  final DateTime lastAccessed;  // When last opened/viewed
  @HiveField(7)
  final DateTime lastEdited;     // When content last changed
  @HiveField(8)
  final DateTime createdAt;

  NoteModel({
    String? id,
    required this.userId,
    this.title,
    required this.content,
    List<String>? tags,
    this.frequencyCount = 0,
    DateTime? lastAccessed,
    DateTime? lastEdited,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        tags = tags ?? [],
        lastAccessed = lastAccessed ?? DateTime.now().toUtc(),
        lastEdited = lastEdited ?? DateTime.now().toUtc(),
        createdAt = createdAt ?? DateTime.now().toUtc();

  /// Get emoji prefix based on primary tag
  String get emojiPrefix {
    if (tags.isEmpty) return '📝';
    final primaryTag = tags.first.toLowerCase();
    return _tagEmojiMap[primaryTag] ?? '📝';
  }

  /// Tag to emoji mapping
  static const Map<String, String> _tagEmojiMap = {
    'work': '💼',
    'bills': '💰',
    'ideas': '💡',
    'gifts': '🎁',
    'personal': '✨',
    'shopping': '🛒',
  };

  /// Auto-generated display title from custom title or first line of content (max 30 chars)
  String get displayTitle {
    const maxLen = NoteModelConstants.maxDisplayTitleLength;
    
    // Use custom title if provided
    if (title != null && title!.isNotEmpty) {
      return title!.length > maxLen 
          ? '${title!.substring(0, maxLen)}...' 
          : title!;
    }
    
    // Fall back to first line of content
    if (content.isEmpty) return 'Untitled';
    final firstLine = content.split('\n').first.trim();
    if (firstLine.isEmpty) return 'Untitled';
    return firstLine.length > maxLen 
        ? '${firstLine.substring(0, maxLen)}...' 
        : firstLine;
  }

  /// Full display title with emoji prefix
  String get displayTitleWithEmoji => '$emojiPrefix $displayTitle';

  /// Check if note is new (created < 12h ago AND never edited)
  bool get isNew {
    final now = DateTime.now().toLocal();
    final createdAtLocal = createdAt.toLocal();
    final lastEditedLocal = lastEdited.toLocal();
    final hoursSinceCreated = now.difference(createdAtLocal).inHours;
    
    // Note is NEW if: created < 12h ago AND lastEdited equals createdAt (never edited)
    // We use a small tolerance for timestamp comparison
    final neverEdited = lastEditedLocal.difference(createdAtLocal).inSeconds.abs() < 
        NoteModelConstants.timestampToleranceSeconds;
    return hoursSinceCreated < NoteModelConstants.newNoteHoursThreshold && neverEdited;
  }

  /// Check if note was recently updated (edited < 12h ago AND has been edited before)
  bool get isRecentlyUpdated {
    final now = DateTime.now().toLocal();
    final createdAtLocal = createdAt.toLocal();
    final lastEditedLocal = lastEdited.toLocal();
    final hoursSinceEdited = now.difference(lastEditedLocal).inHours;
    
    // Note is UPDATED if: edited < 12h ago AND lastEdited differs from createdAt
    final hasBeenEdited = lastEditedLocal.difference(createdAtLocal).inSeconds.abs() >= 
        NoteModelConstants.timestampToleranceSeconds;
    return hoursSinceEdited < NoteModelConstants.recentlyUpdatedHoursThreshold && hasBeenEdited;
  }

  /// Determine category based on last accessed time
  NoteCategory get category {
    // Ensure both timestamps are in local time for accurate comparison
    final now = DateTime.now().toLocal();
    final lastAccessedLocal = lastAccessed.toLocal();
    final difference = now.difference(lastAccessedLocal);

    if (difference.inHours < NoteModelConstants.dailyHoursThreshold) {
      return NoteCategory.daily;
    } else if (difference.inDays < NoteModelConstants.weeklyDaysThreshold) {
      return NoteCategory.weekly;
    } else if (difference.inDays < NoteModelConstants.monthlyDaysThreshold) {
      return NoteCategory.monthly;
    } else {
      return NoteCategory.archive;
    }
  }

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String?,
      content: json['content'] as String,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      frequencyCount: json['frequency_count'] as int? ?? 0,
      lastAccessed: json['last_accessed'] != null
          ? DateTime.parse(json['last_accessed'] as String).toUtc()
          : DateTime.now().toUtc(),
      lastEdited: json['last_edited'] != null
          ? DateTime.parse(json['last_edited'] as String).toUtc()
          : DateTime.now().toUtc(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toUtc()
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'tags': tags,
      'frequency_count': frequencyCount,
      'last_accessed': lastAccessed.toIso8601String(),
      'last_edited': lastEdited.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create JSON for insert (includes id so Supabase uses our client-generated UUID)
  Map<String, dynamic> toInsertJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'tags': tags,
      'frequency_count': frequencyCount,
      'last_accessed': lastAccessed.toIso8601String(),
      'last_edited': lastEdited.toIso8601String(),
    };
  }

  NoteModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    List<String>? tags,
    int? frequencyCount,
    DateTime? lastAccessed,
    DateTime? lastEdited,
    DateTime? createdAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? List.from(this.tags),
      frequencyCount: frequencyCount ?? this.frequencyCount,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      lastEdited: lastEdited ?? this.lastEdited,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'NoteModel(id: $id, content: ${content.substring(0, content.length > 30 ? 30 : content.length)}..., tags: $tags, category: $category)';
  }
}
