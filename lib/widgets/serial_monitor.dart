// Imports core Flutter framework components.
import 'package:flutter/material.dart';
// Imports clipboard service so user can copy serial logs with one tap.
import 'package:flutter/services.dart';
// Imports HardwareBridge models and serial log data structures.
import '../services/hardware_bridge.dart';

// SerialMonitor renders a real-time, scrollable 9600 Baud UART serial console.
class SerialMonitor extends StatefulWidget {
  // Reference to the shared hardware bridge instance.
  final HardwareBridge bridge;

  // Constructor taking the required hardware bridge instance.
  const SerialMonitor({
    // Passes widget key.
    super.key,
    // Assigns bridge.
    required this.bridge,
  });

  // Creates the mutable state object for this widget.
  @override
  State<SerialMonitor> createState() => _SerialMonitorState();
}

// State class managing auto-scrolling and terminal rendering.
class _SerialMonitorState extends State<SerialMonitor> {
  // ScrollController to automatically follow incoming log lines.
  final ScrollController _scrollController = ScrollController();

  // Flag determining whether console automatically scrolls down when new data arrives.
  bool _autoScroll = true;

  // Initializes state and registers listener for new serial log events.
  @override
  void initState() {
    // Calls base class initState.
    super.initState();
    // Registers change listener on the hardware bridge to update console text.
    widget.bridge.addListener(_onBridgeUpdated);
  }

  // Re-binds bridge listener if parent updates widget configuration.
  @override
  void didUpdateWidget(covariant SerialMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bridge != widget.bridge) {
      oldWidget.bridge.removeListener(_onBridgeUpdated);
      widget.bridge.addListener(_onBridgeUpdated);
    }
  }

  // Listener called whenever new serial messages are logged.
  void _onBridgeUpdated() {
    // Rebuilds widget to display newly appended log entries.
    if (mounted) {
      setState(() {});
      // Triggers smooth automatic scroll to bottom if autoscroll is enabled.
      if (_autoScroll) {
        _scrollToBottom();
      }
    }
  }

  // Snaps scroll position to the bottom of the console list without animation queue jitter.
  void _scrollToBottom() {
    // Delays execution to ensure Flutter layout measurement has finalized.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Verifies widget is mounted and scroll controller is attached to active viewport.
      if (!mounted || !_scrollController.hasClients) return;
      // Snaps directly to bottom using jumpTo to avoid queue stuttering during rapid serial logging.
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  // Disposes the scroll controller and unbinds listener cleanly.
  @override
  void dispose() {
    // Unbinds change listener.
    widget.bridge.removeListener(_onBridgeUpdated);
    // Disposes controller.
    _scrollController.dispose();
    // Calls super dispose.
    super.dispose();
  }

  // Copies entire serial log history to system clipboard.
  void _copyAllLogs() {
    // Concatenates all log lines into a single formatted string.
    final allLogs = widget.bridge.serialLogs
        .map((entry) => '[${entry.formattedTime}] ${entry.message}')
        .join('\n');

    // Writes text to system clipboard.
    Clipboard.setData(ClipboardData(text: allLogs));

    // Shows brief confirmation snackbar.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Serial logs copied to clipboard!'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF1E293B),
      ),
    );
  }

  // Resolves text color based on transmission direction (TX, RX, SYS).
  Color _resolveLogColor(String direction) {
    switch (direction) {
      // Outgoing TX commands: Vibrant Emerald Green.
      case 'TX':
        return const Color(0xFF10B981);
      // Incoming RX responses: Bright Electric Amber / Yellow.
      case 'RX':
        return const Color(0xFFFBBF24);
      // System diagnostics and state changes: Light Cyan / Sky Blue.
      case 'SYS':
      default:
        return const Color(0xFF38BDF8);
    }
  }

  // Builds the Serial Monitor console UI.
  @override
  Widget build(BuildContext context) {
    final logs = widget.bridge.serialLogs;

    return Container(
      // Margin around console.
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      // Console height constraint for scrollable terminal.
      height: 260.0,
      // Styling container with terminal CRT screen appearance.
      decoration: BoxDecoration(
        // Deep terminal black background.
        color: const Color(0xFF030712),
        // Rounded corners.
        borderRadius: BorderRadius.circular(16.0),
        // Subtle terminal boundary border.
        border: Border.all(
          color: const Color(0xFF1E293B),
          width: 1.5,
        ),
        // CRT shadow effect.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 18.0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      // Column holding terminal toolbar and scrollable log pane.
      child: Column(
        children: [
          // -----------------------------------------------------------
          // TERMINAL TOOLBAR: Title, Baud rate, Autoscroll & Actions
          // -----------------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15.0),
                topRight: Radius.circular(15.0),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E293B)),
              ),
            ),
            child: Row(
              children: [
                // Left title section wrapped in Flexible with overflow protection.
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Terminal prompt icon.
                      const Icon(
                        Icons.terminal,
                        color: Color(0xFF10B981),
                        size: 18.0,
                      ),
                      const SizedBox(width: 8.0),
                      // Console title with ellipsis overflow protection.
                      const Flexible(
                        child: Text(
                          'Serial Monitor',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      // Serial parameters badge.
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF020617),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Text(
                          '9600 8-N-1',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10.0,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Autoscroll toggle button.
                InkWell(
                  onTap: () {
                    setState(() {
                      _autoScroll = !_autoScroll;
                    });
                  },
                  borderRadius: BorderRadius.circular(6.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                    child: Row(
                      children: [
                        Icon(
                          _autoScroll ? Icons.check_box : Icons.check_box_outline_blank,
                          color: _autoScroll ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          size: 16.0,
                        ),
                        const SizedBox(width: 4.0),
                        const Text(
                          'Autoscroll',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8.0),

                // Copy all logs button.
                IconButton(
                  icon: const Icon(Icons.copy, size: 16.0),
                  color: const Color(0xFF94A3B8),
                  tooltip: 'Copy Logs',
                  splashRadius: 16.0,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4.0),
                  onPressed: _copyAllLogs,
                ),

                const SizedBox(width: 4.0),

                // Clear logs button.
                IconButton(
                  icon: const Icon(Icons.delete_sweep, size: 18.0),
                  color: const Color(0xFFEF4444),
                  tooltip: 'Clear Console',
                  splashRadius: 16.0,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4.0),
                  onPressed: () => widget.bridge.clearLogs(),
                ),
              ],
            ),
          ),

          // -----------------------------------------------------------
          // TERMINAL CONSOLE LOG VIEW (Monospaced Text Lines)
          // -----------------------------------------------------------
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'Waiting for serial transmission...',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontFamily: 'monospace',
                        fontSize: 12.0,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(10.0),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final entry = logs[index];
                      final color = _resolveLogColor(entry.direction);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                            children: [
                              // Timestamp prefix in muted grey.
                              TextSpan(
                                text: '${entry.formattedTime} ',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                ),
                              ),
                              // Direction indicator badge text.
                              TextSpan(
                                text: entry.direction == 'TX'
                                    ? '➔ '
                                    : entry.direction == 'RX'
                                        ? '⬅ '
                                        : '⚙ ',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // Actual serial log message string.
                              TextSpan(
                                text: entry.message,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: entry.direction == 'TX' ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
