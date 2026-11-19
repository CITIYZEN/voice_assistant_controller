import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:voice_assistant_controller/services/speech_service.dart';

SpeechRecognitionResult createResult(String words, {bool isFinal = false}) {
  return SpeechRecognitionResult(
    [SpeechRecognitionWords(words, null, 0.95)],
    isFinal ? 1 : 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeechService Lifecycle & Configuration', () {
    test('Initializes with default Egyptian Arabic locale and inactive state', () {
      final service = SpeechService();
      expect(service.isInitialized, isFalse);
      expect(service.isListening, isFalse);
      expect(service.currentLocale, 'ar-EG');
    });

    test('Locale switching changes active language correctly', () async {
      final service = SpeechService();
      expect(service.currentLocale, 'ar-EG');

      await service.setLocale('en-US');
      expect(service.currentLocale, 'en-US');

      await service.setLocale('ar-EG');
      expect(service.currentLocale, 'ar-EG');
    });

    test('stopListening cleanly transitions state to inactive', () async {
      final service = SpeechService();
      bool? statusNotified;
      service.onStatusChanged = (listening) {
        statusNotified = listening;
      };

      await service.stopListening();
      expect(service.isListening, isFalse);
      expect(statusNotified, isFalse);

      service.dispose();
    });
  });

  group('One-Shot Auto-Stop & Silence Timeout', () {
    test('One-shot auto-stop: executing a valid command immediately stops listening', () async {
      final service = SpeechService();
      String? detectedToken;
      String? detectedPhrase;
      bool? statusReported;

      service.onCommandDetected = (token, phrase, latency) {
        detectedToken = token;
        detectedPhrase = phrase;
      };
      service.onStatusChanged = (isListening) {
        statusReported = isListening;
      };

      // Simulate listening state active
      service.handleStatusChange('listening');
      expect(service.isListening, isTrue);
      expect(statusReported, isTrue);

      // Simulate recognition result matching 'شغل النور' (Relay 1 ON)
      await service.handleSpeechResult(createResult('شغل النور'));

      // Validates command was dispatched
      expect(detectedToken, 'R1_ON');
      expect(detectedPhrase, 'شغل النور');

      // Validates one-shot auto-stop: mic is now OFF
      expect(service.isListening, isFalse);
      expect(statusReported, isFalse);

      service.dispose();
    });

    testWidgets('Auto-restart watchdog is completely removed: stays OFF after notListening', (tester) async {
      final service = SpeechService();
      service.handleStatusChange('listening');
      expect(service.isListening, isTrue);

      // Recognizer ends current stream
      service.handleStatusChange('notListening');
      expect(service.isListening, isFalse);

      // Elapse watchdog delay (150ms was the old watchdog timer)
      await tester.pump(const Duration(milliseconds: 500));
      expect(service.isListening, isFalse);

      // Elapse more time
      await tester.pump(const Duration(seconds: 5));
      expect(service.isListening, isFalse);

      service.dispose();
    });

    testWidgets('3-second silence timeout stops listening after 3s of inactivity', (tester) async {
      final service = SpeechService();
      bool? statusReported;
      service.onStatusChanged = (isListening) {
        statusReported = isListening;
      };

      service.handleStatusChange('listening');
      expect(service.isListening, isTrue);
      expect(service.silenceTimer, isNotNull);

      // 2 seconds of silence -> still listening
      await tester.pump(const Duration(seconds: 2));
      expect(service.isListening, isTrue);

      // Advance 1.1 more seconds (total > 3s) -> silence timeout fires and auto-stops
      await tester.pump(const Duration(milliseconds: 1100));
      expect(service.isListening, isFalse);
      expect(statusReported, isFalse);
      expect(service.silenceTimer, isNull);

      service.dispose();
    });

    testWidgets('Silence timer resets when new speech words arrive', (tester) async {
      final service = SpeechService();
      service.handleStatusChange('listening');
      expect(service.isListening, isTrue);

      // 2 seconds elapse
      await tester.pump(const Duration(seconds: 2));
      expect(service.isListening, isTrue);

      // Non-command words arrive at 2s
      await service.handleSpeechResult(createResult('مساء الخير يا بيت'));

      // Advance another 2 seconds (total 4s from start, but only 2s since last speech)
      await tester.pump(const Duration(seconds: 2));
      expect(service.isListening, isTrue);

      // Advance 1.1 more seconds (total 3.1s since last speech) -> cuts off
      await tester.pump(const Duration(milliseconds: 1100));
      expect(service.isListening, isFalse);

      service.dispose();
    });

    testWidgets('Silence timer resets when sound level > 1.5 occurs', (tester) async {
      final service = SpeechService();
      service.handleStatusChange('listening');
      expect(service.isListening, isTrue);

      // 2 seconds elapse
      await tester.pump(const Duration(seconds: 2));
      expect(service.isListening, isTrue);

      // Audible sound occurs (> 1.5)
      service.resetSilenceTimer();

      // Advance 2 seconds -> still listening
      await tester.pump(const Duration(seconds: 2));
      expect(service.isListening, isTrue);

      // Advance 1.1 seconds -> times out
      await tester.pump(const Duration(milliseconds: 1100));
      expect(service.isListening, isFalse);

      service.dispose();
    });

    test('New listening session clears debounce to allow repeating the same command', () async {
      final service = SpeechService();
      int triggerCount = 0;
      service.onCommandDetected = (token, phrase, latency) {
        triggerCount++;
      };

      // Session 1: Say "turn on fan"
      service.handleStatusChange('listening');
      await service.handleSpeechResult(createResult('turn on fan'));
      expect(triggerCount, 1);
      expect(service.isListening, isFalse);

      // Session 2: User taps mic and says the exact same command
      service.handleStatusChange('listening');
      await service.handleSpeechResult(createResult('turn on fan'));

      expect(triggerCount, 2);
      expect(service.isListening, isFalse);

      service.dispose();
    });

    test('Speech results received after listening stopped are ignored', () async {
      final service = SpeechService();
      int triggerCount = 0;
      service.onCommandDetected = (token, phrase, latency) {
        triggerCount++;
      };

      expect(service.isListening, isFalse);

      // Attempt speech result while inactive
      await service.handleSpeechResult(createResult('turn on fan'));

      expect(triggerCount, 0);
      expect(service.isListening, isFalse);

      service.dispose();
    });
  });
}
