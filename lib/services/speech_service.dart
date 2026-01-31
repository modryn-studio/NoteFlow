import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// Service for handling speech-to-text functionality
class SpeechService {
  static SpeechService? _instance;
  static SpeechService get instance => _instance ??= SpeechService._();

  SpeechService._();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  bool _shouldKeepListening = false;  // Flag to auto-restart
  Function(String)? _currentOnResult;
  String _currentLocaleId = 'en_US';
  String _accumulatedText = '';  // Accumulate text across sessions

  /// Check if speech recognition is available on device
  bool get isAvailable => _isInitialized;

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );
      return _isInitialized;
    } catch (e) {
      _isInitialized = false;
      return false;
    }
  }

  /// Error callback
  void _onError(SpeechRecognitionError error) {
    // Ignore "no match" errors and restart - this happens during pauses
    if (error.errorMsg == 'error_no_match' && _shouldKeepListening) {
      _isListening = false;
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_shouldKeepListening) {
          _restartListening();
        }
      });
      return;
    }
    
    _isListening = false;
    // Error handling - can be extended with callback
  }

  /// Status callback
  void _onStatus(String status) {
    _isListening = status == 'listening';
    
    // Auto-restart when it goes to "done" if we want to keep listening
    if (status == 'done' && _shouldKeepListening) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_shouldKeepListening) {
          _restartListening();
        }
      });
    }
  }

  /// Start listening for speech
  Future<void> startListening({
    required Function(String text) onResult,
    required Function() onComplete,
    Function(String error)? onError,
    String localeId = 'en_US',
  }) async {
    if (!_isInitialized) {
      final available = await initialize();
      if (!available) {
        onError?.call('Speech recognition not available on this device');
        return;
      }
    }

    if (_isListening) {
      await stopListening();
    }

    // Store callbacks for auto-restart
    _currentOnResult = onResult;
    _currentLocaleId = localeId;
    _shouldKeepListening = true;
    _accumulatedText = '';  // Reset accumulated text for new session
    
    await _startListeningInternal();
  }

  /// Internal method to start/restart listening
  Future<void> _startListeningInternal() async {
    _isListening = true;
    String currentSegmentText = '';  // Track current segment

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        currentSegmentText = result.recognizedWords;
        
        // Combine accumulated text with current segment
        final fullText = _accumulatedText.isEmpty 
            ? currentSegmentText 
            : '$_accumulatedText $currentSegmentText';
        
        _currentOnResult?.call(fullText);
        
        // When segment finalizes, save it to accumulated
        if (result.finalResult) {
          if (currentSegmentText.isNotEmpty) {
            _accumulatedText = _accumulatedText.isEmpty
                ? currentSegmentText
                : '$_accumulatedText $currentSegmentText';
          }
        }
      },
      listenFor: const Duration(minutes: 10),
      pauseFor: const Duration(minutes: 10),
      localeId: _currentLocaleId,
      onSoundLevelChange: null,
      listenOptions: SpeechListenOptions(
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  /// Restart listening (called automatically after "done" status)
  Future<void> _restartListening() async {
    if (_shouldKeepListening && !_isListening) {
      await _startListeningInternal();
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    _shouldKeepListening = false;  // Prevent auto-restart
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
    _accumulatedText = '';  // Clear accumulated text
  }

  /// Cancel listening
  Future<void> cancelListening() async {
    _shouldKeepListening = false;  // Prevent auto-restart
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
    }
    _accumulatedText = '';  // Clear accumulated text
  }

  /// Get available locales
  Future<List<LocaleName>> getLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _speech.locales();
  }

  /// Dispose resources
  void dispose() {
    _speech.cancel();
    _isListening = false;
  }
}

/// Result class for speech recognition
class SpeechResult {
  final String text;
  final bool isFinal;

  SpeechResult({required this.text, required this.isFinal});
}
