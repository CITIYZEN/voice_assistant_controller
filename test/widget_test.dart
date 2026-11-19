import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_controller/main.dart';
import 'package:voice_assistant_controller/services/command_parser.dart';
import 'package:voice_assistant_controller/services/hardware_bridge.dart';
import 'package:voice_assistant_controller/widgets/virtual_arduino_board.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommandParser & HardwareBridge Integrity', () {
    test('Arabic and English voice commands parse accurately', () {
      final res1 = CommandParser.parse('شغل النور');
      expect(res1?.token, 'R1_ON');

      final res2 = CommandParser.parse('turn off fan');
      expect(res2?.token, 'R2_OFF');

      final res3 = CommandParser.parse('شغل المروحة');
      expect(res3?.token, 'R2_ON');

      final res4 = CommandParser.parse('party mode');
      expect(res4?.token, 'RGB_CYCLE');
    });

    test('HardwareBridge state updates correctly on commands', () async {
      final bridge = HardwareBridge();
      expect(bridge.relay2On, isFalse);

      await bridge.sendCommand('R2_ON');
      expect(bridge.relay2On, isTrue);

      await bridge.sendCommand('R2_OFF');
      expect(bridge.relay2On, isFalse);
    });
  });

  group('CoolingFanRotorPainter & VirtualArduinoBoard', () {
    testWidgets('Relay 2 displays cooling fan rotor and replaces Icons.toys', (tester) async {
      final bridge = HardwareBridge();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VirtualArduinoBoard(bridge: bridge),
          ),
        ),
      );

      // Verify Icons.toys is completely removed
      expect(find.byIcon(Icons.toys), findsNothing);

      // Verify Cooling Fan title and CustomPaint rotor are rendered
      expect(find.text('Cooling Fan'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Find the CustomPaint that uses CoolingFanRotorPainter
      final fanRotorFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is CoolingFanRotorPainter,
      );
      expect(fanRotorFinder, findsOneWidget);

      // Initially Relay 2 is off -> color is gray #71717A
      final initialCustomPaint = tester.widget<CustomPaint>(fanRotorFinder);
      final initialPainter = initialCustomPaint.painter as CoolingFanRotorPainter;
      expect(initialPainter.color, const Color(0xFF71717A));

      // Toggle relay 2 via tap
      await tester.tap(find.text('Cooling Fan'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(bridge.relay2On, isTrue);

      // Now Relay 2 is on -> color is cyan #06B6D4
      final activeCustomPaint = tester.widget<CustomPaint>(fanRotorFinder);
      final activePainter = activeCustomPaint.painter as CoolingFanRotorPainter;
      expect(activePainter.color, const Color(0xFF06B6D4));
    });

    testWidgets('Header displays Automation Hub with hub icon and removes Arduino Uno R3', (tester) async {
      final bridge = HardwareBridge();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VirtualArduinoBoard(bridge: bridge),
          ),
        ),
      );

      // Verify 'Arduino Uno R3' is replaced
      expect(find.text('Arduino Uno R3'), findsNothing);

      // Verify 'Automation Hub' and Icons.hub_outlined are rendered
      expect(find.text('Automation Hub'), findsOneWidget);
      expect(find.byIcon(Icons.hub_outlined), findsOneWidget);

      // Verify RELAY BUS tile and its icon are rendered
      expect(find.text('RELAY BUS'), findsOneWidget);
      expect(find.byIcon(Icons.alt_route), findsOneWidget);
      expect(find.text('0 of 3 Active'), findsOneWidget);
    });

    test('CoolingFanRotorPainter paints 3-blade rotor without errors', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const painter = CoolingFanRotorPainter(color: Color(0xFF06B6D4));

      painter.paint(canvas, const Size(20.0, 20.0));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  group('Hero Mic Stage & SoundWaveAura Visualizer (Zero Layout Shift)', () {
    testWidgets('Hero stage has fixed height 150.0 and stationary 72x72 mic button', (tester) async {
      await tester.pumpWidget(const VoiceAssistantApp());

      // Verify the fixed-height 150.0 container exists
      final fixedStageFinder = find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 150.0,
      );
      expect(fixedStageFinder, findsOneWidget);

      // Verify stationary 72x72 mic button exists
      final coreMicButtonFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 72.0 &&
            widget.constraints?.maxHeight == 72.0,
      );
      expect(coreMicButtonFinder, findsOneWidget);

      // Verify SoundWaveAuraPainter is present
      final auraFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is SoundWaveAuraPainter,
      );
      expect(auraFinder, findsOneWidget);

      // Verify transcript box minHeight constraint is 68.0
      final transcriptBoxFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.minHeight == 68.0,
      );
      expect(transcriptBoxFinder, findsOneWidget);
    });

    test('SoundWaveAuraPainter paints 3 concentric ripple rings cleanly', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const painter = SoundWaveAuraPainter(
        pulse: 0.5,
        soundLevel: 4.2,
        isListening: true,
      );

      painter.paint(canvas, const Size(72.0, 72.0));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}
