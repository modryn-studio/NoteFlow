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

  /// Get glow color - consistent lavender for all notes
  Color get _glowColor => AppColors.softLavender;

  /// Get glow intensity based on frequency
  double get _glowIntensity {
    // More frequently accessed = subtle brighter glow (reduced for consistency)
    if (note.frequencyCount > 20) return 0.3;
    if (note.frequencyCount > 10) return 0.2;
    if (note.frequencyCount > 5) return 0.15;
    if (note.frequencyCount > 0) return 0.1;
    return 0.05;
  }

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

  /// Get formatted time ago string for last viewed
  String get _viewedTimeAgo {
    final now = DateTime.now().toLocal();
    final lastAccessedLocal = note.lastAccessed.toLocal();
    final difference = now.difference(lastAccessedLocal);

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
        glowColor: _glowColor,
        glowIntensity: _glowIntensity,
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
                    // Right: View count + last viewed
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
                        const SizedBox(width: 6),
                        Text(
                          '• $_viewedTimeAgo',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.softLavender.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            // New/Updated badge with fade-in animation
            if (note.isNew || note.isRecentlyUpdated)
              Positioned(
                top: 0,
                right: 0,
                child: _NoteBadge(
                  isNew: note.isNew,
                  isUpdated: note.isRecentlyUpdated,
                ),
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
        color: AppColors.softLavender.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.softLavender.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        tag,
        style: AppTypography.tag,
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
                glowColor: isSelected ? AppColors.softLavender : _glowColor,
                glowIntensity: isSelected ? 0.4 : _glowIntensity,
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

/// Badge widget with 300ms fade-in animation for New/Updated status
class _NoteBadge extends StatefulWidget {
  final bool isNew;
  final bool isUpdated;

  const _NoteBadge({
    required this.isNew,
    required this.isUpdated,
  });

  @override
  State<_NoteBadge> createState() => _NoteBadgeState();
}

class _NoteBadgeState extends State<_NoteBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNewBadge = widget.isNew;
    final badgeColor = isNewBadge ? AppColors.warmGlow : AppColors.mintGlow;
    final badgeText = isNewBadge ? 'NEW' : 'UPDATED';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: badgeColor.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Text(
          badgeText,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: badgeColor,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
