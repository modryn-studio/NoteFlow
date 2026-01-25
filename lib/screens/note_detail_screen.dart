import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/note_model.dart';
import '../services/supabase_service.dart';
import '../services/tagging_service.dart';
import '../services/frequency_tracker.dart';
import '../widgets/tag_chip.dart';
import '../widgets/glass_card.dart';

/// Full-screen note detail/edit screen
class NoteDetailScreen extends StatefulWidget {
  final NoteModel? note;

  const NoteDetailScreen({
    super.key,
    required this.note,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late TextEditingController _contentController;
  late List<String> _tags;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasChanges = false;
  NoteModel? _note;
  List<String> _newTags = [];

  bool get _isNewNote => widget.note == null;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _contentController = TextEditingController(text: _note?.content ?? '');
    _tags = List.from(_note?.tags ?? []);
    _isEditing = true; // Always start in edit mode

    _contentController.addListener(_onContentChanged);

    // Track note open if editing existing note
    if (!_isNewNote && _note != null) {
      _trackNoteOpen();
    }
  }

  void _trackNoteOpen() async {
    try {
      if (_note != null) {
        await FrequencyTracker.instance.trackNoteOpen(_note!.id);
      }
    } catch (e) {
      // Ignore tracking errors
    }
  }

  void _onContentChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  /// Save note without navigating (for auto-save on back)
  Future<void> _saveQuietly() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    try {
      if (_isNewNote) {
        final tags = TaggingService.instance.autoTag(content);
        await SupabaseService.instance.createNote(content, tags);
      } else if (_note != null) {
        final updatedNote = _note!.copyWith(
          content: content,
          tags: _tags,
        );
        await SupabaseService.instance.updateNote(updatedNote);
      }
    } catch (e) {
      // Silently ignore save errors on back navigation
    }
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      _showError('Note cannot be empty');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isNewNote) {
        // Auto-tag new note
        final tags = TaggingService.instance.autoTag(content);
        await SupabaseService.instance.createNote(content, tags);
      } else if (_note != null) {
        // Update existing note
        final updatedNote = _note!.copyWith(
          content: content,
          tags: _tags,
        );
        await SupabaseService.instance.updateNote(updatedNote);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showError('Failed to save: $e');
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _autoTag() {
    final content = _contentController.text;
    final suggestedTags = TaggingService.instance.autoTag(content);

    // Find new tags that aren't already added
    final newTags = suggestedTags.where((t) => !_tags.contains(t)).toList();

    setState(() {
      _tags.addAll(newTags);
      _newTags = newTags;
      _hasChanges = true;
    });

    // Clear new tag indicators after animation
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _newTags = [];
        });
      }
    });
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _hasChanges = true;
    });
  }

  void _addCustomTag() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkPurple,
        title: Text('Add Tag', style: AppTypography.heading),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTypography.body,
          cursorColor: AppColors.softLavender,
          decoration: InputDecoration(
            hintText: 'Enter tag name',
            hintStyle: AppTypography.caption,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.subtleGray),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.softLavender),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTypography.body.copyWith(color: AppColors.subtleGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Add', style: AppTypography.body.copyWith(color: AppColors.softLavender)),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      final tag = result.trim().toLowerCase();
      if (!_tags.contains(tag)) {
        setState(() {
          _tags.add(tag);
          _newTags = [tag];
          _hasChanges = true;
        });

        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            setState(() {
              _newTags = [];
            });
          }
        });
      }
    }
  }

  Future<void> _delete() async {
    if (_note == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkPurple,
        title: Text('Delete Note', style: AppTypography.heading),
        content: Text(
          'Are you sure you want to delete this note?',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTypography.body.copyWith(color: AppColors.subtleGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: AppTypography.body.copyWith(color: AppColors.warmGlow)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SupabaseService.instance.deleteNote(_note!.id);
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        _showError('Failed to delete: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.warmGlow,
      ),
    );
  }

  String get _lastEditedText {
    if (_note == null) return '';
    final diff = DateTime.now().difference(_note!.lastAccessed);
    if (diff.inMinutes < 1) return 'Last edited just now';
    if (diff.inHours < 1) return 'Last edited ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Last edited ${diff.inHours}h ago';
    return 'Last edited ${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              _buildAppBar(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tags section
                      _buildTagsSection(),

                      const SizedBox(height: 16),

                      // Note content
                      _buildContentSection(),

                      const SizedBox(height: 24),

                      // Last edited timestamp
                      if (!_isNewNote)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            _lastEditedText,
                            style: AppTypography.caption,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.pearlWhite,
            ),
            onPressed: () async {
              // Auto-save on back navigation if there are changes
              if (_hasChanges && _contentController.text.trim().isNotEmpty) {
                await _saveQuietly();
              }
              if (mounted) Navigator.of(context).pop(_hasChanges);
            },
          ),

          const Spacer(),

          // Action buttons
          if (!_isNewNote) ...[
            // Edit/Done button
            IconButton(
              icon: Icon(
                _isEditing ? Icons.check_rounded : Icons.edit_rounded,
                color: AppColors.softLavender,
              ),
              onPressed: _isEditing ? _save : _toggleEdit,
            ),

            // Delete button
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.warmGlow,
              ),
              onPressed: _delete,
            ),
          ] else ...[
            // Save button for new note
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.softLavender,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(
                      Icons.check_rounded,
                      color: AppColors.mintGlow,
                    ),
                    onPressed: _save,
                  ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tags',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  // Auto-tag button
                  GestureDetector(
                    onTap: _autoTag,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.softTeal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: AppColors.softTeal,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Auto',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.softTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Add tag button
                  GestureDetector(
                    onTap: _addCustomTag,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.softLavender.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: AppColors.softLavender,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.isEmpty
                ? [
                    Text(
                      'No tags - tap Auto or + to add',
                      style: AppTypography.caption.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ]
                : _tags
                    .map((tag) => TagChip(
                          label: tag,
                          isNew: _newTags.contains(tag),
                          onRemove: () => _removeTag(tag),
                        ))
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: _isEditing
          ? TextField(
              controller: _contentController,
              autofocus: _isNewNote,
              maxLines: null,
              minLines: 10,
              style: AppTypography.bodyLarge,
              cursorColor: AppColors.softLavender,
              decoration: InputDecoration(
                hintText: 'Start typing your note...',
                hintStyle: AppTypography.body.copyWith(
                  color: AppColors.subtleGray.withOpacity(0.6),
                ),
                border: InputBorder.none,
              ),
            )
          : GestureDetector(
              onTap: _toggleEdit,
              child: Container(
                constraints: const BoxConstraints(minHeight: 200),
                width: double.infinity,
                child: Text(
                  _contentController.text.isEmpty
                      ? 'Tap to add content...'
                      : _contentController.text,
                  style: _contentController.text.isEmpty
                      ? AppTypography.body.copyWith(
                          color: AppColors.subtleGray.withOpacity(0.6),
                        )
                      : AppTypography.bodyLarge,
                ),
              ),
            ),
    );
  }
}
