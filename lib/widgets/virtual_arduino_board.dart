// Imports core Flutter material design widgets and theming components.
import 'package:flutter/material.dart';
// Imports math utilities for rotor blade geometric calculations.
import 'dart:math' as math;
// Imports HardwareBridge models and state definitions.
import '../services/hardware_bridge.dart';

// VirtualArduinoBoard renders an interactive visual Bento simulation of an Arduino Uno and connected peripherals.
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
  // Animation controller driving the spinning motion of the cooling fan icon when Relay 2 is ON.
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
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Sets up RGB cycle animation controller with 3-second continuous rainbow loop.
    _rgbCycleController = AnimationController(
      vsync: this,
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

  // Re-evaluates animation playing states and re-attaches listener if bridge reference updates.
  @override
  void didUpdateWidget(covariant VirtualArduinoBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bridge != widget.bridge) {
      oldWidget.bridge.removeListener(_onBridgeChanged);
      widget.bridge.addListener(_onBridgeChanged);
      _updateAnimationStates();
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
    switch (widget.bridge.rgbMode) {
      case RgbMode.off:
        return const Color(0xFF27272A);
      case RgbMode.red:
        return const Color(0xFFEF4444);
      case RgbMode.green:
        return const Color(0xFF10B981);
      case RgbMode.blue:
        return const Color(0xFF3B82F6);
      case RgbMode.white:
        return const Color(0xFFFAFAFA);
      case RgbMode.cycle:
        return HSLColor.fromAHSL(1.0, _rainbowHueAnimation.value, 1.0, 0.55).toColor();
    }
  }

  // Builds the virtual Arduino board widget tree in a modern Bento Grid.
  @override
  Widget build(BuildContext context) {
    // Calculates count of active relays for status summary.
    final activeRelayCount = (widget.bridge.relay1On ? 1 : 0) +
        (widget.bridge.relay2On ? 1 : 0) +
        (widget.bridge.relay3On ? 1 : 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF121215),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -----------------------------------------------------------
          // BOARD HEADER: Title, Microcontroller Model & Activity LEDs
          // -----------------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Board name & architecture badge wrapped in Expanded to prevent overflow.
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.developer_board,
                      color: Color(0xFFA1A1AA),
                      size: 18.0,
                    ),
                    const SizedBox(width: 8.0),
                    const Flexible(
                      child: Text(
                        'Arduino Uno R3',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFFAFAFA),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181B),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: const Color(0xFF27272A)),
                      ),
                      child: const Text(
                        '9600 BAUD',
                        style: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8.0),

              // Activity LEDs (PWR, TX, RX).
              Row(
                children: [
                  _buildStatusLed('PWR', const Color(0xFF10B981), isLit: true),
                  const SizedBox(width: 8.0),
                  _buildStatusLed('TX', const Color(0xFFF59E0B), isLit: widget.bridge.txBlinking),
                  const SizedBox(width: 8.0),
                  _buildStatusLed('RX', const Color(0xFF06B6D4), isLit: widget.bridge.rxBlinking),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14.0),
          const Divider(color: Color(0xFF27272A), height: 1.0),
          const SizedBox(height: 14.0),

          // -----------------------------------------------------------
          // 2-COLUMN HARDWARE BENTO GRID (Relays 1, 2, 3 & Summary)
          // -----------------------------------------------------------
          Row(
            children: [
              // Column 1: Relay 1 (Light D7)
              Expanded(
                child: _buildBentoRelayTile(
                  title: 'Living Light',
                  pinLabel: 'D7',
                  isOn: widget.bridge.relay1On,
                  accentColor: const Color(0xFFF59E0B),
                  icon: Icons.lightbulb,
                  onToggle: () => widget.bridge.toggleRelay(1),
                  hint: '"turn on light"',
                ),
              ),
              const SizedBox(width: 10.0),
              // Column 2: Relay 2 (Fan D8)
              Expanded(
                child: _buildBentoRelayTile(
                  title: 'Cooling Fan',
                  pinLabel: 'D8',
                  isOn: widget.bridge.relay2On,
                  accentColor: const Color(0xFF06B6D4),
                  icon: Icons.wind_power,
                  customIcon: RotationTransition(
                    turns: _fanController,
                    child: SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CustomPaint(
                        painter: CoolingFanRotorPainter(
                          color: widget.bridge.relay2On ? const Color(0xFF06B6D4) : const Color(0xFF71717A),
                        ),
                      ),
                    ),
                  ),
                  onToggle: () => widget.bridge.toggleRelay(2),
                  hint: '"turn on fan"',
                ),
              ),
            ],
          ),

          const SizedBox(height: 10.0),

          Row(
            children: [
              // Column 1: Relay 3 (TV / Plug D9)
              Expanded(
                child: _buildBentoRelayTile(
                  title: 'Smart TV',
                  pinLabel: 'D9',
                  isOn: widget.bridge.relay3On,
                  accentColor: const Color(0xFFA855F7),
                  icon: Icons.tv,
                  onToggle: () => widget.bridge.toggleRelay(3),
                  hint: '"turn on tv"',
                ),
              ),
              const SizedBox(width: 10.0),
              // Column 2: Master Relay Status Summary Tile
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF09090B),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'RELAY BUS',
                            style: TextStyle(
                              color: Color(0xFF71717A),
                              fontSize: 9.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF18181B),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: const Text(
                              '5V VCC',
                              style: TextStyle(
                                color: Color(0xFFA1A1AA),
                                fontSize: 9.0,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0),
                      Text(
                        '$activeRelayCount of 3 Active',
                        style: const TextStyle(
                          color: Color(0xFFFAFAFA),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        activeRelayCount == 3
                            ? 'All channels closed'
                            : activeRelayCount == 0
                                ? 'All channels open'
                                : 'Mixed state',
                        style: const TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14.0),
          const Divider(color: Color(0xFF27272A), height: 1.0),
          const SizedBox(height: 14.0),

          // -----------------------------------------------------------
          // BENTO ROW: PWM RGB MOOD LIGHTING (PINS D3/D5/D6)
          // -----------------------------------------------------------
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF09090B),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with virtual glowing LED diffuser and active status.
                Row(
                  children: [
                    // RGB LED Lens Indicator.
                    AnimatedBuilder(
                      animation: _rgbCycleController,
                      builder: (context, child) {
                        final rgbColor = _resolveRgbColor();
                        final isRgbActive = widget.bridge.rgbMode != RgbMode.off;

                        return Container(
                          width: 32.0,
                          height: 32.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: rgbColor,
                            border: Border.all(
                              color: isRgbActive ? Colors.white.withOpacity(0.5) : const Color(0xFF27272A),
                              width: 1.5,
                            ),
                            boxShadow: isRgbActive
                                ? [
                                    BoxShadow(
                                      color: rgbColor.withOpacity(0.35),
                                      blurRadius: 10.0,
                                      spreadRadius: 1.0,
                                    ),
                                  ]
                                : [],
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 12.0),

                    // Title & PWM Pin badge.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'RGB Mood Light',
                                style: TextStyle(
                                  color: Color(0xFFFAFAFA),
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6.0),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF18181B),
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: const Text(
                                  'D3, D5, D6',
                                  style: TextStyle(
                                    color: Color(0xFFA1A1AA),
                                    fontSize: 9.5,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            _getRgbModeTitle(widget.bridge.rgbMode),
                            style: const TextStyle(
                              color: Color(0xFFA1A1AA),
                              fontSize: 11.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12.0),

                // Manual Tap-to-Test Quick Color Selector Chips
                Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: [
                    _buildRgbPill('Red', const Color(0xFFEF4444), RgbMode.red),
                    _buildRgbPill('Green', const Color(0xFF10B981), RgbMode.green),
                    _buildRgbPill('Blue', const Color(0xFF3B82F6), RgbMode.blue),
                    _buildRgbPill('White', const Color(0xFFFAFAFA), RgbMode.white),
                    _buildRgbPill('Party', const Color(0xFFEC4899), RgbMode.cycle),
                    _buildRgbPill('Off', const Color(0xFF71717A), RgbMode.off),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Returns concise title for active RGB mode.
  String _getRgbModeTitle(RgbMode mode) {
    switch (mode) {
      case RgbMode.off:
        return 'Extinguished (OFF)';
      case RgbMode.red:
        return 'Solid Red Mood';
      case RgbMode.green:
        return 'Solid Green Mood';
      case RgbMode.blue:
        return 'Solid Blue Mood';
      case RgbMode.white:
        return 'Ambient White';
      case RgbMode.cycle:
        return 'Party Mode Cycle';
    }
  }

  // Builds an interactive Bento Relay card.
  Widget _buildBentoRelayTile({
    required String title,
    required String pinLabel,
    required bool isOn,
    required Color accentColor,
    required IconData icon,
    Widget? customIcon,
    required VoidCallback onToggle,
    required String hint,
  }) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isOn ? accentColor.withOpacity(0.08) : const Color(0xFF09090B),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isOn ? accentColor.withOpacity(0.5) : const Color(0xFF27272A),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Pin label and Active status indicator dot.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    pinLabel,
                    style: const TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 9.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  width: 7.0,
                  height: 7.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOn ? accentColor : const Color(0xFF27272A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            // Icon.
            customIcon ??
                Icon(
                  icon,
                  size: 20.0,
                  color: isOn ? accentColor : const Color(0xFF71717A),
                ),
            const SizedBox(height: 8.0),
            // Title.
            Text(
              title,
              style: TextStyle(
                color: isOn ? const Color(0xFFFAFAFA) : const Color(0xFFA1A1AA),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2.0),
            // Hint.
            Text(
              isOn ? 'ON' : 'OFF',
              style: TextStyle(
                color: isOn ? accentColor : const Color(0xFF71717A),
                fontSize: 10.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds an activity indicator dot with label.
  Widget _buildStatusLed(String label, Color color, {required bool isLit}) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: 6.5,
          height: 6.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLit ? color : const Color(0xFF27272A),
          ),
        ),
        const SizedBox(width: 4.0),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF71717A),
            fontSize: 9.0,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Builds a minimalist color pill for RGB selection.
  Widget _buildRgbPill(String label, Color color, RgbMode mode) {
    final isSelected = widget.bridge.rgbMode == mode;

    return InkWell(
      onTap: () => widget.bridge.setRgb(mode),
      borderRadius: BorderRadius.circular(8.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF18181B) : const Color(0xFF121215),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF27272A),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6.0,
              height: 6.0,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5.0),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFFAFAFA) : const Color(0xFFA1A1AA),
                fontSize: 11.0,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// CustomPainter rendering a realistic, aerodynamic 3-blade cooling fan rotor.
class CoolingFanRotorPainter extends CustomPainter {
  // Color tint of the fan blades and hub.
  final Color color;

  const CoolingFanRotorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Draws central mounting hub
    canvas.drawCircle(center, 3.2, paint);

    // Draws 3 aerodynamic curved fan rotor blades spaced at 120-degree intervals.
    for (int i = 0; i < 3; i++) {
      final baseAngle = i * (2 * math.pi / 3) - (math.pi / 2);
      final path = Path();

      const innerRadius = 2.8;
      final outerRadius = size.width * 0.48; // ~9.6px for 20x20

      final p0 = center + Offset(innerRadius * math.cos(baseAngle - 0.35), innerRadius * math.sin(baseAngle - 0.35));
      final pTipLeading = center + Offset(outerRadius * math.cos(baseAngle + 0.15), outerRadius * math.sin(baseAngle + 0.15));
      final pTipTrailing = center + Offset(outerRadius * 0.88 * math.cos(baseAngle + 0.65), outerRadius * 0.88 * math.sin(baseAngle + 0.65));
      final p3 = center + Offset(innerRadius * math.cos(baseAngle + 0.45), innerRadius * math.sin(baseAngle + 0.45));

      path.moveTo(p0.dx, p0.dy);
      // Aerodynamic swept leading edge
      path.quadraticBezierTo(
        center.dx + (outerRadius * 0.6 * math.cos(baseAngle)),
        center.dy + (outerRadius * 0.6 * math.sin(baseAngle)),
        pTipLeading.dx,
        pTipLeading.dy,
      );
      // Curved blade tip perimeter
      path.quadraticBezierTo(
        center.dx + (outerRadius * math.cos(baseAngle + 0.42)),
        center.dy + (outerRadius * math.sin(baseAngle + 0.42)),
        pTipTrailing.dx,
        pTipTrailing.dy,
      );
      // Trailing edge returning to mounting hub
      path.quadraticBezierTo(
        center.dx + (outerRadius * 0.5 * math.cos(baseAngle + 0.6)),
        center.dy + (outerRadius * 0.5 * math.sin(baseAngle + 0.6)),
        p3.dx,
        p3.dy,
      );
      path.close();

      canvas.drawPath(path, paint);
    }

    // Mechanical central axle core
    final axlePaint = Paint()
      ..color = const Color(0xFF121215)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 1.2, axlePaint);
  }

  @override
  bool shouldRepaint(covariant CoolingFanRotorPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
