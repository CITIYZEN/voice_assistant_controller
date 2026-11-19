// Imports core Flutter framework for material design components.
import 'package:flutter/material.dart';
// Imports math library for sine wave calculations in the audio visualizer.
import 'dart:math' as math;
// Imports SpeechService for native speech recognition and streaming.
import 'services/speech_service.dart';
// Imports HardwareBridge for state synchronization and serial communication.
import 'services/hardware_bridge.dart';
// Imports VirtualArduinoBoard visual Bento dashboard widget.
import 'widgets/virtual_arduino_board.dart';
// Imports SerialMonitor collapsible terminal console widget.
import 'widgets/serial_monitor.dart';

// Application main entry point executed on startup.
void main() {
  // Ensures Flutter widget binding is initialized before calling native platform channels.
  WidgetsFlutterBinding.ensureInitialized();
  // Runs the root application widget.
  runApp(const VoiceAssistantApp());
}

// Root application widget setting up the editorial dark design system.
class VoiceAssistantApp extends StatelessWidget {
  // Constant constructor.
  const VoiceAssistantApp({super.key});

  // Builds the MaterialApp configured with a refined Zinc/Slate dark theme.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Application title.
      title: 'HVASSI Voice Controller',
      // Disables debug watermark banner in release preview.
      debugShowCheckedModeBanner: false,
      // Configures editorial high-contrast matte dark theme.
      theme: ThemeData(
        // Forces dark brightness across all components.
        brightness: Brightness.dark,
        // Matte Zinc-950 deep canvas background.
        scaffoldBackgroundColor: const Color(0xFF09090B),
        // Primary text accent.
        primaryColor: const Color(0xFFFAFAFA),
        // ColorScheme configuration based on the matte Zinc palette.
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFAFAFA),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF121215),
          background: Color(0xFF09090B),
        ),
        // Typography font family.
        fontFamily: 'Roboto',
      ),
      // Sets the initial home page widget.
      home: const VoiceAssistantHomeScreen(),
    );
  }
}

// Primary stateful screen hosting the voice assistant hero and hardware dashboard.
class VoiceAssistantHomeScreen extends StatefulWidget {
  // Constant constructor.
  const VoiceAssistantHomeScreen({super.key});

  // Creates state for the home screen.
  @override
  State<VoiceAssistantHomeScreen> createState() => _VoiceAssistantHomeScreenState();
}

// State class managing microphone lifecycle, waveform visualizer, and bridge dispatch.
class _VoiceAssistantHomeScreenState extends State<VoiceAssistantHomeScreen>
    with TickerProviderStateMixin {
  // Shared speech recognition service instance.
  final SpeechService _speechService = SpeechService();

  // Shared hardware bridge instance for Arduino simulation and serial logging.
  final HardwareBridge _hardwareBridge = HardwareBridge();

  // Animation controller driving the hero microphone orb breathing aura.
  late AnimationController _pulseController;

  // Animation controller driving the live audio waveform bars.
  late AnimationController _waveformController;

  // Live transcript string displayed in real-time as user speaks.
  String _liveTranscript = 'Tap microphone to speak...';

  // Last detected command token and phrase for UI feedback.
  String _lastDetectedCommand = '';

  // Measured detection latency in milliseconds (e.g. 95 ms).
  int _lastLatencyMs = 0;

  // Current audio level from microphone (0.0 to 10.0) for dynamic waveform height.
  double _soundLevel = 0.0;

  // Initializes controllers, listeners, and native speech callbacks.
  @override
  void initState() {
    // Calls superclass initState.
    super.initState();

    // Sets up pulsing microphone orb animation controller with 1600ms smooth breathing duration.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // Sets up waveform animation controller with 800ms loop for rhythmic bar fluctuation.
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Configures SpeechService callbacks for real-time reactivity.
    _setupSpeechCallbacks();

    // Pre-initializes speech recognition engine on startup.
    _speechService.initialize();
  }

  // Binds callbacks from SpeechService to update local state and dispatch hardware commands.
  void _setupSpeechCallbacks() {
    // Callback: Live partial transcript streaming as words are spoken.
    _speechService.onTranscriptUpdated = (transcript) {
      if (mounted) {
        setState(() {
          _liveTranscript = transcript;
        });
      }
    };

    // Callback: Instant command detection upon keyword match with measured latency.
    _speechService.onCommandDetected = (token, matchedPhrase, latencyMs) {
      if (mounted) {
        setState(() {
          _lastDetectedCommand = '$token ("$matchedPhrase")';
          _lastLatencyMs = latencyMs;
        });

        // Transmits token to HardwareBridge for Arduino execution & serial logging.
        _hardwareBridge.sendCommand(token);
      }
    };

    // Callback: Listening state transition (active or idle).
    _speechService.onStatusChanged = (isListening) {
      if (mounted) {
        setState(() {});
        // Starts or stops breathing aura animation based on listening state.
        if (isListening) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }
      }
    };

    // Callback: Microphone decibel audio volume changes for waveform visualizer.
    _speechService.onSoundLevelChanged = (level) {
      if (mounted) {
        setState(() {
          // Clamps sound level between 0.0 and 10.0 to prevent negative dB anomalies.
          _soundLevel = level.clamp(0.0, 10.0);
        });
      }
    };
  }

  // Disposes animation controllers and releases speech recognition engine.
  @override
  void dispose() {
    // Disposes pulse animation controller.
    _pulseController.dispose();
    // Disposes waveform animation controller.
    _waveformController.dispose();
    // Disposes speech service resources.
    _speechService.dispose();
    // Disposes hardware bridge listeners.
    _hardwareBridge.dispose();
    // Calls superclass dispose.
    super.dispose();
  }

  // Switches language locale between Egyptian Arabic and English.
  void _toggleLanguage() {
    final isCurrentlyArabic = _speechService.currentLocale.startsWith('ar');
    final newLocale = isCurrentlyArabic ? 'en-US' : 'ar-EG';
    _speechService.setLocale(newLocale);
    setState(() {
      _liveTranscript = !isCurrentlyArabic
          ? 'تم تفعيل اللغة العربية (اللهجة المصرية)...'
          : 'English voice recognition activated...';
    });
  }

  // Opens modal sheet allowing user to toggle Simulation Mode vs Hardware Mode.
  void _showModeSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121215),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Centered drag handle bar.
                  Center(
                    child: Container(
                      width: 36.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF27272A),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  // Header row.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hardware Bridge Mode',
                        style: TextStyle(
                          color: Color(0xFFFAFAFA),
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFFA1A1AA), size: 20.0),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF27272A), height: 1.0),
                  const SizedBox(height: 12.0),

                  // Mode selection radio tiles.
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      side: BorderSide(
                        color: _hardwareBridge.mode == BridgeMode.simulation
                            ? const Color(0xFF3F3F46)
                            : const Color(0xFF18181B),
                      ),
                    ),
                    tileColor: const Color(0xFF18181B),
                    title: const Text('Simulation Mode (Virtual Board)',
                        style: TextStyle(color: Color(0xFFFAFAFA), fontSize: 14.0, fontWeight: FontWeight.w500)),
                    subtitle: const Text('No physical hardware required, 100% interactive emulator',
                        style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12.0)),
                    leading: Radio<BridgeMode>(
                      value: BridgeMode.simulation,
                      groupValue: _hardwareBridge.mode,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (mode) {
                        if (mode != null) {
                          _hardwareBridge.setMode(mode);
                          setSheetState(() {});
                          setState(() {});
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      side: BorderSide(
                        color: _hardwareBridge.mode == BridgeMode.hardware
                            ? const Color(0xFF3F3F46)
                            : const Color(0xFF18181B),
                      ),
                    ),
                    tileColor: const Color(0xFF18181B),
                    title: const Text('Hardware Mode (Physical Arduino / ESP32)',
                        style: TextStyle(color: Color(0xFFFAFAFA), fontSize: 14.0, fontWeight: FontWeight.w500)),
                    subtitle: const Text('Sends real tokens via Wi-Fi HTTP or Bluetooth HC-05',
                        style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12.0)),
                    leading: Radio<BridgeMode>(
                      value: BridgeMode.hardware,
                      groupValue: _hardwareBridge.mode,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (mode) {
                        if (mode != null) {
                          _hardwareBridge.setMode(mode);
                          setSheetState(() {});
                          setState(() {});
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 16.0),

                  // Close button.
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF27272A),
                        foregroundColor: const Color(0xFFFAFAFA),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Builds the main screen widget tree.
  @override
  Widget build(BuildContext context) {
    final isArabic = _speechService.currentLocale.startsWith('ar');
    final isListening = _speechService.isListening;

    return Scaffold(
      // -------------------------------------------------------------
      // APP BAR: Title, Mode Indicator, Latency Badge, Language Toggle
      // -------------------------------------------------------------
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        titleSpacing: 16.0,
        title: Row(
          children: [
            // Crisp matte badge icon.
            Container(
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: const Icon(
                Icons.sensors,
                color: Color(0xFFFAFAFA),
                size: 18.0,
              ),
            ),
            const SizedBox(width: 10.0),
            // App Title.
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HVASSI',
                  style: TextStyle(
                    color: Color(0xFFFAFAFA),
                    fontSize: 15.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Voice Controller v1.0.1',
                  style: TextStyle(
                    color: Color(0xFFA1A1AA),
                    fontSize: 11.0,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Mode Indicator Chip (Simulation vs Hardware).
          InkWell(
            onTap: _showModeSettingsDialog,
            borderRadius: BorderRadius.circular(10.0),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12.0),
              padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: const Color(0xFF121215),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6.0,
                    height: 6.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hardwareBridge.mode == BridgeMode.simulation
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    _hardwareBridge.mode == BridgeMode.simulation ? 'SIM' : 'HW',
                    style: const TextStyle(
                      color: Color(0xFFFAFAFA),
                      fontSize: 11.0,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8.0),

          // Instant Language Switcher Button (AR / EN).
          InkWell(
            onTap: _toggleLanguage,
            borderRadius: BorderRadius.circular(10.0),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12.0),
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: const Color(0xFF121215),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.translate, color: Color(0xFFA1A1AA), size: 13.0),
                  const SizedBox(width: 5.0),
                  Text(
                    isArabic ? 'AR' : 'EN',
                    style: const TextStyle(
                      color: Color(0xFFFAFAFA),
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 14.0),
        ],
      ),

      // -------------------------------------------------------------
      // BODY: Scrollable view with Hero Mic, Bento Board & Collapsible Monitor
      // -------------------------------------------------------------
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Top Latency & Status Banner with NumberFlow-style animated badge.
            _buildLatencyBanner(),

            const SizedBox(height: 8.0),

            // Hero Voice Assistant Microphone & Live Transcript Box (The standout visual moment).
            _buildVoiceHeroSection(isListening, isArabic),

            const SizedBox(height: 10.0),

            // Master Controls Fast Action Bar (Turn All ON / OFF).
            _buildMasterControlsBar(),

            const SizedBox(height: 10.0),

            // Virtual Arduino Uno Bento Dashboard (Relays + RGB LED).
            VirtualArduinoBoard(bridge: _hardwareBridge),

            const SizedBox(height: 4.0),

            // Vaul-Style Collapsible 9600 Baud Serial Monitor Console.
            SerialMonitor(bridge: _hardwareBridge),

            const SizedBox(height: 28.0),
          ],
        ),
      ),
    );
  }

  // Builds the top real-time latency status banner with animated number roll.
  Widget _buildLatencyBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF121215),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // STT Engine Status.
          Row(
            children: [
              Container(
                width: 7.0,
                height: 7.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _speechService.isListening ? const Color(0xFF10B981) : const Color(0xFF71717A),
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                _speechService.isListening ? 'Streaming partial audio stream' : 'Speech engine ready',
                style: const TextStyle(
                  color: Color(0xFFA1A1AA),
                  fontSize: 12.0,
                ),
              ),
            ],
          ),

          // NumberFlow-style animated latency badge.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Color(0xFF10B981), size: 13.0),
                const SizedBox(width: 3.0),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.4),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Text(
                    _lastLatencyMs > 0 ? '$_lastLatencyMs ms' : 'Zero-Lag',
                    key: ValueKey<int>(_lastLatencyMs),
                    style: const TextStyle(
                      color: Color(0xFFFAFAFA),
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Builds the interactive voice assistant hero section with fixed-height stage and audio waveform visualizer.
  Widget _buildVoiceHeroSection(bool isListening, bool isArabic) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: const Color(0xFF121215),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        children: [
          // Dedicated fixed-height hero stage (150.0) with zero layout shift.
          SizedBox(
            height: 150.0,
            child: ClipRect(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                // Stationary 72x72 Circular Microphone Button with concentric sound wave ripple rings behind it.
                Center(
                  child: GestureDetector(
                    onTap: () => _speechService.toggleListening(),
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: SoundWaveAuraPainter(
                            pulse: _pulseController.value,
                            soundLevel: _soundLevel,
                            isListening: isListening,
                          ),
                          child: Container(
                            width: 72.0,
                            height: 72.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF18181B),
                              border: Border.all(
                                color: isListening ? const Color(0xFF10B981) : const Color(0xFF27272A),
                                width: 1.5,
                              ),
                              boxShadow: isListening
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withOpacity(0.25),
                                        blurRadius: 18.0,
                                        spreadRadius: 1.5,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Icon(
                                isListening ? Icons.mic : Icons.mic_none,
                                color: isListening ? const Color(0xFF10B981) : const Color(0xFFA1A1AA),
                                size: 30.0,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 10.0),

                // Multi-bar Audio Waveform Visualizer in fixed height container.
                SizedBox(
                  height: 16.0,
                  child: _buildAudioWaveform(isListening),
                ),

                const SizedBox(height: 8.0),

                // Listening status guidance text.
                Text(
                  isListening ? 'Listening in real-time...' : 'Tap to start voice control',
                  style: TextStyle(
                    color: isListening ? const Color(0xFF10B981) : const Color(0xFF71717A),
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

          const SizedBox(height: 12.0),

          // Streaming Transcript Display Card with clean minHeight: 68.0 to eliminate layout jump.
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 68.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF09090B),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with subtle language pill and live dot.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6.0,
                          height: 6.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isListening ? const Color(0xFF10B981) : const Color(0xFF71717A),
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        const Text(
                          'TRANSCRIPT',
                          style: TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 10.0,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      isArabic ? 'ar-EG' : 'en-US',
                      style: const TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),
                // Spoken Transcript Text with blinking cursor indication.
                Text(
                  _liveTranscript,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(
                    color: isListening ? const Color(0xFFFAFAFA) : const Color(0xFFA1A1AA),
                    fontSize: 13.5,
                    fontStyle: _liveTranscript.startsWith('Tap') ? FontStyle.italic : FontStyle.normal,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Last Detected Command Pill (Sonner Toast style).
          if (_lastDetectedCommand.isNotEmpty) ...[
            const SizedBox(height: 10.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14.0),
                  const SizedBox(width: 6.0),
                  Text(
                    _lastDetectedCommand,
                    style: const TextStyle(
                      color: Color(0xFFFAFAFA),
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Builds an interactive multi-bar audio waveform visualizer.
  Widget _buildAudioWaveform(bool isListening) {
    return AnimatedBuilder(
      animation: _waveformController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(7, (index) {
            // Calculates varied bar heights based on sine wave and current mic sound level.
            final wavePhase = (_waveformController.value * 2 * math.pi) + (index * 0.7);
            final waveOffset = (math.sin(wavePhase) + 1.0) / 2.0; // 0.0 to 1.0

            final height = isListening
                ? 3.5 + (waveOffset * 8.0) + ((_soundLevel / 10.0) * 4.5)
                : 3.5;

            return Container(
              width: 3.5,
              height: height.clamp(3.5, 16.0),
              margin: const EdgeInsets.symmetric(horizontal: 2.0),
              decoration: BoxDecoration(
                color: isListening ? const Color(0xFF10B981) : const Color(0xFF27272A),
                borderRadius: BorderRadius.circular(2.0),
              ),
            );
          }),
        );
      },
    );
  }

  // Builds fast action bar for Master Turn All ON and Turn All OFF.
  Widget _buildMasterControlsBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // Turn All ON Button.
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF121215),
                foregroundColor: const Color(0xFFFAFAFA),
                side: const BorderSide(color: Color(0xFF27272A)),
                padding: const EdgeInsets.symmetric(vertical: 11.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              icon: const Icon(Icons.power_settings_new, size: 16.0, color: Color(0xFF10B981)),
              label: const Text(
                'ALL ON',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
              onPressed: () => _hardwareBridge.sendCommand('ALL_ON'),
            ),
          ),
          const SizedBox(width: 10.0),
          // Turn All OFF Button (Goodnight).
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF121215),
                foregroundColor: const Color(0xFFFAFAFA),
                side: const BorderSide(color: Color(0xFF27272A)),
                padding: const EdgeInsets.symmetric(vertical: 11.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              icon: const Icon(Icons.nightlight_round, size: 16.0, color: Color(0xFFEF4444)),
              label: const Text(
                'ALL OFF',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
              onPressed: () => _hardwareBridge.sendCommand('ALL_OFF'),
            ),
          ),
        ],
      ),
    );
  }
}

// CustomPainter that renders 2-3 smooth concentric animated ripple rings behind the stationary mic button.
class SoundWaveAuraPainter extends CustomPainter {
  // Current animation progress of the breathing pulse controller (0.0 to 1.0).
  final double pulse;
  // Live input decibel level from speech service (0.0 to 10.0).
  final double soundLevel;
  // Whether speech recognition is actively streaming.
  final bool isListening;

  const SoundWaveAuraPainter({
    required this.pulse,
    required this.soundLevel,
    required this.isListening,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isListening) return;

    final center = Offset(size.width / 2, size.height / 2);
    const baseRadius = 36.0; // Half of 72x72 core button
    final normalizedSound = (soundLevel / 10.0).clamp(0.0, 1.0);

    // Soft ambient aura glow immediately behind button core
    final auraPaint = Paint()
      ..color = const Color(0xFF10B981).withOpacity((0.14 + (normalizedSound * 0.10) - (pulse * 0.04)).clamp(0.04, 0.24))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius + 4.0 + (pulse * 3.0), auraPaint);

    // 3 Concentric animated sound wave ripple rings expanding and fading smoothly based on pulse and sound level.
    final ringConfigs = [
      // Ring 1 (Inner ring)
      _RippleRing(
        radius: baseRadius + 4.0 + (pulse * 4.0) + (normalizedSound * 3.0),
        alpha: ((0.36 - (pulse * 0.14)) * (0.65 + normalizedSound * 0.35)).clamp(0.06, 0.42),
        strokeWidth: 1.5,
      ),
      // Ring 2 (Middle ring)
      _RippleRing(
        radius: baseRadius + 9.0 + (pulse * 6.0) + (normalizedSound * 4.0),
        alpha: ((0.22 - (pulse * 0.10)) * (0.65 + normalizedSound * 0.35)).clamp(0.04, 0.28),
        strokeWidth: 1.2,
      ),
      // Ring 3 (Outer ring)
      _RippleRing(
        radius: baseRadius + 14.0 + (pulse * 8.0) + (normalizedSound * 5.0),
        alpha: ((0.13 - (pulse * 0.06)) * (0.65 + normalizedSound * 0.35)).clamp(0.02, 0.16),
        strokeWidth: 1.0,
      ),
    ];

    // Renders clean concentric ripple stroke waves behind the button
    for (final ring in ringConfigs) {
      final strokePaint = Paint()
        ..color = const Color(0xFF10B981).withOpacity(ring.alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring.strokeWidth;
      canvas.drawCircle(center, ring.radius, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SoundWaveAuraPainter oldDelegate) {
    return oldDelegate.pulse != pulse ||
        oldDelegate.soundLevel != soundLevel ||
        oldDelegate.isListening != isListening;
  }
}

// Internal data model for ripple ring parameters.
class _RippleRing {
  final double radius;
  final double alpha;
  final double strokeWidth;

  const _RippleRing({
    required this.radius,
    required this.alpha,
    required this.strokeWidth,
  });
}
