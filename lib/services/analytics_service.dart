import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/analytics_event.dart';
import '../core/config/supabase_config.dart';
import 'auth_service.dart';

/// Service for tracking tag corrections and other analytics events
class AnalyticsService {
  static AnalyticsService? _instance;
  static AnalyticsService get instance => _instance ??= AnalyticsService._();

  AnalyticsService._();

  static const String _boxName = 'tag_corrections';
  Box<TagCorrectionEvent>? _box;

  /// Initialize the analytics service
  Future<void> initialize() async {
    // Register adapter if not already registered
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(TagCorrectionEventAdapter());
    }
    _box = await Hive.openBox<TagCorrectionEvent>(_boxName);
  }

  /// Ensure box is initialized
  /// Throws if initialization fails
  Future<Box<TagCorrectionEvent>> _getBox() async {
    if (_box == null || !_box!.isOpen) {
      await initialize();
    }
    if (_box == null) {
      throw StateError('Analytics box failed to initialize');
    }
    return _box!;
  }

  /// Log a tag correction event
  Future<void> logTagCorrection({
    required String noteId,
    required String noteContent,
    required List<String> originalTags,
    required List<String> finalTags,
  }) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;

    final event = TagCorrectionEvent.create(
      noteId: noteId,
      fullContent: noteContent,
      originalTags: originalTags,
      finalTags: finalTags,
      userId: userId,
    );

    // Only log if there were actual changes
    if (!event.hasChanges) return;

    final box = await _getBox();
    await box.add(event);

    // Log to console for debugging
    debugPrint('ANALYTICS: Tag correction logged - ${event.toString()}');
  }

  /// Get all unsynced events
  Future<List<TagCorrectionEvent>> getUnsyncedEvents() async {
    final box = await _getBox();
    return box.values.where((e) => !e.synced).toList();
  }

  /// Mark events as synced
  Future<void> markAsSynced(List<TagCorrectionEvent> events) async {
    for (final event in events) {
      event.synced = true;
      await event.save();
    }
  }

  /// Default timeout for sync operations
  static const Duration _syncTimeout = Duration(seconds: 10);

  /// Sync events to Supabase
  Future<int> syncToSupabase() async {
    final events = await getUnsyncedEvents();
    if (events.isEmpty) return 0;

    int syncedCount = 0;
    final client = SupabaseConfig.client;

    for (final event in events) {
      try {
        await client
            .from('analytics_tag_corrections')
            .insert(event.toSupabaseJson())
            .timeout(_syncTimeout);

        event.synced = true;
        await event.save();
        syncedCount++;
      } catch (e) {
        // Log error but continue with other events
        debugPrint('ANALYTICS: Failed to sync event ${event.eventId}: $e');
      }
    }

    return syncedCount;
  }

  /// Get statistics on tag corrections
  Future<Map<String, dynamic>> getStats() async {
    final box = await _getBox();
    final events = box.values.toList();

    // Count most removed tags
    final removedTagCounts = <String, int>{};
    for (final event in events) {
      for (final tag in event.removedTags) {
        removedTagCounts[tag] = (removedTagCounts[tag] ?? 0) + 1;
      }
    }

    // Count most added tags
    final addedTagCounts = <String, int>{};
    for (final event in events) {
      for (final tag in event.addedTags) {
        addedTagCounts[tag] = (addedTagCounts[tag] ?? 0) + 1;
      }
    }

    // Sort by count
    final sortedRemoved = removedTagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedAdded = addedTagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalCorrections': events.length,
      'syncedCount': events.where((e) => e.synced).length,
      'pendingSync': events.where((e) => !e.synced).length,
      'mostRemovedTags': sortedRemoved.take(5).toList(),
      'mostAddedTags': sortedAdded.take(5).toList(),
    };
  }

  /// Clear all local events (use after sync or for reset)
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Get total event count
  Future<int> getEventCount() async {
    final box = await _getBox();
    return box.length;
  }

  /// Dispose resources and close Hive box
  Future<void> dispose() async {
    await _box?.close();
    _box = null;
  }
}
