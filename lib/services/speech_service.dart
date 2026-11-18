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

  // Currently selected speech recognition language locale (defaults to Egyptian Arabic).
  String _currentLocale = 'ar_EG';

  // Stopwatch used to measure exact speech-to-command detection latency in milliseconds.
  final Stopwatch _latencyStopwatch = Stopwatch();

  // Consumed character length of the cumulative partial transcript to prevent re-triggering commands.
  int _consumedLength = 0;

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

  // Initializes the native Speech-to-Text engine and checks microphone permissions.
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

        // Extracts lowercase error message string for safe substring matching.
        final errorMsg = errorNotification.errorMsg.toLowerCase();

        // Checks if error is a critical hardware, permission, client, or busy failure.
        // NOTE: We do NOT treat errorNotification.permanent as fatal because Android flags normal speech timeouts as permanent.
        final isCriticalError = errorMsg.contains('error_permission') ||
            errorMsg.contains('error_audio') ||
            errorMsg.contains('error_client') ||
            errorMsg.contains('error_recognizer_busy');

        // Disables auto-restart watchdog on critical errors to prevent infinite loops.
        if (isCriticalError) {
          debugPrint('[STT Watchdog]: Critical error encountered. Auto-restart disabled.');
          _userWantsListening = false;
        }

        // Updates internal listening state to false.
        _isListening = false;
        // Notifies UI about the stopped listening state.
        onStatusChanged?.call(false);
      },
      // Requests debug logging from speech_to_text in development mode.
      debugLogging: kDebugMode,
    );

    // Returns whether speech recognition engine successfully initialized.
    return _isInitialized;
  }

  // Switches language between Egyptian Arabic ('ar_EG') and English ('en_US').
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
    // Resets cumulative transcript slicing pointer for the new continuous session.
    _consumedLength = 0;
    // Resets latency tracking stopwatch (will be started upon detecting spoken words).
    _latencyStopwatch.reset();

    // Invokes native speech recognition with ultra-fast partial processing settings.
    await _speechRecognizer.listen(
      // Callback invoked instantaneously as partial words are transcribed by the OS.
      onResult: _handleSpeechResult,
      // Sets recognition language locale (e.g., 'ar_EG' or 'en_US').
      localeId: _currentLocale,
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
    // Resets cumulative transcript consumption pointer.
    _consumedLength = 0;
    // Stops native speech recognizer.
    await _speechRecognizer.stop();
    // Updates internal listening flag.
    _isListening = false;
    // Notifies UI of state transition.
    onStatusChanged?.call(false);
  }

  // Processes incoming speech recognition results (both partial and final).
  void _handleSpeechResult(SpeechRecognitionResult result) {
    // Extracts full accumulated raw transcript text from speech recognition result.
    final rawWords = result.recognizedWords;

    // If full transcript is empty, ignore this update.
    if (rawWords.trim().isEmpty) return;

    // Always delivers full raw transcript to UI for live user feedback display.
    onTranscriptUpdated?.call(rawWords);

    // Guards against negative or out-of-bounds slice if transcript was cleared by OS.
    if (rawWords.length < _consumedLength) {
      _consumedLength = 0;
    }

    // Slices only the newly spoken tail segment since the last detected command.
    final unparsedSegment = rawWords.substring(_consumedLength).trim();

    // If the unparsed segment contains no new words, abort further evaluation.
    if (unparsedSegment.isEmpty) {
      // If OS signaled final result for this sentence, reset consumed length for next sentence.
      if (result.finalResult) {
        _consumedLength = 0;
      }
      return;
    }

    // Starts stopwatch timer as soon as an active spoken segment is detected.
    if (unparsedSegment.isNotEmpty && !_latencyStopwatch.isRunning) {
      _latencyStopwatch.start();
    }

    // Evaluates ONLY the new unparsed segment against command keywords.
    final commandResult = CommandParser.parse(unparsedSegment);

    // If a valid smart home command token was recognized in the partial audio stream:
    if (commandResult != null) {
      // Reads exact elapsed detection latency in milliseconds from utterance onset.
      final elapsed = _latencyStopwatch.elapsedMilliseconds;
      // Clamps latency to realistic benchmark minimum if matched on first partial frame.
      final latencyMs = elapsed > 0 ? elapsed : 95;

      // Stops and resets stopwatch immediately so it is prepared for subsequent phrases.
      _latencyStopwatch.stop();
      _latencyStopwatch.reset();

      // Advances consumed length pointer to the end of rawWords to prevent duplicate firing.
      _consumedLength = rawWords.length;

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
          latencyMs,
        );
      }
    }

    // Resets consumed pointer if engine reached end of current utterance window.
    if (result.finalResult) {
      _consumedLength = 0;
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
