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
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectionToggle,
  });

  /// Get formatted time ago string
  /// Get formatted time ago string for last edited
  String get _editedTimeAgo {
    final now = DateTime.now().toLocal();
    final lastEditedLocal = note.lastEdited.toLocal();
    final difference = now.difference(lastEditedLocal);

    if (difference.inMinutes < 1) {
      return 'just now';
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
    // In selection mode, show a row with checkbox
    if (isSelectionMode) {
      return _buildSelectionCard();
    }
    
    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.warmGlow.withValues(alpha: 0.3),
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
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title with emoji prefix
                Padding(
                  padding: const EdgeInsets.only(right: 60), // Space for badge
                  child: Text(
                    note.displayTitleWithEmoji,
                    style: AppTypography.headingSmall.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),

                // Bottom row with dual timestamps
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Last edited (primary info)
                    Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: AppColors.subtleGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _editedTimeAgo,
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                    // Right: View count only (no last viewed time)
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
          ],
        ),
      ),
    );
  }

  /// Build card with checkbox for selection mode
  Widget _buildSelectionCard() {
    return GestureDetector(
      onTap: onSelectionToggle,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            // Animated checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected 
                    ? AppColors.softLavender 
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected 
                      ? AppColors.softLavender 
                      : AppColors.subtleGray,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: AppColors.deepIndigo,
                      size: 18,
                    )
                  : null,
            ),
            // Note card content
            Expanded(
              child: AnimatedGlassCard(
                onTap: onSelectionToggle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with emoji prefix
                    Text(
                      note.displayTitleWithEmoji,
                      style: AppTypography.headingSmall.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Content preview
                    Text(
                      _previewText,
                      style: AppTypography.body.copyWith(
                        color: AppColors.subtleGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

