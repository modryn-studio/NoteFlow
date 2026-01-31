import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/note_model.dart';
import 'glass_card.dart';

/// Note card widget with glassmorphic design
class NoteCard extends StatefulWidget {
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

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _isDismissible = true;
  double? _startX;
  double? _startY;

  /// Get formatted time ago string
  /// Get formatted time ago string for last edited
  String get _editedTimeAgo {
    final now = DateTime.now().toLocal();
    final lastEditedLocal = widget.note.lastEdited.toLocal();
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
    if (widget.note.content.length <= 100) {
      return widget.note.content;
    }
    return '${widget.note.content.substring(0, 100)}...';
  }

  @override
  Widget build(BuildContext context) {
    // In selection mode, show a row with checkbox
    if (widget.isSelectionMode) {
      return _buildSelectionCard();
    }
    
    return GestureDetector(
      onHorizontalDragStart: (details) {
        _startX = details.globalPosition.dx;
        _startY = details.globalPosition.dy;
        setState(() => _isDismissible = false);
      },
      onHorizontalDragUpdate: (details) {
        if (_startX != null && _startY != null) {
          final dx = (_startX! - details.globalPosition.dx).abs();
          final dy = (_startY! - details.globalPosition.dy).abs();
          
          // Only enable dismissible if swipe is mostly horizontal
          // Require 3x more horizontal movement than vertical
          if (dx > 30 && dx > dy * 3) {
            setState(() => _isDismissible = true);
          }
        }
      },
      onHorizontalDragEnd: (details) {
        _startX = null;
        _startY = null;
        // Reset after a short delay to allow dismissible to complete
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _isDismissible = false);
        });
      },
      child: _isDismissible ? _buildDismissibleCard() : _buildStaticCard(),
    );
  }

  Widget _buildDismissibleCard() {
    return Dismissible(
      key: Key(widget.note.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.7, // Must swipe 70% of width
      },
      movementDuration: const Duration(milliseconds: 300),
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
              style: AppTypography.headingSmall,
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
      onDismissed: (direction) => widget.onDelete?.call(),
      child: _buildCardContent(),
    );
  }

  Widget _buildStaticCard() {
    return _buildCardContent();
  }

  Widget _buildCardContent() {
    return AnimatedGlassCard(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.only(right: 60), // Space for badge
                child: Text(
                  widget.note.displayTitle,
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
                        '${widget.note.frequencyCount}',
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
    );
  }

  /// Build card with checkbox for selection mode
  Widget _buildSelectionCard() {
    return GestureDetector(
      onTap: widget.onSelectionToggle,
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
                color: widget.isSelected 
                    ? AppColors.softLavender 
                    : Colors.transparent,
                border: Border.all(
                  color: widget.isSelected 
                      ? AppColors.softLavender 
                      : AppColors.subtleGray,
                  width: 2,
                ),
              ),
              child: widget.isSelected
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
                onTap: widget.onSelectionToggle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      widget.note.displayTitle,
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

