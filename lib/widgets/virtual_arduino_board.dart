// Imports math utilities for rotation angle calculations.
import 'dart:math' as math;
// Imports core Flutter material design widgets and theming components.
import 'package:flutter/material.dart';
// Imports HardwareBridge models and state definitions.
import '../services/hardware_bridge.dart';

// VirtualArduinoBoard renders an interactive visual simulation of an Arduino Uno and connected peripherals.
class VirtualArduinoBoard extends StatefulWidget {
  // Reference to the shared hardware bridge instance.
  final HardwareBridge bridge;

  // Constructor receiving the required hardware bridge instance.
  const VirtualArduinoBoard({
    // Passes key to superclass.
    super.key,
    // Assigns bridge instance.
    required this.bridge,
  });

  // Creates mutable state for the virtual board widget.
  @override
  State<VirtualArduinoBoard> createState() => _VirtualArduinoBoardState();
}

// State class managing animations and board interactions.
class _VirtualArduinoBoardState extends State<VirtualArduinoBoard> with TickerProviderStateMixin {
  // Animation controller driving the continuous spinning motion of the cooling fan icon when Relay 2 is ON.
  late AnimationController _fanController;

  // Animation controller driving the rainbow color cycle for the RGB LED party mode.
  late AnimationController _rgbCycleController;

  // Animation producing hue rotation from 0.0 to 360.0 degrees.
  late Animation<double> _rainbowHueAnimation;

  // Initializes controllers and registers state listeners on widget creation.
  @override
  void initState() {
    // Calls base class initState.
    super.initState();

    // Sets up fan rotation animation controller with 1-second continuous rotation loop.
    _fanController = AnimationController(
      // Binds ticker provider.
      vsync: this,
      // Sets revolution duration.
      duration: const Duration(milliseconds: 1000),
    );

    // Sets up RGB cycle animation controller with 3-second continuous rainbow loop.
    _rgbCycleController = AnimationController(
      // Binds ticker provider.
      vsync: this,
      // Sets full spectrum cycle duration.
      duration: const Duration(milliseconds: 3000),
    );

    // Creates continuous hue tween from 0 to 360 degrees.
    _rainbowHueAnimation = Tween<double>(begin: 0.0, end: 360.0).animate(_rgbCycleController);

    // Syncs animation controllers with the initial hardware bridge state.
    _updateAnimationStates();

    // Listens to hardware bridge state changes (voice commands or manual clicks).
    widget.bridge.addListener(_onBridgeChanged);
  }

  // Listener called whenever hardware bridge state transitions occur.
  void _onBridgeChanged() {
    // Re-evaluates animation playing states.
    _updateAnimationStates();
    // Triggers rebuild to update visual relay and LED indicators.
    if (mounted) {
      setState(() {});
    }
  }

  // Manages playing/stopping of fan and RGB animations based on bridge state.
  void _updateAnimationStates() {
    // Controls fan spinning animation based on Relay 2 state.
    if (widget.bridge.relay2On) {
      // Starts repeating rotation if fan is ON.
      if (!_fanController.isAnimating) {
        _fanController.repeat();
      }
    } else {
      // Stops fan rotation when fan is OFF.
      if (_fanController.isAnimating) {
        _fanController.stop();
      }
    }

    // Controls RGB rainbow animation based on RGB mode.
    if (widget.bridge.rgbMode == RgbMode.cycle) {
      // Starts rainbow cycle if party mode is active.
      if (!_rgbCycleController.isAnimating) {
        _rgbCycleController.repeat();
      }
    } else {
      // Stops rainbow cycle when solid color or OFF is active.
      if (_rgbCycleController.isAnimating) {
        _rgbCycleController.stop();
      }
    }
  }

  // Disposes animation controllers and detaches listeners cleanly.
  @override
  void dispose() {
    // Removes bridge change listener.
    widget.bridge.removeListener(_onBridgeChanged);
    // Disposes fan controller.
    _fanController.dispose();
    // Disposes RGB cycle controller.
    _rgbCycleController.dispose();
    // Calls super dispose.
    super.dispose();
  }

  // Resolves the current display color for the virtual RGB LED.
  Color _resolveRgbColor() {
    // Checks active RGB mode.
    switch (widget.bridge.rgbMode) {
      // Extinguished LED.
      case RgbMode.off:
        return const Color(0xFF1E232A);
      // Solid Red.
      case RgbMode.red:
        return const Color(0xFFFF1744);
      // Solid Green.
      case RgbMode.green:
        return const Color(0xFF00E676);
      // Solid Blue.
      case RgbMode.blue:
        return const Color(0xFF2979FF);
      // Solid White.
      case RgbMode.white:
        return const Color(0xFFFFFFFF);
      // Dynamic rainbow cycle in party mode.
      case RgbMode.cycle:
        return HSLColor.fromAHSL(1.0, _rainbowHueAnimation.value, 1.0, 0.55).toColor();
    }
  }

  // Builds the virtual Arduino board widget tree.
  @override
  Widget build(BuildContext context) {
    // Wraps entire board in styled container card.
    return Container(
      // Margin around board card.
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      // Padding inside card.
      padding: const EdgeInsets.all(16.0),
      // Container decoration with dark glassmorphism aesthetic.
      decoration: BoxDecoration(
        // Dark slate background resembling microcontroller PCB.
        color: const Color(0xFF111722),
        // Rounded corners.
        borderRadius: BorderRadius.circular(20.0),
        // Subtle border giving a high-tech hardware look.
        border: Border.all(
          color: const Color(0xFF1E293B),
          width: 1.5,
        ),
        // Soft drop shadow.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16.0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // Column holding header, board status, relay cards, and RGB module.
      child: Column(
        // Aligns children to start horizontally.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -----------------------------------------------------------
          // BOARD HEADER: Title, Microcontroller Model & Activity LEDs
          // -----------------------------------------------------------
          Row(
            // Distributes space evenly.
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Board name & architecture badge.
              Row(
                children: [
                  // Microchip icon.
                  const Icon(
                    Icons.developer_board,
                    color: Color(0xFF38BDF8),
                    size: 22.0,
                  ),
                  const SizedBox(width: 8.0),
                  // Title text.
                  const Text(
                    'Virtual Arduino Uno R3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  // Baud rate badge.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Text(
                      '9600 BAUD',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10.0,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // Activity LEDs (PWR, TX, RX).
              Row(
                children: [
                  // Power indicator LED (Always green when active).
                  _buildStatusLed('PWR', Colors.greenAccent, isLit: true),
                  const SizedBox(width: 8.0),
                  // TX indicator LED (Blinks orange on transmission).
                  _buildStatusLed('TX', Colors.orangeAccent, isLit: widget.bridge.txBlinking),
                  const SizedBox(width: 8.0),
                  // RX indicator LED (Blinks yellow on reception).
                  _buildStatusLed('RX', Colors.amberAccent, isLit: widget.bridge.rxBlinking),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16.0),
          const Divider(color: Color(0xFF1E293B), height: 1.0),
          const SizedBox(height: 16.0),

          // Section Title: Relay Appliances
          const Row(
            children: [
              Icon(Icons.power, color: Color(0xFF94A3B8), size: 16.0),
              SizedBox(width: 6.0),
              Text(
                '3-CHANNEL 5V RELAY MODULE',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12.0),

          // -----------------------------------------------------------
          // 3 INTERACTIVE RELAY CARDS (Light D7, Fan D8, Plug/TV D9)
          // -----------------------------------------------------------
          // Relay 1 Card: Living Room Light (Pin D7)
          _buildRelayCard(
            title: 'Living Room Light',
            pinLabel: 'Pin D7',
            isOn: widget.bridge.relay1On,
            accentColor: const Color(0xFFFFB703),
            icon: Icons.lightbulb,
            onToggle: () => widget.bridge.toggleRelay(1),
            voiceHint: '"turn on the light" / "شغل النور"',
          ),

          const SizedBox(height: 10.0),

          // Relay 2 Card: Cooling Fan (Pin D8) with rotation animation
          _buildRelayCard(
            title: 'Cooling Fan',
            pinLabel: 'Pin D8',
            isOn: widget.bridge.relay2On,
            accentColor: const Color(0xFF00F5D4),
            icon: Icons.mode_fan_off,
            customIconWidget: RotationTransition(
              turns: _fanController,
              child: Icon(
                Icons.toys,
                color: widget.bridge.relay2On ? const Color(0xFF00F5D4) : const Color(0xFF64748B),
                size: 26.0,
              ),
            ),
            onToggle: () => widget.bridge.toggleRelay(2),
            voiceHint: '"turn on the fan" / "شغل المروحة"',
          ),

          const SizedBox(height: 10.0),

          // Relay 3 Card: Smart Plug / TV (Pin D9)
          _buildRelayCard(
            title: 'Smart Plug / TV',
            pinLabel: 'Pin D9',
            isOn: widget.bridge.relay3On,
            accentColor: const Color(0xFFB5179E),
            icon: Icons.tv,
            onToggle: () => widget.bridge.toggleRelay(3),
            voiceHint: '"turn on the tv" / "شغل الفيشة"',
          ),

          const SizedBox(height: 20.0),
          const Divider(color: Color(0xFF1E293B), height: 1.0),
          const SizedBox(height: 16.0),

          // -----------------------------------------------------------
          // VIRTUAL RGB LED MODULE (Pins D3, D5, D6 PWM)
          // -----------------------------------------------------------
          const Row(
            children: [
              Icon(Icons.palette, color: Color(0xFF94A3B8), size: 16.0),
              SizedBox(width: 6.0),
              Text(
                'PWM RGB MOOD LIGHTING (PINS D3/D5/D6)',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14.0),

          // RGB Module Container Card
          Container(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0F18),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              children: [
                // Top row with virtual glowing LED diffuser and active status.
                Row(
                  children: [
                    // Animated builder updating color continuously during party mode cycle.
                    AnimatedBuilder(
                      animation: _rgbCycleController,
                      builder: (context, child) {
                        final rgbColor = _resolveRgbColor();
                        final isRgbActive = widget.bridge.rgbMode != RgbMode.off;

                        return Container(
                          width: 58.0,
                          height: 58.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: rgbColor,
                            // Dynamic multi-layered glow shadow.
                            boxShadow: isRgbActive
                                ? [
                                    BoxShadow(
                                      color: rgbColor.withOpacity(0.65),
                                      blurRadius: 24.0,
                                      spreadRadius: 4.0,
                                    ),
                                    BoxShadow(
                                      color: rgbColor.withOpacity(0.3),
                                      blurRadius: 48.0,
                                      spreadRadius: 10.0,
                                    ),
                                  ]
                                : [],
                            border: Border.all(
                              color: isRgbActive ? Colors.white.withOpacity(0.8) : const Color(0xFF334155),
                              width: 2.0,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.flare,
                              color: isRgbActive ? Colors.white.withOpacity(0.9) : const Color(0xFF475569),
                              size: 24.0,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 16.0),

                    // RGB Mode description and voice command tip.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status title.
                          Text(
                            _getRgbModeTitle(widget.bridge.rgbMode),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          // Voice suggestion text.
                          Text(
                            _getRgbModeHint(widget.bridge.rgbMode),
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14.0),

                // Manual Tap-to-Test Quick Color Selector Chips
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    _buildRgbChip('Red', const Color(0xFFFF1744), RgbMode.red),
                    _buildRgbChip('Green', const Color(0xFF00E676), RgbMode.green),
                    _buildRgbChip('Blue', const Color(0xFF2979FF), RgbMode.blue),
                    _buildRgbChip('White', Colors.white, RgbMode.white),
                    _buildRgbChip('Party Mode', const Color(0xFFFF007F), RgbMode.cycle, isParty: true),
                    _buildRgbChip('OFF', const Color(0xFF64748B), RgbMode.off),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Returns human-friendly title for the active RGB mode.
  String _getRgbModeTitle(RgbMode mode) {
    switch (mode) {
      case RgbMode.off:
        return 'RGB LED: Extinguished (OFF)';
      case RgbMode.red:
        return 'RGB LED: Solid Red Mood';
      case RgbMode.green:
        return 'RGB LED: Solid Green Mood';
      case RgbMode.blue:
        return 'RGB LED: Solid Blue Mood';
      case RgbMode.white:
        return 'RGB LED: Ambient White';
      case RgbMode.cycle:
        return 'RGB LED: 🎉 Party Mode (Dynamic)';
    }
  }

  // Returns voice command suggestion corresponding to current RGB mode.
  String _getRgbModeHint(RgbMode mode) {
    switch (mode) {
      case RgbMode.off:
        return 'Say "red light" or "وضع الحفلة" to ignite';
      case RgbMode.red:
        return 'Active token: RGB_RED ("نور أحمر")';
      case RgbMode.green:
        return 'Active token: RGB_GREEN ("نور أخضر")';
      case RgbMode.blue:
        return 'Active token: RGB_BLUE ("نور أزرق")';
      case RgbMode.white:
        return 'Active token: RGB_WHITE ("نور أبيض")';
      case RgbMode.cycle:
        return 'Active token: RGB_CYCLE ("ألوان متغيرة")';
    }
  }

  // Builds an interactive Relay card with glowing indicators and manual switch.
  Widget _buildRelayCard({
    required String title,
    required String pinLabel,
    required bool isOn,
    required Color accentColor,
    required IconData icon,
    Widget? customIconWidget,
    required VoidCallback onToggle,
    required String voiceHint,
  }) {
    // Wraps card in gesture detector for intuitive tap-to-toggle.
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(14.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isOn ? accentColor.withOpacity(0.08) : const Color(0xFF0A0F18),
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(
            color: isOn ? accentColor.withOpacity(0.6) : const Color(0xFF1E293B),
            width: isOn ? 1.5 : 1.0,
          ),
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.18),
                    blurRadius: 14.0,
                    spreadRadius: 1.0,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Icon container with glow effect when relay is energized.
            Container(
              width: 44.0,
              height: 44.0,
              decoration: BoxDecoration(
                color: isOn ? accentColor.withOpacity(0.2) : const Color(0xFF1E293B),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: customIconWidget ??
                    Icon(
                      icon,
                      color: isOn ? accentColor : const Color(0xFF64748B),
                      size: 22.0,
                    ),
              ),
            ),

            const SizedBox(width: 12.0),

            // Device details column.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Pin Badge row.
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isOn ? Colors.white : const Color(0xFFCBD5E1),
                          fontSize: 14.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          pinLabel,
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 10.0,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3.0),
                  // Voice command hint.
                  Text(
                    voiceHint,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11.0,
                    ),
                  ),
                ],
              ),
            ),

            // Interactive state toggle switch.
            Switch(
              value: isOn,
              onChanged: (_) => onToggle(),
              activeColor: accentColor,
              activeTrackColor: accentColor.withOpacity(0.4),
              inactiveThumbColor: const Color(0xFF64748B),
              inactiveTrackColor: const Color(0xFF1E293B),
            ),
          ],
        ),
      ),
    );
  }

  // Builds an activity indicator LED with label (PWR, TX, RX).
  Widget _buildStatusLed(String label, Color color, {required bool isLit}) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: 9.0,
          height: 9.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLit ? color : const Color(0xFF1E293B),
            boxShadow: isLit
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.8),
                      blurRadius: 8.0,
                      spreadRadius: 2.0,
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 3.0),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 8.5,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Builds an interactive tap chip for quick RGB color testing.
  Widget _buildRgbChip(String label, Color color, RgbMode mode, {bool isParty = false}) {
    final isSelected = widget.bridge.rgbMode == mode;

    return InkWell(
      onTap: () => widget.bridge.setRgb(mode),
      borderRadius: BorderRadius.circular(20.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF334155),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8.0,
              height: 8.0,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6.0),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 11.0,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
