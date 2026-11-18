// Imports core Flutter framework for UI rendering.
import 'package:flutter/material.dart';
// Imports SpeechService for native speech recognition and partial streaming.
import 'services/speech_service.dart';
// Imports HardwareBridge for state management and serial communication.
import 'services/hardware_bridge.dart';
// Imports VirtualArduinoBoard visual dashboard widget.
import 'widgets/virtual_arduino_board.dart';
// Imports SerialMonitor 9600 baud console widget.
import 'widgets/serial_monitor.dart';

// Application main entry point executed on startup.
void main() {
  // Ensures widget binding is initialized before accessing native platform channels.
  WidgetsFlutterBinding.ensureInitialized();
  // Runs root application widget.
  runApp(const VoiceAssistantApp());
}

// Root application widget setting up dark theme and home screen.
class VoiceAssistantApp extends StatelessWidget {
  // Constructor with key.
  const VoiceAssistantApp({super.key});

  // Builds MaterialApp configured with custom smart home dark theme.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Application title.
      title: 'HVASSI Voice Controller',
      // Disables debug banner in the top corner.
      debugShowCheckedModeBanner: false,
      // Configures futuristic dark theme.
      theme: ThemeData(
        // Forces dark brightness across all components.
        brightness: Brightness.dark,
        // Scaffold background color (deep midnight black/navy).
        scaffoldBackgroundColor: const Color(0xFF070B12),
        // Primary color accent (vibrant cyan).
        primaryColor: const Color(0xFF00E5FF),
        // ColorScheme configuration.
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF7C4DFF),
          surface: Color(0xFF111722),
          background: Color(0xFF070B12),
        ),
        // Typography font family.
        fontFamily: 'Roboto',
      ),
      // Sets the initial home page widget.
      home: const VoiceAssistantHomeScreen(),
    );
  }
}

// Primary stateful screen hosting the voice assistant controls and hardware dashboard.
class VoiceAssistantHomeScreen extends StatefulWidget {
  // Constructor.
  const VoiceAssistantHomeScreen({super.key});

  // Creates state.
  @override
  State<VoiceAssistantHomeScreen> createState() => _VoiceAssistantHomeScreenState();
}

// State class managing microphone lifecycle, transcript updates, and bridge communication.
class _VoiceAssistantHomeScreenState extends State<VoiceAssistantHomeScreen> with SingleTickerProviderStateMixin {
  // Shared speech recognition service instance.
  final SpeechService _speechService = SpeechService();

  // Shared hardware bridge instance for Arduino simulation and serial logging.
  final HardwareBridge _hardwareBridge = HardwareBridge();

  // Animation controller for pulsing microphone ripple effect.
  late AnimationController _pulseController;

  // Live transcript string displayed in real-time as user speaks.
  String _liveTranscript = 'Tap microphone and say a command...';

  // Last detected command token and phrase for UI feedback.
  String _lastDetectedCommand = '';

  // Measured detection latency in milliseconds (e.g. 140 ms).
  int _lastLatencyMs = 0;

  // Current audio level from microphone (0.0 to 10.0) for dynamic visual ripple scaling.
  double _soundLevel = 0.0;

  // Initializes controllers, listeners, and native speech callbacks.
  @override
  void initState() {
    // Calls superclass initState.
    super.initState();

    // Sets up pulsing microphone animation controller with 1200ms duration.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

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

        // Transmits token to HardwareBridge for Arduino execution & serial logging!
        _hardwareBridge.sendCommand(token);
      }
    };

    // Callback: Listening state transition (active or idle).
    _speechService.onStatusChanged = (isListening) {
      if (mounted) {
        setState(() {});
        // Starts or stops pulsing ripple animation based on listening state.
        if (isListening) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }
      }
    };

    // Callback: Microphone decibel audio volume changes for pulsing sensitivity.
    _speechService.onSoundLevelChanged = (level) {
      if (mounted) {
        setState(() {
          _soundLevel = level;
        });
      }
    };
  }

  // Disposes animation controller and releases speech recognition engine.
  @override
  void dispose() {
    // Disposes pulse animation controller.
    _pulseController.dispose();
    // Disposes speech service resources.
    _speechService.dispose();
    // Disposes hardware bridge listeners.
    _hardwareBridge.dispose();
    // Calls superclass dispose.
    super.dispose();
  }

  // Switches language locale between Egyptian Arabic and English.
  void _toggleLanguage() {
    final newLocale = _speechService.currentLocale == 'ar_EG' ? 'en_US' : 'ar_EG';
    _speechService.setLocale(newLocale);
    setState(() {
      _liveTranscript = newLocale == 'ar_EG'
          ? 'تم تفعيل اللغة العربية (اللهجة المصرية)...'
          : 'English voice recognition activated...';
    });
  }

  // Opens modal sheet allowing user to toggle Simulation Mode vs Hardware Mode.
  void _showModeSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111722),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
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
                  // Header row.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hardware Bridge Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF1E293B)),
                  const SizedBox(height: 12.0),

                  // Mode selection radio tiles.
                  ListTile(
                    title: const Text('Simulation Mode (Virtual Arduino)'),
                    subtitle: const Text('Zero physical hardware required, 100% interactive simulation'),
                    leading: Radio<BridgeMode>(
                      value: BridgeMode.simulation,
                      groupValue: _hardwareBridge.mode,
                      activeColor: const Color(0xFF00E5FF),
                      onChanged: (mode) {
                        if (mode != null) {
                          _hardwareBridge.setMode(mode);
                          setSheetState(() {});
                          setState(() {});
                        }
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Hardware Mode (Physical Arduino / ESP32)'),
                    subtitle: const Text('Transmits real tokens via Wi-Fi HTTP or Bluetooth HC-05'),
                    leading: Radio<BridgeMode>(
                      value: BridgeMode.hardware,
                      groupValue: _hardwareBridge.mode,
                      activeColor: const Color(0xFF00E5FF),
                      onChanged: (mode) {
                        if (mode != null) {
                          _hardwareBridge.setMode(mode);
                          setSheetState(() {});
                          setState(() {});
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 12.0),

                  // Close button.
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // Resolves color for latency badge based on speed benchmarks.
  Color _resolveLatencyColor(int ms) {
    if (ms <= 0) return const Color(0xFF94A3B8);
    // Ultra-fast (< 200 ms): Electric Green
    if (ms < 200) return const Color(0xFF00E676);
    // Fast (< 350 ms): Bright Cyan
    if (ms < 350) return const Color(0xFF00E5FF);
    // Medium (< 600 ms): Amber
    if (ms < 600) return const Color(0xFFFFB703);
    // Slower: Red
    return const Color(0xFFFF5252);
  }

  // Builds the main screen widget tree.
  @override
  Widget build(BuildContext context) {
    final isArabic = _speechService.currentLocale == 'ar_EG';
    final isListening = _speechService.isListening;

    return Scaffold(
      // -------------------------------------------------------------
      // APP BAR: Title, Mode Indicator, Latency Badge, Language Toggle
      // -------------------------------------------------------------
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B101B),
        elevation: 0,
        titleSpacing: 16.0,
        title: Row(
          children: [
            // Voice Wave Icon.
            Container(
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Icon(
                Icons.graphic_eq,
                color: Color(0xFF00E5FF),
                size: 20.0,
              ),
            ),
            const SizedBox(width: 10.0),
            // App Title.
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HVASSI Voice Controller',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Zero-Latency STT Assistant',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11.0,
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
            borderRadius: BorderRadius.circular(16.0),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12.0),
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: _hardwareBridge.mode == BridgeMode.simulation
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF059669).withOpacity(0.2),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: _hardwareBridge.mode == BridgeMode.simulation
                      ? const Color(0xFF334155)
                      : const Color(0xFF10B981),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _hardwareBridge.mode == BridgeMode.simulation ? Icons.memory : Icons.wifi,
                    size: 13.0,
                    color: _hardwareBridge.mode == BridgeMode.simulation
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    _hardwareBridge.mode == BridgeMode.simulation ? 'SIM' : 'HW',
                    style: TextStyle(
                      color: _hardwareBridge.mode == BridgeMode.simulation
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF10B981),
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
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
            borderRadius: BorderRadius.circular(16.0),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12.0),
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.language, color: Color(0xFF38BDF8), size: 14.0),
                  const SizedBox(width: 4.0),
                  Text(
                    isArabic ? '🇪🇬 AR' : '🇺🇸 EN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
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
      // BODY: Scrollable view with Hero Mic, Dashboard & Serial Monitor
      // -------------------------------------------------------------
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Top Latency & Status Banner.
            _buildLatencyBanner(),

            const SizedBox(height: 12.0),

            // Hero Voice Assistant Microphone & Live Transcript Box.
            _buildVoiceHeroSection(isListening, isArabic),

            const SizedBox(height: 10.0),

            // Master Controls Fast Action Bar (Turn All ON / OFF).
            _buildMasterControlsBar(),

            const SizedBox(height: 8.0),

            // Virtual Arduino Uno Dashboard (Relays + RGB LED).
            VirtualArduinoBoard(bridge: _hardwareBridge),

            // Live 9600 Baud Serial Monitor Console.
            SerialMonitor(bridge: _hardwareBridge),

            const SizedBox(height: 24.0),
          ],
        ),
      ),
    );
  }

  // Builds the top real-time latency status banner.
  Widget _buildLatencyBanner() {
    final latencyColor = _resolveLatencyColor(_lastLatencyMs);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // STT Engine Status.
          Row(
            children: [
              Container(
                width: 8.0,
                height: 8.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _speechService.isListening ? const Color(0xFF00E676) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                _speechService.isListening ? 'Streaming Partial Audio...' : 'Voice Engine Ready',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12.0,
                ),
              ),
            ],
          ),

          // Latency Measurement Badge.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
            decoration: BoxDecoration(
              color: latencyColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: latencyColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt, color: latencyColor, size: 14.0),
                const SizedBox(width: 2.0),
                Text(
                  _lastLatencyMs > 0 ? '$_lastLatencyMs ms' : 'Zero-Latency',
                  style: TextStyle(
                    color: latencyColor,
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Builds the interactive voice assistant hero section with pulsing mic and live transcript.
  Widget _buildVoiceHeroSection(bool isListening, bool isArabic) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1527), Color(0xFF0A0E18)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(22.0),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(isListening ? 0.12 : 0.04),
            blurRadius: 20.0,
            spreadRadius: 2.0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Pulsing Microphone Button.
          Center(
            child: GestureDetector(
              onTap: () => _speechService.toggleListening(),
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  // Calculates dynamic ripple scale based on animation value and audio volume level.
                  final scale = isListening ? 1.0 + (_pulseController.value * 0.15) + (_soundLevel * 0.02) : 1.0;

                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 76.0,
                      height: 76.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isListening
                              ? [const Color(0xFF00E5FF), const Color(0xFF7C4DFF)]
                              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: isListening
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withOpacity(0.55),
                                  blurRadius: 22.0,
                                  spreadRadius: 4.0,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 8.0,
                                ),
                              ],
                        border: Border.all(
                          color: isListening ? Colors.white : const Color(0xFF334155),
                          width: 2.0,
                        ),
                      ),
                      child: Icon(
                        isListening ? Icons.mic : Icons.mic_none,
                        color: isListening ? Colors.black : const Color(0xFF94A3B8),
                        size: 34.0,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12.0),

          // Listening status guidance text.
          Text(
            isListening ? 'Listening in real-time...' : 'Tap to start voice control',
            style: TextStyle(
              color: isListening ? const Color(0xFF00E5FF) : const Color(0xFF64748B),
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 14.0),

          // Live Transcript Display Box.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF060911),
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Transcript box label row.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'LIVE TRANSCRIPT',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      isArabic ? 'Egyptian Arabic (ar_EG)' : 'English (en_US)',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 10.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),
                // Spoken Transcript Text.
                Text(
                  _liveTranscript,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(
                    color: isListening ? Colors.white : const Color(0xFF94A3B8),
                    fontSize: 14.5,
                    fontStyle: _liveTranscript.startsWith('Tap') ? FontStyle.italic : FontStyle.normal,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Last Detected Command Badge (if available).
          if (_lastDetectedCommand.isNotEmpty) ...[
            const SizedBox(height: 10.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 15.0),
                  const SizedBox(width: 6.0),
                  Text(
                    'Triggered: $_lastDetectedCommand',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
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

  // Builds fast action bar for Master Turn All ON and Turn All OFF.
  Widget _buildMasterControlsBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // Turn All ON Button.
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2B1D),
                foregroundColor: const Color(0xFF00E676),
                side: const BorderSide(color: Color(0xFF059669)),
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              icon: const Icon(Icons.power_settings_new, size: 17.0),
              label: const Text(
                'ALL ON (شغل الكل)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _hardwareBridge.sendCommand('ALL_ON'),
            ),
          ),
          const SizedBox(width: 10.0),
          // Turn All OFF Button (Goodnight).
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B1015),
                foregroundColor: const Color(0xFFFF5252),
                side: const BorderSide(color: Color(0xFFDC2626)),
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              icon: const Icon(Icons.nightlight_round, size: 17.0),
              label: const Text(
                'ALL OFF (اطفي الكل)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _hardwareBridge.sendCommand('ALL_OFF'),
            ),
          ),
        ],
      ),
    );
  }
}
