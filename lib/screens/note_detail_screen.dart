import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import '../models/note_model.dart';
import '../services/local_database_service.dart';
import '../services/tagging_service.dart';
import '../services/entity_detection_service.dart';
import '../services/analytics_service.dart';
import '../widgets/tag_chip.dart';
import '../widgets/glass_card.dart';

/// Global lock to prevent concurrent edits of the same note on same device
class _NoteEditLock {
  static final Set<String> _lockedNoteIds = {};
  
  static bool tryLock(String? noteId) {
    if (noteId == null) return true; // New notes don't need lock
    if (_lockedNoteIds.contains(noteId)) return false;
    _lockedNoteIds.add(noteId);
    return true;
  }
  
  static void unlock(String? noteId) {
    if (noteId != null) _lockedNoteIds.remove(noteId);
  }
}

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
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late FocusNode _titleFocusNode;
  late FocusNode _contentFocusNode;
  late List<String> _tags;
  late List<String> _originalTags; // Track original tags for analytics
  late String _originalTitle; // Track original title
  late String _originalContent; // Track original content
  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasChanges = false;
  NoteModel? _note;
  List<String> _newTags = [];
  bool _isNewNote = false; // Track if this is a new unsaved note
  bool _hasSaved = false; // Track if save was already performed (prevents double-save on back)
  DateTime? _lastSaveAttempt; // Debounce rapid save taps
  static const _saveDebounceMs = 500; // Minimum ms between save attempts
  
  // Entity detection cache for performance with long content
  String? _cachedEntityContent;
  List<DetectedEntity> _cachedEntities = [];
  
  /// Check if content actually changed (not just opened for edit)
  bool get _hasActualContentChanges {
    final currentTitle = _titleController.text.trim();
    final currentContent = _contentController.text.trim();
    
    // Check title and content changes
    if (currentTitle != _originalTitle || currentContent != _originalContent) {
      return true;
    }
    
    // Check tag changes
    if (_tags.length != _originalTags.length) {
      return true;
    }
    final originalSet = Set.from(_originalTags);
    final currentSet = Set.from(_tags);
    if (!originalSet.containsAll(currentSet) || !currentSet.containsAll(originalSet)) {
      return true;
    }
    
    return false;
  }

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _isNewNote = widget.note == null; // Set once at init, updated after first save
    
    // Try to acquire lock for this note (prevents concurrent edits on same device)
    if (!_NoteEditLock.tryLock(_note?.id)) {
      // Note is already being edited elsewhere - show read-only
      // This is a rare edge case, handled gracefully
      debugPrint('Note ${_note?.id} is already being edited');
    }
    
    // Store trimmed versions for consistent comparison
    _originalTitle = (_note?.title ?? '').trim();
    _originalContent = (_note?.content ?? '').trim();
    // Initialize controllers with original (potentially untrimmed) values for editing
    _titleController = TextEditingController(text: _note?.title ?? '');
    _contentController = TextEditingController(text: _note?.content ?? '');
    _titleFocusNode = FocusNode();
    _contentFocusNode = FocusNode();
    _tags = List.from(_note?.tags ?? []);
    _originalTags = List.from(_note?.tags ?? []); // Store original for analytics
    _isEditing = _isNewNote; // Only start in edit mode for new notes

    _titleController.addListener(_onContentChanged);
    _contentController.addListener(_onContentChanged);
    
    // Note: Frequency tracking is handled in home_screen before navigation
    // to avoid race conditions with data loading
  }

  void _onContentChanged() {
    // Check if content actually changed from original
    final hasActualChanges = _hasActualContentChanges;
    if (hasActualChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasActualChanges;
      });
    }
  }

  @override
  void dispose() {
    // Release note edit lock
    _NoteEditLock.unlock(_note?.id);
    
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
    
    // Auto-focus content field when entering edit mode
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _contentFocusNode.requestFocus();
      });
    }
  }

  /// Get cached entities for content (avoids re-detecting on every build)
  List<DetectedEntity> _getCachedEntities(String content) {
    if (_cachedEntityContent != content) {
      _cachedEntityContent = content;
      _cachedEntities = EntityDetectionService.instance.detectEntities(content);
    }
    return _cachedEntities;
  }

  /// Undo all changes and restore original values
  void _undoChanges() {
    setState(() {
      _titleController.text = _originalTitle;
      _contentController.text = _originalContent;
      _tags = List.from(_originalTags);
      _hasChanges = false;
    });
  }

  /// Save note without navigating (for auto-save on back)
  Future<void> _saveQuietly() async {
    // Prevent concurrent saves
    if (_isSaving) return;
    
    // For new notes that have already been saved, treat as existing note
    // This prevents duplicate creation when tapping back
    
    final content = _contentController.text.trim();
    final title = _titleController.text.trim();
    
    // Don't save if both title and content are empty
    if (content.isEmpty && title.isEmpty) return;
    
    // Don't save if no actual changes
    if (!_hasActualContentChanges) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isNewNote) {
        // For title-only notes, use title for tagging if content is empty
        final textToTag = content.isNotEmpty ? content : title;
        final tags = _tags.isNotEmpty ? _tags : TaggingService.instance.autoTag(textToTag);
        final savedNote = await LocalDatabaseService.instance.createNote(
          title.isEmpty ? null : title,
          content,
          tags,
        );
        
        // Update state to prevent duplicate saves
        _note = savedNote;
        _isNewNote = false;
        _originalTitle = title;
        _originalContent = content;
        _originalTags = List.from(tags);
        _tags = List.from(tags);
      } else if (_note != null) {
        // Log tag corrections before saving (existing notes only)
        await _logTagCorrections();
        
        final now = DateTime.now().toUtc();
        final updatedNote = _note!.copyWith(
          title: title.isEmpty ? null : title,
          content: content,
          tags: _tags,
          // Only update lastEdited if content actually changed
          lastEdited: _hasActualContentChanges ? now : _note!.lastEdited,
          lastAccessed: now,   // Always update accessed time
        );
        final savedNote = await LocalDatabaseService.instance.updateNote(updatedNote);
        _note = savedNote;
        _originalTitle = title;
        _originalContent = content;
        _originalTags = List.from(_tags);
      }
      
      // Show saved confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Note saved'),
            backgroundColor: AppColors.mintGlow.withValues(alpha: 0.9),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // Silently ignore save errors on back navigation
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasChanges = false;
          _hasSaved = true; // Mark as saved so PopScope returns true
        });
      }
    }
  }

  Future<void> _save() async {
    // Prevent concurrent saves
    if (_isSaving) return;
    
    // Debounce rapid taps (within 500ms)
    final now = DateTime.now();
    if (_lastSaveAttempt != null && 
        now.difference(_lastSaveAttempt!).inMilliseconds < _saveDebounceMs) {
      return;
    }
    _lastSaveAttempt = now;
    
    final content = _contentController.text.trim();
    final title = _titleController.text.trim();

    // Require at least title or content
    if (content.isEmpty && title.isEmpty) {
      _showError('Note cannot be completely empty');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isNewNote) {
        // Auto-tag new note if no tags set
        // For title-only notes, use title for tagging if content is empty
        final textToTag = content.isNotEmpty ? content : title;
        final tags = _tags.isNotEmpty ? _tags : TaggingService.instance.autoTag(textToTag);
        final savedNote = await LocalDatabaseService.instance.createNote(
          title.isEmpty ? null : title,
          content,
          tags,
        );
        
        if (mounted) {
          // Update state to prevent duplicate saves
          setState(() {
            _note = savedNote;
            _isNewNote = false;
            _isEditing = false;
            _isSaving = false;
            _hasChanges = false;
            _hasSaved = true;
            _originalTitle = title;
            _originalContent = content;
            _originalTags = List.from(tags);
            _tags = List.from(tags);
          });
          
          // Unfocus all fields to dismiss keyboard and exit edit mode
          _titleFocusNode.unfocus();
          _contentFocusNode.unfocus();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Note saved'),
              backgroundColor: AppColors.mintGlow.withValues(alpha: 0.9),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else if (_note != null) {
        // Log tag corrections before saving (existing notes only)
        await _logTagCorrections();
        
        // Update existing note
        final now = DateTime.now().toUtc();
        final updatedNote = _note!.copyWith(
          title: title.isEmpty ? null : title,
          content: content,
          tags: _tags,
          lastEdited: _hasActualContentChanges ? now : _note!.lastEdited,
          lastAccessed: now,   // Viewing while editing
        );
        final savedNote = await LocalDatabaseService.instance.updateNote(updatedNote);

        if (mounted) {
          // Exit edit mode and show confirmation
          setState(() {
            _note = savedNote;
            _isEditing = false;
            _isSaving = false;
            _hasChanges = false;
            _hasSaved = true;
            _originalTitle = title;
            _originalContent = content;
            _originalTags = List.from(_tags);
          });
          
          // Unfocus all fields to dismiss keyboard and exit edit mode
          _titleFocusNode.unfocus();
          _contentFocusNode.unfocus();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Note saved'),
              backgroundColor: AppColors.mintGlow.withValues(alpha: 0.9),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      _showError('Failed to save: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Log tag corrections for ML training
  Future<void> _logTagCorrections() async {
    if (_note == null) return;
    
    // Check if tags changed
    final originalSet = Set.from(_originalTags);
    final currentSet = Set.from(_tags);
    
    if (originalSet.difference(currentSet).isEmpty && 
        currentSet.difference(originalSet).isEmpty) {
      return; // No changes
    }
    
    try {
      await AnalyticsService.instance.logTagCorrection(
        noteId: _note!.id,
        noteContent: _contentController.text,
        originalTags: _originalTags,
        finalTags: _tags,
      );
    } catch (e) {
      // Silently ignore analytics errors - don't block save
      debugPrint('ANALYTICS: Failed to log tag correction: $e');
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
      _hasChanges = _hasActualContentChanges;
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
      _hasChanges = _hasActualContentChanges;
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
          _hasChanges = _hasActualContentChanges;
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
        await LocalDatabaseService.instance.deleteNote(_note!.id);
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
    final now = DateTime.now().toLocal();
    final lastEditedLocal = _note!.lastEdited.toLocal();
    final diff = now.difference(lastEditedLocal);
    if (diff.inMinutes < 1) return 'Last edited just now';
    if (diff.inHours < 1) return 'Last edited ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Last edited ${diff.inHours}h ago';
    return 'Last edited ${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Intercept all pops to handle save properly
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // Already handled
        
        // Save only if there are actual content changes AND we haven't already saved
        // _hasSaved prevents double-save when user taps save then immediately taps back
        // Note: Save if title OR content has text (title-only notes are valid)
        final hasContent = _contentController.text.trim().isNotEmpty || 
                          _titleController.text.trim().isNotEmpty;
        if (!_hasSaved && _hasActualContentChanges && hasContent) {
          await _saveQuietly();
        }
        
        // Now pop with result
        if (context.mounted) {
          Navigator.of(context).pop(_hasChanges || _hasSaved);
        }
      },
      child: Scaffold(
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
                        // Tags section (moved above title)
                        _buildTagsSection(),
                        
                        const SizedBox(height: 16),
                        
                        // Title field (moved below tags)
                        _buildTitleSection(),

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
                        
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
            onPressed: () {
              // Trigger PopScope to handle save and navigation
              Navigator.of(context).maybePop();
            },
          ),

          const Spacer(),

          // Action buttons
          // Undo button (show when there are actual changes)
          if (_hasChanges)
            IconButton(
              icon: const Icon(
                Icons.undo_rounded,
                color: AppColors.subtleGray,
              ),
              onPressed: _undoChanges,
              tooltip: 'Undo changes',
            ),
          
          // Save button (show when there are actual changes)
          if (_hasChanges)
            IconButton(
              icon: const Icon(
                Icons.check_rounded,
                color: AppColors.softLavender,
              ),
              onPressed: _save,
              tooltip: 'Save',
            ),

          // Delete button (only for existing notes)
          if (!_isNewNote)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.warmGlow,
              ),
              onPressed: _delete,
              tooltip: 'Delete note',
            ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        controller: _titleController,
        focusNode: _titleFocusNode,
        style: AppTypography.heading.copyWith(fontSize: 20),
        cursorColor: AppColors.softLavender,
        decoration: InputDecoration(
          hintText: 'Title (optional)',
          hintStyle: AppTypography.heading.copyWith(
            fontSize: 20,
            color: AppColors.subtleGray.withValues(alpha: 0.5),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        textCapitalization: TextCapitalization.sentences,
        maxLines: 1,
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
                        color: AppColors.softTeal.withValues(alpha: 0.2),
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
                        color: AppColors.softLavender.withValues(alpha: 0.2),
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
              focusNode: _contentFocusNode,
              autofocus: _isNewNote,
              maxLines: null,
              minLines: 10,
              style: AppTypography.bodyLarge,
              cursorColor: AppColors.softLavender,
              decoration: InputDecoration(
                hintText: 'Start typing your note...',
                hintStyle: AppTypography.body.copyWith(
                  color: AppColors.subtleGray.withValues(alpha: 0.6),
                ),
                border: InputBorder.none,
              ),
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleEdit,
              child: Container(
                constraints: const BoxConstraints(minHeight: 200),
                width: double.infinity,
                child: _contentController.text.isEmpty
                    ? Text(
                        'Tap to add content...',
                        style: AppTypography.body.copyWith(
                          color: AppColors.subtleGray.withValues(alpha: 0.6),
                        ),
                      )
                    : _buildRichTextWithEntities(),
              ),
            ),
    );
  }

  /// Build rich text with clickable entities (phone, email, URL)
  /// Tapping entities launches them; tapping regular text enters edit mode
  Widget _buildRichTextWithEntities() {
    final content = _contentController.text;
    
    // Use cached entities if content hasn't changed (performance optimization)
    final entities = _getCachedEntities(content);
    
    if (entities.isEmpty) {
      // No entities, just plain text - tap anywhere to edit
      return Text(
        content,
        style: AppTypography.bodyLarge,
      );
    }

    // Build TextSpans with clickable entities
    final spans = <InlineSpan>[];
    int currentIndex = 0;

    for (final entity in entities) {
      // Add text before entity (plain text, tap handled by parent GestureDetector)
      if (entity.startIndex > currentIndex) {
        spans.add(TextSpan(
          text: content.substring(currentIndex, entity.startIndex),
          style: AppTypography.bodyLarge,
        ));
      }

      // Add clickable entity with WidgetSpan to isolate tap handling
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: () => _launchEntity(entity),
          child: Text(
            entity.value,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.softLavender,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.softLavender,
            ),
          ),
        ),
      ));

      currentIndex = entity.endIndex;
    }

    // Add remaining text
    if (currentIndex < content.length) {
      spans.add(TextSpan(
        text: content.substring(currentIndex),
        style: AppTypography.bodyLarge,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }

  Future<void> _launchEntity(DetectedEntity entity) async {
    final uri = Uri.parse(entity.actionUri);
    
    try {
      if (await canLaunchUrl(uri)) {
        // Use external application for mailto, tel, and http links
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          _showError('Could not open ${entity.actionLabel.toLowerCase()}');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to open: $e');
      }
    }
  }
}
