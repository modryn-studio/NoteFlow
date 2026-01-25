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
    _isListening = false;
    // Error handling - can be extended with callback
  }

  /// Status callback
  void _onStatus(String status) {
    _isListening = status == 'listening';
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

    _isListening = true;

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords);
        if (result.finalResult) {
          _isListening = false;
          onComplete();
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: localeId,
      cancelOnError: true,
      partialResults: true,
    );
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  /// Cancel listening
  Future<void> cancelListening() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
    }
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

  SpeechResult({
    required this.text,
    required this.isFinal,
  });
}
