import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../core/theme/app_theme.dart';
import '../models/note_model.dart';
import '../services/supabase_service.dart';
import '../services/frequency_tracker.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_search_bar.dart';
import '../widgets/note_card.dart';
import 'note_detail_screen.dart';
import 'voice_capture_screen.dart';

enum SortMode { smart, recent }

/// Main home screen with intelligent note surfacing
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<NoteModel> _allNotes = []; // Preserve original notes
  Map<NoteCategory, List<NoteModel>> _groupedNotes = {};
  bool _isLoading = true;
  String _searchQuery = '';
  SortMode _sortMode = SortMode.smart;

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
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadSortPreference();
    await _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString('sort_mode') ?? 'smart';
    setState(() {
      _sortMode = savedMode == 'recent' ? SortMode.recent : SortMode.smart;
    });
  }

  Future<void> _saveSortPreference(SortMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sort_mode', mode == SortMode.recent ? 'recent' : 'smart');
  }

  void _toggleSortMode() {
    setState(() {
      _sortMode = _sortMode == SortMode.smart ? SortMode.recent : SortMode.smart;
    });
    _saveSortPreference(_sortMode);
    _groupNotes(_allNotes); // Re-sort with new mode
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

    if (!mounted) return;

    // Capture navigator and context before async gap
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

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
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('$selectedCount notes deleted'),
              backgroundColor: AppColors.mintGlow.withValues(alpha: 0.9),
            ),
          );
        }
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

        // Show detailed error with note titles
        final failedTitles = failedNotes
            .map((n) => n.displayTitle)
            .take(3)
            .join(', ');
        final moreCount = failedNotes.length > 3 ? ' and ${failedNotes.length - 3} more' : '';
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $failedTitles$moreCount'),
              backgroundColor: AppColors.warmGlow,
            ),
          );
        }
      }
    } catch (e) {
      // Close progress dialog
      if (mounted) {
        navigator.pop();
      }

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: AppColors.warmGlow,
          ),
        );
      }

      // Reload notes to restore state
      await _loadNotes();
    } finally {
      // Ensure progress notifier is always disposed
      progressNotifier.dispose();
    }
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
    // Group by category first
    final grouped = <NoteCategory, List<NoteModel>>{
      NoteCategory.daily: [],
      NoteCategory.weekly: [],
      NoteCategory.monthly: [],
      NoteCategory.archive: [],
    };

    for (final note in notes) {
      grouped[note.category]!.add(note);
    }

    // Sort each category based on current sort mode
    for (final category in grouped.keys) {
      if (_sortMode == SortMode.smart) {
        // Smart: Sort by frequency count (most accessed first)
        grouped[category]!.sort(
          (a, b) => b.frequencyCount.compareTo(a.frequencyCount),
        );
      } else {
        // Recent: Sort by last edited (most recent first)
        grouped[category]!.sort(
          (a, b) => b.lastEdited.compareTo(a.lastEdited),
        );
      }
    }

    _groupedNotes = grouped;
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
    // Unfocus search bar before navigation
    FocusScope.of(context).unfocus();
    
    // Capture search query before async operation to detect changes
    final searchQueryBeforeNav = _searchQuery;

    // Navigate immediately for instant feel
    if (!mounted) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => NoteDetailScreen(note: note)),
    );

    if (!mounted) return;

    // Unfocus search bar again after returning to prevent auto-focus
    _searchFocusNode.unfocus();

    // Track frequency and wait for completion so UI shows updated count on return
    // Ignore errors since this is non-critical
    await FrequencyTracker.instance.trackNoteOpen(note.id).catchError((error) {
      // Silently handle tracking errors (non-critical feature)
      debugPrint('Failed to track note open: $error');
      return note; // Return original note on error
    });

    // Check if search query changed during navigation
    final searchQueryAfterNav = _searchQuery;

    // Always refresh to pick up updated lastAccessed timestamp
    // Skip grouping if search is active to avoid flicker
    await _loadNotes(skipGrouping: searchQueryAfterNav.isNotEmpty);

    if (!mounted) return;

    // Only re-apply search if query hasn't changed during async operations
    if (searchQueryAfterNav.isNotEmpty &&
        searchQueryBeforeNav == searchQueryAfterNav) {
      // Extra mounted check before modifying state
      if (!mounted) return;
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
    return PopScope(
      canPop: !_isSelectionMode && !_searchFocusNode.hasFocus && _searchQuery.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Priority 1: Exit selection mode
          if (_isSelectionMode) {
            _exitSelectionMode();
          }
          // Priority 2: Close keyboard if search is focused
          else if (_searchFocusNode.hasFocus) {
            setState(() {
              _searchFocusNode.unfocus();
            });
          }
          // Priority 3: Clear search if keyboard is already closed
          else if (_searchQuery.isNotEmpty) {
            _searchController.clear();
            _searchNotes('');
          }
        }
      },
      child: Scaffold(
        body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Dismiss keyboard when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: Container(
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
                          // Sort toggle button
                          GestureDetector(
                            onTap: _toggleSortMode,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.darkPurple.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.softLavender.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _sortMode == SortMode.smart
                                        ? Icons.psychology_outlined
                                        : Icons.schedule_outlined,
                                    size: 16,
                                    color: AppColors.softLavender,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _sortMode == SortMode.smart ? 'Smart' : 'Recent',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.softLavender,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                  focusNode: _searchFocusNode,
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
