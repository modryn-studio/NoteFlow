import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/note_model.dart';
import '../services/supabase_service.dart';
import '../services/frequency_tracker.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_search_bar.dart';
import '../widgets/note_card.dart';
import 'note_detail_screen.dart';
import 'voice_capture_screen.dart';

/// Main home screen with intelligent note surfacing
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<NoteModel> _allNotes = []; // Preserve original notes
  Map<NoteCategory, List<NoteModel>> _groupedNotes = {};
  bool _isLoading = true;
  String _searchQuery = '';

  // Multi-select mode state
  bool _isSelectionMode = false;
  final Set<String> _selectedNoteIds = {};

  // Track collapsed sections
  final Map<NoteCategory, bool> _collapsedSections = {
    NoteCategory.daily: false,
    NoteCategory.weekly: false,
    NoteCategory.monthly: false,
    NoteCategory.archive: true, // Archive collapsed by default
  };

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Enter selection mode
  void _enterSelectionMode(NoteModel note) {
    setState(() {
      _isSelectionMode = true;
      _selectedNoteIds.add(note.id);
    });
  }

  /// Exit selection mode
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedNoteIds.clear();
    });
  }

  /// Toggle note selection
  void _toggleNoteSelection(NoteModel note) {
    setState(() {
      if (_selectedNoteIds.contains(note.id)) {
        _selectedNoteIds.remove(note.id);
        // Exit selection mode if no notes selected
        if (_selectedNoteIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedNoteIds.add(note.id);
      }
    });
  }

  /// Select all visible notes
  void _selectAllNotes() {
    setState(() {
      for (final category in _groupedNotes.values) {
        for (final note in category) {
          _selectedNoteIds.add(note.id);
        }
      }
    });
  }

  /// Batch delete selected notes with progress dialog
  Future<void> _batchDeleteSelected() async {
    if (_selectedNoteIds.isEmpty) return;

    final selectedCount = _selectedNoteIds.length;

    // Confirm deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkPurple,
        title: Text(
          'Delete $selectedCount Notes',
          style: AppTypography.heading,
        ),
        content: Text(
          'Are you sure you want to delete $selectedCount selected notes? This cannot be undone.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTypography.body.copyWith(color: AppColors.subtleGray),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: AppTypography.body.copyWith(color: AppColors.warmGlow),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Store selected IDs and cache notes BEFORE deletion for potential rollback
    final idsToDelete = _selectedNoteIds.toList();
    final notesBackup = _allNotes
        .where((note) => idsToDelete.contains(note.id))
        .toList();

    // Create a ValueNotifier to update dialog progress
    final progressNotifier = ValueNotifier<int>(0);

    // Capture navigator before async gap
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ValueListenableBuilder<int>(
        valueListenable: progressNotifier,
        builder: (context, progress, _) {
          return AlertDialog(
            backgroundColor: AppColors.darkPurple,
            title: Text('Deleting Notes', style: AppTypography.heading),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: selectedCount > 0 ? progress / selectedCount : 0,
                  backgroundColor: AppColors.glassTint,
                  color: AppColors.softLavender,
                ),
                const SizedBox(height: 16),
                Text(
                  'Deleting $progress of $selectedCount...',
                  style: AppTypography.body,
                ),
              ],
            ),
          );
        },
      ),
    );

    // Optimistic update: Remove notes from local state immediately
    setState(() {
      _allNotes.removeWhere((note) => idsToDelete.contains(note.id));
      _groupNotes(_allNotes);
      _exitSelectionMode();
    });

    // Perform batch delete
    try {
      final failedIds = await SupabaseService.instance.batchDeleteNotes(
        idsToDelete,
        onProgress: (current, total) {
          progressNotifier.value = current;
        },
      );

      // Close progress dialog
      if (mounted) {
        navigator.pop();
      }

      // Dispose the progress notifier
      progressNotifier.dispose();

      // Show result
      if (failedIds.isEmpty) {
        _showSuccess('$selectedCount notes deleted');
      } else {
        // Rollback failed notes using the cached backup
        final failedNotes = notesBackup
            .where((note) => failedIds.contains(note.id))
            .toList();

        // Re-add failed notes to local state
        if (failedNotes.isNotEmpty) {
          setState(() {
            _allNotes.addAll(failedNotes);
            _groupNotes(_allNotes);
          });
        }

        _showError('Failed to delete ${failedIds.length} notes');
      }
    } catch (e) {
      // Dispose the progress notifier
      progressNotifier.dispose();

      // Close progress dialog
      if (mounted) {
        navigator.pop();
      }

      _showError('Delete failed: $e');

      // Reload notes to restore state
      await _loadNotes();
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.mintGlow.withValues(alpha: 0.9),
      ),
    );
  }

  Future<void> _loadNotes({bool skipGrouping = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notes = await SupabaseService.instance.fetchNotes();
      _allNotes = notes; // Store original

      // Skip grouping if we're going to search immediately after
      if (!skipGrouping) {
        _groupNotes(notes);
      }
    } catch (e) {
      _showError('Failed to load notes: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _groupNotes(List<NoteModel> notes) {
    _groupedNotes = FrequencyTracker.instance.groupNotesByCategory(notes);
    setState(() {});
  }

  Future<void> _searchNotes(String query) async {
    _searchQuery = query;

    if (query.isEmpty) {
      // Restore original notes when search is cleared
      setState(() {
        _groupNotes(_allNotes);
      });
      return;
    }

    try {
      final results = await SupabaseService.instance.searchNotes(query);
      setState(() {
        _groupNotes(results);
      });
    } catch (e) {
      _showError('Search failed: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.warmGlow),
    );
  }

  void _openNote(NoteModel note) async {
    // Capture search query before async operation to detect changes
    final searchQueryBeforeNav = _searchQuery;

    // Track frequency - no longer fire-and-forget to avoid race condition
    // This ensures database is updated before we reload notes
    try {
      await FrequencyTracker.instance.trackNoteOpen(note.id);
    } catch (error) {
      // Silently log tracking errors, but continue navigation
      // ignore: avoid_print
      print('ERROR: Failed to track note open: $error');
    }

    if (!mounted) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => NoteDetailScreen(note: note)),
    );

    if (!mounted) return;

    // Check if search query changed during navigation
    final searchQueryAfterNav = _searchQuery;

    // Always refresh to pick up updated lastAccessed timestamp
    // Skip grouping if search is active to avoid flicker
    await _loadNotes(skipGrouping: searchQueryAfterNav.isNotEmpty);

    if (!mounted) return;

    // Only re-apply search if query hasn't changed during async operations
    if (searchQueryAfterNav.isNotEmpty &&
        searchQueryBeforeNav == searchQueryAfterNav) {
      _searchNotes(searchQueryAfterNav);
    }
  }

  void _openVoiceCapture() async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const VoiceCaptureScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    if (result == true) {
      _loadNotes();
    }
  }

  Future<void> _deleteNote(NoteModel note) async {
    // Optimistic update: Remove from local state immediately
    setState(() {
      _allNotes.removeWhere((n) => n.id == note.id);
      // Re-group notes to update UI instantly without flicker
      _groupNotes(_allNotes);
    });

    try {
      await SupabaseService.instance.deleteNote(note.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Note deleted'),
          backgroundColor: AppColors.darkPurple,
        ),
      );
    } catch (e) {
      // Rollback: Re-add the note on failure
      setState(() {
        _allNotes.add(note);
        _groupNotes(_allNotes);
      });
      _showError('Failed to delete note: $e');
    }
  }

  void _createTextNote() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const NoteDetailScreen(note: null),
      ),
    );

    if (result == true) {
      _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'NoteFlow',
                      style: AppTypography.heading.copyWith(fontSize: 28),
                    ),
                    Row(
                      children: [
                        // Text note button
                        IconButton(
                          icon: const Icon(
                            Icons.add_rounded,
                            color: AppColors.pearlWhite,
                          ),
                          onPressed: _createTextNote,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Search bar
              GlassSearchBar(
                controller: _searchController,
                onChanged: _searchNotes,
                hintText: 'Search notes...',
              ),

              // Notes list
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.softLavender,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNotes,
                        color: AppColors.softLavender,
                        backgroundColor: AppColors.darkPurple,
                        child: _buildNotesList(),
                      ),
              ),
            ],
          ),
        ),
      ),
      // Selection mode floating action bar
      bottomNavigationBar: _isSelectionMode ? _buildSelectionActionBar() : null,
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: _openVoiceCapture,
              backgroundColor: AppColors.softLavender,
              child: const Icon(
                Icons.mic_rounded,
                color: AppColors.deepIndigo,
                size: 28,
              ),
            ),
    );
  }

  /// Build floating action bar for selection mode
  Widget _buildSelectionActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkPurple,
        border: Border(
          top: BorderSide(
            color: AppColors.glassHighlight.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Cancel button
            TextButton.icon(
              onPressed: _exitSelectionMode,
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.subtleGray,
              ),
              label: Text(
                'Cancel',
                style: AppTypography.body.copyWith(color: AppColors.subtleGray),
              ),
            ),

            // Select All button
            TextButton.icon(
              onPressed: _selectAllNotes,
              icon: const Icon(
                Icons.select_all_rounded,
                color: AppColors.softLavender,
              ),
              label: Text(
                'Select All',
                style: AppTypography.body.copyWith(
                  color: AppColors.softLavender,
                ),
              ),
            ),

            // Delete button
            TextButton.icon(
              onPressed: _selectedNoteIds.isEmpty ? null : _batchDeleteSelected,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: _selectedNoteIds.isEmpty
                    ? AppColors.subtleGray.withValues(alpha: 0.5)
                    : AppColors.warmGlow,
              ),
              label: Text(
                'Delete (${_selectedNoteIds.length})',
                style: AppTypography.body.copyWith(
                  color: _selectedNoteIds.isEmpty
                      ? AppColors.subtleGray.withValues(alpha: 0.5)
                      : AppColors.warmGlow,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesList() {
    // Check if any notes exist in grouped results
    final hasAnyNotes = _groupedNotes.values.any((list) => list.isNotEmpty);

    if (!hasAnyNotes) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        for (final category in NoteCategory.values)
          if (_groupedNotes[category]?.isNotEmpty ?? false)
            _buildCategorySection(category),
      ],
    );
  }

  Widget _buildCategorySection(NoteCategory category) {
    final notes = _groupedNotes[category] ?? [];
    // Auto-expand sections during search to show matching results
    final isCollapsed = _searchQuery.isNotEmpty
        ? false
        : (_collapsedSections[category] ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header - entire row is tappable
        InkWell(
          onTap: () {
            setState(() {
              _collapsedSections[category] = !isCollapsed;
            });
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                // Category indicator dots
                _buildCategoryIndicator(category, notes.length),
                const SizedBox(width: 12),

                // Category name
                Text(
                  FrequencyTracker.getCategoryName(category),
                  style: AppTypography.headingSmall.copyWith(
                    color: _getCategoryColor(category),
                  ),
                ),

                const SizedBox(width: 8),

                // Note count
                Text('(${notes.length})', style: AppTypography.caption),

                const Spacer(),

                // Collapse indicator
                AnimatedRotation(
                  turns: isCollapsed ? -0.25 : 0,
                  duration: AppAnimations.fast,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.subtleGray,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Notes - Use ListView to prevent flicker on delete
        if (!isCollapsed)
          ...notes.map((note) {
            return NoteCard(
              key: ValueKey(note.id),
              note: note,
              onTap: _isSelectionMode
                  ? () => _toggleNoteSelection(note)
                  : () => _openNote(note),
              onLongPress: _isSelectionMode
                  ? null
                  : () => _enterSelectionMode(note),
              onDelete: _isSelectionMode ? null : () => _deleteNote(note),
              isSelectionMode: _isSelectionMode,
              isSelected: _selectedNoteIds.contains(note.id),
              onSelectionToggle: () => _toggleNoteSelection(note),
            );
          }),
      ],
    );
  }

  Widget _buildCategoryIndicator(NoteCategory category, int count) {
    final color = _getCategoryColor(category);
    final maxDots = 5;
    final dotsToShow = count.clamp(1, maxDots);

    return Row(
      children: List.generate(dotsToShow, (index) {
        return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
            ],
          ),
        );
      }),
    );
  }

  Color _getCategoryColor(NoteCategory category) {
    switch (category) {
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

  Widget _buildEmptyState() {
    return Center(
      child: GlassCard(
        margin: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_add_outlined,
              size: 64,
              color: AppColors.softLavender.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No notes yet' : 'No notes found',
              style: AppTypography.headingSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Tap the mic button to create your first note'
                  : 'Try a different search term',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
