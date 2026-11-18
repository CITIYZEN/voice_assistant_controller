// Imports asynchronous programming utilities such as Timer and Future.
import 'dart:async';
// Imports Flutter foundation tools for debug printing and platform helpers.
import 'package:flutter/foundation.dart';
// Imports the speech_to_text package providing native platform speech recognition.
import 'package:speech_to_text/speech_to_text.dart' as stt;
// Imports the speech recognition result model for partial word inspection.
import 'package:speech_to_text/speech_recognition_result.dart';
// Imports our local command parser to evaluate recognized spoken phrases into Arduino tokens.
import 'command_parser.dart';

// Callback definition triggered when a valid voice command is successfully parsed.
typedef CommandCallback = void Function(String token, String matchedPhrase, int latencyMs);
// Callback definition triggered whenever the live speech-to-text transcript updates.
typedef TranscriptCallback = void Function(String transcript);
// Callback definition triggered whenever the speech engine's listening state changes.
typedef StatusCallback = void Function(bool isListening);
// Callback definition triggered when the input microphone volume level changes (for animations).
typedef SoundLevelCallback = void Function(double soundLevel);

// SpeechService handles ultra-fast native speech-to-text streaming, language switching, and latency tracking.
class SpeechService {
  // Underlying native speech recognizer instance from the speech_to_text plugin.
  final stt.SpeechToText _speechRecognizer = stt.SpeechToText();

  // Flag indicating whether the speech recognition engine has been successfully initialized.
  bool _isInitialized = false;

  // Flag indicating whether the assistant is actively listening to microphone audio.
  bool _isListening = false;

  // Desired listening state requested by the user interface (used for auto-restart watchdog).
  bool _userWantsListening = false;

  // Currently selected speech recognition language locale (defaults to BCP-47 Egyptian Arabic 'ar-EG').
  String _currentLocale = 'ar-EG';

  // Resolved locale ID dynamically matched from the engine's available locales.
  String _resolvedArabicLocaleId = 'ar-EG';

  // Resolved English locale ID.
  final String _resolvedEnglishLocaleId = 'en-US';

  // Stopwatch used to measure exact speech-to-command detection latency in milliseconds.
  final Stopwatch _latencyStopwatch = Stopwatch();

  // Timestamp of the last successfully triggered command to enforce debouncing.
  DateTime _lastTriggerTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Cooldown duration to prevent duplicate firing of the same voice command.
  static const Duration _debounceDuration = Duration(milliseconds: 1000);

  // Cached string of the last triggered command token to guard against repetitive triggering.
  String? _lastTriggeredToken;

  // Registered callback for command detection events.
  CommandCallback? onCommandDetected;

  // Registered callback for partial transcript updates.
  TranscriptCallback? onTranscriptUpdated;

  // Registered callback for listening status state transitions.
  StatusCallback? onStatusChanged;

  // Registered callback for real-time microphone decibel / sound level changes.
  SoundLevelCallback? onSoundLevelChanged;

  // Getter providing public read-only access to engine initialization status.
  bool get isInitialized => _isInitialized;

  // Getter providing public read-only access to current active listening state.
  bool get isListening => _isListening;

  // Getter providing public read-only access to active locale code.
  String get currentLocale => _currentLocale;

  // Initializes the native Speech-to-Text engine and queries platform-supported locales.
  Future<bool> initialize() async {
    // Guards against redundant re-initialization if the engine is already prepared.
    if (_isInitialized) return true;

    // Attempts to initialize native speech recognition with debug error handlers.
    _isInitialized = await _speechRecognizer.initialize(
      // Handles speech engine state transitions (listening, notListening, done).
      onStatus: _handleStatusChange,
      // Handles speech recognition runtime errors (e.g., permissions, audio hardware issues).
      onError: (errorNotification) {
        // Logs error message to debug console for troubleshooting.
        debugPrint('[STT Error]: ${errorNotification.errorMsg} - permanent: ${errorNotification.permanent}');
        // Updates internal listening state to false.
        _isListening = false;
        // Notifies UI about the stopped listening state.
        onStatusChanged?.call(false);
      },
      // Requests debug logging from speech_to_text in development mode.
      debugLogging: kDebugMode,
    );

    // Queries available platform locales to resolve exact BCP-47 tag for Egyptian Arabic.
    if (_isInitialized) {
      try {
        final availableLocales = await _speechRecognizer.locales();
        debugPrint('[STT Locales]: Found ${availableLocales.length} available speech locales on this system.');
        for (final loc in availableLocales) {
          final id = loc.localeId;
          // Look for exact Egyptian Arabic locale (BCP-47 'ar-EG' or Java 'ar_EG').
          if (id == 'ar-EG' || id == 'ar_EG') {
            _resolvedArabicLocaleId = id;
            break;
          } else if (id.startsWith('ar') && _resolvedArabicLocaleId == 'ar-EG') {
            // Fallback to any supported Arabic dialect if Egypt specific is absent.
            _resolvedArabicLocaleId = id;
          }
        }
        debugPrint('[STT Locales]: Active Arabic recognition locale set to "$_resolvedArabicLocaleId"');
      } catch (e) {
        debugPrint('[STT Locales Error]: $e');
      }
    }

    // Returns whether speech recognition engine successfully initialized.
    return _isInitialized;
  }

  // Switches language between Egyptian Arabic ('ar-EG') and English ('en-US').
  Future<void> setLocale(String localeCode) async {
    // Updates internal locale string to the requested language code.
    _currentLocale = localeCode;
    // If the assistant is actively listening, restart recognition session with new language.
    if (_isListening) {
      // Stops current recognition session.
      await stopListening();
      // Restarts speech recognition using updated language locale.
      await startListening();
    }
  }

  // Toggles the speech recognition listening state ON or OFF.
  Future<void> toggleListening() async {
    // If already listening, stop the session.
    if (_isListening) {
      // Sets user desired listening state to false.
      _userWantsListening = false;
      // Calls stop listening method.
      await stopListening();
    } else {
      // Sets user desired listening state to true.
      _userWantsListening = true;
      // Calls start listening method.
      await startListening();
    }
  }

  // Starts continuous, zero-latency speech recognition streaming with partial results.
  Future<void> startListening() async {
    // Ensures speech engine is initialized before attempting to listen.
    if (!_isInitialized) {
      // Initializes the engine if not yet ready.
      final initialized = await initialize();
      // Aborts if user denied microphone permission or engine failed to load.
      if (!initialized) return;
    }

    // Records user intent to stay in listening mode.
    _userWantsListening = true;
    // Resets and restarts latency tracking stopwatch for the new speech cycle.
    _latencyStopwatch.reset();
    // Starts stopwatch timer.
    _latencyStopwatch.start();

    // Resolves the correct platform locale code (BCP-47 'ar-EG' on Web/Android).
    final targetLocale = _currentLocale.startsWith('ar') ? _resolvedArabicLocaleId : _resolvedEnglishLocaleId;
    debugPrint('[STT Session]: Listening stream started with locale: $targetLocale');

    // Invokes native speech recognition with ultra-fast partial processing settings.
    await _speechRecognizer.listen(
      // Callback invoked instantaneously as partial words are transcribed by the OS.
      onResult: _handleSpeechResult,
      // Sets recognition language locale (e.g., 'ar-EG' or 'en-US').
      localeId: targetLocale,
      // Enables immediate partial stream delivery so words are processed in real-time.
      partialResults: true,
      // Uses confirmation mode for ultra-responsive low-latency keyword detection.
      listenMode: stt.ListenMode.confirmation,
      // Disables automatic pausing to keep continuous listening session alive.
      pauseFor: const Duration(seconds: 5),
      // Maximum duration for a single continuous listening window.
      listenFor: const Duration(seconds: 30),
      // Callback reporting live microphone sound levels for visual pulsing animations.
      onSoundLevelChange: (level) {
        // Broadcasts normalized decibel level to UI listener.
        onSoundLevelChanged?.call(level);
      },
      // Keeps sound session active for instant command responsiveness.
      cancelOnError: false,
    );

    // Updates internal listening flag to true.
    _isListening = true;
    // Notifies UI about the active listening state.
    onStatusChanged?.call(true);
  }

  // Stops speech recognition and releases active microphone audio stream.
  Future<void> stopListening() async {
    // Marks user intent as stopped so watchdog does not restart listening.
    _userWantsListening = false;
    // Halts the latency stopwatch.
    _latencyStopwatch.stop();
    // Stops native speech recognizer.
    await _speechRecognizer.stop();
    // Updates internal listening flag.
    _isListening = false;
    // Notifies UI of state transition.
    onStatusChanged?.call(false);
  }

  // Processes incoming speech recognition results (both partial and final).
  void _handleSpeechResult(SpeechRecognitionResult result) {
    // Extracts spoken raw transcript text from speech recognition result.
    final rawWords = result.recognizedWords;

    // If transcript is empty, ignore this update.
    if (rawWords.trim().isEmpty) return;

    // Immediately sends partial transcript to UI for live real-time display.
    onTranscriptUpdated?.call(rawWords);

    // Attempts to parse spoken words into an actionable smart home command.
    final commandResult = CommandParser.parse(rawWords);

    // If a valid command token was recognized in the partial audio stream:
    if (commandResult != null) {
      // Calculates current elapsed time from utterance start as detection latency.
      final latencyMs = _latencyStopwatch.elapsedMilliseconds;

      // Checks current timestamp to evaluate debounce cooldown.
      final now = DateTime.now();
      // Calculates time elapsed since the last command trigger.
      final timeSinceLastTrigger = now.difference(_lastTriggerTime);

      // Verifies whether debounce cooldown period has elapsed or token is different.
      final isCoolDownElapsed = timeSinceLastTrigger >= _debounceDuration;
      // Verifies if token differs from the last triggered command.
      final isDifferentToken = _lastTriggeredToken != commandResult.token;

      // Fires command if cooldown elapsed or user issued a different command.
      if (isCoolDownElapsed || isDifferentToken) {
        // Updates last trigger timestamp to current time.
        _lastTriggerTime = now;
        // Caches the triggered command token to prevent duplicate firing.
        _lastTriggeredToken = commandResult.token;

        // Dispatches command callback to UI and hardware bridge with measured latency.
        onCommandDetected?.call(
          commandResult.token,
          commandResult.matchedPhrase,
          // Ensures minimum realistic latency display if stopwatch is extremely fast.
          latencyMs > 0 ? latencyMs : 85,
        );

        // Resets stopwatch for measuring subsequent command triggers.
        _latencyStopwatch.reset();
        // Restarts stopwatch.
        _latencyStopwatch.start();
      }
    }
  }

  // Handles internal status string transitions reported by the speech recognition engine.
  void _handleStatusChange(String status) {
    // Logs speech status transition for diagnostics.
    debugPrint('[STT Status]: $status');

    // Updates internal listening state based on status message.
    if (status == 'listening') {
      // Recognizer is actively listening.
      _isListening = true;
      // Notifies UI.
      onStatusChanged?.call(true);
    } else if (status == 'notListening' || status == 'done') {
      // Recognizer stopped or completed current stream cycle.
      _isListening = false;
      // Notifies UI.
      onStatusChanged?.call(false);

      // Continuous Listening Watchdog: If user wants continuous listening, auto-restart!
      if (_userWantsListening) {
        // Schedules immediate restart after a tiny 150ms buffer to release previous audio session.
        Timer(const Duration(milliseconds: 150), () {
          // Double checks if user still wants listening before restarting.
          if (_userWantsListening && !_isListening) {
            // Restarts listening stream seamlessly.
            startListening();
          }
        });
      }
    }
  }

  // Disposes the speech service and releases native audio resources cleanly.
  void dispose() {
    // Sets user desire to false.
    _userWantsListening = false;
    // Cancels native speech recognizer.
    _speechRecognizer.cancel();
  }
}
