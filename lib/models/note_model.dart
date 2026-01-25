import 'package:uuid/uuid.dart';

enum NoteCategory {
  daily,
  weekly,
  monthly,
  archive,
}

class NoteModel {
  final String id;
  final String userId;
  final String content;
  final List<String> tags;
  final int frequencyCount;
  final DateTime lastAccessed;
  final DateTime createdAt;

  NoteModel({
    String? id,
    required this.userId,
    required this.content,
    List<String>? tags,
    this.frequencyCount = 0,
    DateTime? lastAccessed,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        tags = tags ?? [],
        lastAccessed = lastAccessed ?? DateTime.now().toUtc(),
        createdAt = createdAt ?? DateTime.now().toUtc();

  /// Determine category based on last accessed time
  NoteCategory get category {
    // Ensure both timestamps are in local time for accurate comparison
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

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      frequencyCount: json['frequency_count'] as int? ?? 0,
      lastAccessed: json['last_accessed'] != null
          ? DateTime.parse(json['last_accessed'] as String).toLocal()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'tags': tags,
      'frequency_count': frequencyCount,
      'last_accessed': lastAccessed.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create JSON for insert (excludes id for auto-generation)
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'content': content,
      'tags': tags,
      'frequency_count': frequencyCount,
      'last_accessed': lastAccessed.toIso8601String(),
    };
  }

  NoteModel copyWith({
    String? id,
    String? userId,
    String? content,
    List<String>? tags,
    int? frequencyCount,
    DateTime? lastAccessed,
    DateTime? createdAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      tags: tags ?? List.from(this.tags),
      frequencyCount: frequencyCount ?? this.frequencyCount,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'NoteModel(id: $id, content: ${content.substring(0, content.length > 30 ? 30 : content.length)}..., tags: $tags, category: $category)';
  }
}
