import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/note_model.dart';
import 'glass_card.dart';

/// Note card widget with glassmorphic design
class NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onLongPress,
    this.onDelete,
  });

  /// Get glow color based on note category
  Color get _glowColor {
    switch (note.category) {
      case NoteCategory.daily:
        return AppColors.warmGlow;
      case NoteCategory.weekly:
        return AppColors.coolGlow;
      case NoteCategory.monthly:
        return AppColors.softTeal;
      case NoteCategory.archive:
        return AppColors.archiveGlow;
    }
  }

  /// Get glow intensity based on frequency
  double get _glowIntensity {
    // More frequently accessed = brighter glow
    if (note.frequencyCount > 20) return 0.8;
    if (note.frequencyCount > 10) return 0.6;
    if (note.frequencyCount > 5) return 0.4;
    if (note.frequencyCount > 0) return 0.2;
    return 0.1;
  }

  /// Get formatted time ago string
  String get _timeAgo {
    final now = DateTime.now();
    final difference = now.difference(note.lastAccessed);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}mo ago';
    }
  }

  /// Get preview text (first 100 characters)
  String get _previewText {
    if (note.content.length <= 100) {
      return note.content;
    }
    return '${note.content.substring(0, 100)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.warmGlow.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.warmGlow,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.darkPurple,
            title: Text(
              'Delete Note',
              style: AppTypography.heading,
            ),
            content: Text(
              'Are you sure you want to delete this note?',
              style: AppTypography.body,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: AppTypography.body.copyWith(
                    color: AppColors.subtleGray,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Delete',
                  style: AppTypography.body.copyWith(
                    color: AppColors.warmGlow,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => onDelete?.call(),
      child: AnimatedGlassCard(
        onTap: onTap,
        onLongPress: onLongPress,
        glowColor: _glowColor,
        glowIntensity: _glowIntensity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tags row
            if (note.tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: note.tags.map((tag) => _buildTag(tag)).toList(),
              ),
              const SizedBox(height: 10),
            ],

            // Content preview
            Text(
              _previewText,
              style: AppTypography.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 10),

            // Bottom row with time and frequency
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _timeAgo,
                  style: AppTypography.caption,
                ),
                Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 14,
                      color: AppColors.subtleGray,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${note.frequencyCount}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.softLavender.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.softLavender.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        tag,
        style: AppTypography.tag,
      ),
    );
  }
}
