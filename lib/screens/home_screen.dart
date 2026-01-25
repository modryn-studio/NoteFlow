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

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notes = await SupabaseService.instance.fetchNotes();
      _allNotes = notes; // Store original
      _groupNotes(notes);
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
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.warmGlow,
      ),
    );
  }

  void _openNote(NoteModel note) async {
    // Fire-and-forget frequency tracking (don't block navigation)
    FrequencyTracker.instance.trackNoteOpen(note.id).ignore();

    if (!mounted) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(note: note),
      ),
    );

    // Always refresh to pick up updated lastAccessed timestamp
    _loadNotes();
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
    try {
      await SupabaseService.instance.deleteNote(note.id);
      _loadNotes();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Note deleted'),
          backgroundColor: AppColors.darkPurple,
        ),
      );
    } catch (e) {
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
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
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
      floatingActionButton: FloatingActionButton(
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
                Text(
                  '(${notes.length})',
                  style: AppTypography.caption,
                ),

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

        // Notes
        AnimatedCrossFade(
          firstChild: Column(
            children: notes.map((note) {
              return NoteCard(
                note: note,
                onTap: () => _openNote(note),
                onDelete: () => _deleteNote(note),
              );
            }).toList(),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState:
              isCollapsed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: AppAnimations.fast,
        ),
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
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 4,
              ),
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
              color: AppColors.softLavender.withOpacity(0.5),
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
