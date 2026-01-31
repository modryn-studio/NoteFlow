import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/speech_service.dart';
import '../services/tagging_service.dart';
import '../services/local_database_service.dart';
import '../widgets/breathing_circle.dart';
import '../widgets/glass_button.dart';

/// Full-screen voice capture overlay
class VoiceCaptureScreen extends StatefulWidget {
  const VoiceCaptureScreen({super.key});

  @override
  State<VoiceCaptureScreen> createState() => _VoiceCaptureScreenState();
}

class _VoiceCaptureScreenState extends State<VoiceCaptureScreen>
    with TickerProviderStateMixin {
  final SpeechService _speechService = SpeechService.instance;
  final TextEditingController _textController = TextEditingController();

  bool _isListening = false;
  bool _isSpeechAvailable = false;
  bool _isTextMode = false;
  bool _isSaving = false;
  String _recognizedText = '';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    _isSpeechAvailable = await _speechService.initialize();
    if (!_isSpeechAvailable) {
      setState(() {
        _isTextMode = true;
      });
      _showErrorToast('Voice recognition not available on this device');
    } else {
      _startListening();
    }
  }

  void _showErrorToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.warmGlow.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _startListening() async {
    if (!_isSpeechAvailable) {
      setState(() {
        _isTextMode = true;
      });
      return;
    }

    setState(() {
      _isListening = true;
    });

    await _speechService.startListening(
      onResult: (text) {
        setState(() {
          _recognizedText = text;
        });
      },
      onComplete: () {
        setState(() {
          _isListening = false;
        });
      },
      onError: (error) {
        setState(() {
          _isListening = false;
          _isTextMode = true;
        });
        _showErrorToast('Voice error: $error. Switched to text input.');
      },
    );
  }

  Future<void> _stopListening() async {
    await _speechService.stopListening();
    setState(() {
      _isListening = false;
    });
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  void _switchToTextMode() {
    _stopListening();
    setState(() {
      _isTextMode = true;
      _textController.text = _recognizedText;
    });
  }

  Future<void> _saveNote() async {
    final content = _isTextMode ? _textController.text : _recognizedText;

    if (content.trim().isEmpty) {
      _showErrorToast('Please enter some content');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Auto-tag the content
      final tags = TaggingService.instance.autoTag(content);

      // Save to local database (no title for voice notes)
      await LocalDatabaseService.instance.createNote(null, content, tags);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showErrorToast('Failed to save note: $e');
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _cancel() async {
    await _speechService.cancelListening();
    await _fadeController.reverse();
    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _fadeController.dispose();
    // Cancel speech service - fire and forget (best effort)
    // Catch any errors to prevent dispose from throwing
    _speechService.cancelListening().catchError((e) {
      // Silently ignore errors during cleanup
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: AppColors.deepIndigo.withValues(alpha: 0.85),
            child: SafeArea(
              child: Column(
                children: [
                  // Close button
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.pearlWhite,
                          size: 28,
                        ),
                        onPressed: _cancel,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Main content area
                  if (_isTextMode) _buildTextInput() else _buildVoiceCapture(),

                  const Spacer(),

                  // Waveform visualization (voice mode only)
                  if (!_isTextMode) ...[
                    WaveformVisualizer(
                      isActive: _isListening,
                      height: 60,
                      color: AppColors.softLavender,
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GlassButton(
                          text: 'Cancel',
                          icon: Icons.close_rounded,
                          color: AppColors.subtleGray,
                          onTap: _cancel,
                        ),
                        const SizedBox(width: 16),
                        GlassButton(
                          text: 'Save',
                          icon: Icons.check_rounded,
                          color: AppColors.mintGlow,
                          isLoading: _isSaving,
                          onTap: _saveNote,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceCapture() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Breathing circle
        GestureDetector(
          onTap: _toggleListening,
          child: BreathingCircle(
            isActive: _isListening,
            size: 200,
            color: AppColors.softLavender,
          ),
        ),

        const SizedBox(height: 32),

        // Status text
        Text(
          _isListening ? 'Listening...' : 'Tap to start',
          style: AppTypography.headingSmall,
        ),

        const SizedBox(height: 24),

        // Recognized text
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(minHeight: 100),
          decoration: BoxDecoration(
            color: AppColors.glassTint.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.glassHighlight.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            _recognizedText.isEmpty ? 'Your words will appear here...' : _recognizedText,
            style: _recognizedText.isEmpty
                ? AppTypography.body.copyWith(color: AppColors.subtleGray)
                : AppTypography.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 16),

        // Switch to text mode button
        TextButton.icon(
          onPressed: _switchToTextMode,
          icon: const Icon(
            Icons.keyboard_rounded,
            color: AppColors.softLavender,
            size: 18,
          ),
          label: Text(
            'Type instead',
            style: AppTypography.caption.copyWith(
              color: AppColors.softLavender,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Text input icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.softLavender.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.edit_rounded,
              size: 36,
              color: AppColors.softLavender,
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Enter your note',
            style: AppTypography.headingSmall,
          ),

          const SizedBox(height: 24),

          // Text field
          Container(
            decoration: BoxDecoration(
              color: AppColors.glassTint.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.glassHighlight.withValues(alpha: 0.3),
              ),
            ),
            child: TextField(
              controller: _textController,
              autofocus: true,
              maxLines: 6,
              minLines: 4,
              style: AppTypography.bodyLarge,
              cursorColor: AppColors.softLavender,
              decoration: InputDecoration(
                hintText: 'Start typing...',
                hintStyle: AppTypography.body.copyWith(
                  color: AppColors.subtleGray.withValues(alpha: 0.6),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),

          if (_isSpeechAvailable) ...[
            const SizedBox(height: 16),

            // Switch to voice mode button
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isTextMode = false;
                  _recognizedText = _textController.text;
                });
                _startListening();
              },
              icon: const Icon(
                Icons.mic_rounded,
                color: AppColors.softLavender,
                size: 18,
              ),
              label: Text(
                'Use voice instead',
                style: AppTypography.caption.copyWith(
                  color: AppColors.softLavender,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
