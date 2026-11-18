// Imports core Flutter framework components.
import 'package:flutter/material.dart';
// Imports clipboard service so user can copy serial logs with one tap.
import 'package:flutter/services.dart';
// Imports HardwareBridge models and serial log data structures.
import '../services/hardware_bridge.dart';

// SerialMonitor renders a collapsible, Vaul-style 9600 Baud UART serial console.
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

// State class managing expansion, auto-scrolling, and terminal rendering.
class _SerialMonitorState extends State<SerialMonitor> {
  // ScrollController to automatically follow incoming log lines.
  final ScrollController _scrollController = ScrollController();

  // Flag determining whether the console drawer is expanded or collapsed.
  bool _isExpanded = false;

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
      // Triggers snap to bottom if autoscroll is enabled and console is expanded.
      if (_autoScroll && _isExpanded) {
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
    final allLogs = widget.bridge.serialLogs
        .map((entry) => '[${entry.formattedTime}] ${entry.message}')
        .join('\n');

    Clipboard.setData(ClipboardData(text: allLogs));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Serial logs copied to clipboard'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF18181B),
      ),
    );
  }

  // Resolves text color based on transmission direction (TX, RX, SYS).
  Color _resolveLogColor(String direction) {
    switch (direction) {
      case 'TX':
        return const Color(0xFF10B981);
      case 'RX':
        return const Color(0xFFF59E0B);
      case 'SYS':
      default:
        return const Color(0xFF06B6D4);
    }
  }

  // Builds the Serial Monitor console UI.
  @override
  Widget build(BuildContext context) {
    final logs = widget.bridge.serialLogs;
    final latestLog = logs.isNotEmpty ? logs.last : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF121215),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        children: [
          // -----------------------------------------------------------
          // VAUL-STYLE HEADER (Drag Handle & Quick-Peek Status Bar)
          // -----------------------------------------------------------
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
              if (_isExpanded) {
                _scrollToBottom();
              }
            },
            borderRadius: BorderRadius.circular(16.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              child: Column(
                children: [
                  // Subtle top drag handle bar.
                  Container(
                    width: 32.0,
                    height: 3.5,
                    margin: const EdgeInsets.only(bottom: 8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27272A),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),

                  // Main header row.
                  Row(
                    children: [
                      const Icon(
                        Icons.terminal,
                        color: Color(0xFFA1A1AA),
                        size: 16.0,
                      ),
                      const SizedBox(width: 8.0),
                      const Text(
                        'Serial Console',
                        style: TextStyle(
                          color: Color(0xFFFAFAFA),
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181B),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: const Text(
                          '9600 8-N-1',
                          style: TextStyle(
                            color: Color(0xFFA1A1AA),
                            fontSize: 9.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),

                      const Spacer(),

                      // If collapsed: Inline Quick-Peek of the latest serial transaction.
                      if (!_isExpanded && latestLog != null) ...[
                        Expanded(
                          flex: 3,
                          child: Text(
                            latestLog.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: _resolveLogColor(latestLog.direction),
                              fontSize: 11.0,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 6.0),
                      ],

                      // Expand / Collapse Chevron Icon.
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: const Color(0xFFA1A1AA),
                        size: 18.0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // -----------------------------------------------------------
          // EXPANDED TERMINAL VIEW: Controls Toolbar & Monospaced Log History
          // -----------------------------------------------------------
          if (_isExpanded) ...[
            const Divider(color: Color(0xFF27272A), height: 1.0),

            // Controls sub-bar (Autoscroll, Copy, Clear).
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
              color: const Color(0xFF18181B),
              child: Row(
                children: [
                  // Autoscroll toggle button.
                  InkWell(
                    onTap: () {
                      setState(() {
                        _autoScroll = !_autoScroll;
                      });
                    },
                    borderRadius: BorderRadius.circular(6.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                      child: Row(
                        children: [
                          Icon(
                            _autoScroll ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: _autoScroll ? const Color(0xFF10B981) : const Color(0xFF71717A),
                            size: 14.0,
                          ),
                          const SizedBox(width: 5.0),
                          const Text(
                            'Autoscroll',
                            style: TextStyle(
                              color: Color(0xFFA1A1AA),
                              fontSize: 11.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Copy all logs button.
                  IconButton(
                    icon: const Icon(Icons.copy, size: 15.0),
                    color: const Color(0xFFA1A1AA),
                    tooltip: 'Copy logs',
                    splashRadius: 14.0,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4.0),
                    onPressed: _copyAllLogs,
                  ),

                  const SizedBox(width: 8.0),

                  // Clear console button.
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16.0),
                    color: const Color(0xFF71717A),
                    tooltip: 'Clear console',
                    splashRadius: 14.0,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4.0),
                    onPressed: () => widget.bridge.clearLogs(),
                  ),
                ],
              ),
            ),

            // Monospaced CRT Terminal Window.
            Container(
              height: 200.0,
              width: double.infinity,
              color: const Color(0xFF09090B),
              child: logs.isEmpty
                  ? const Center(
                      child: Text(
                        'Awaiting serial transmission...',
                        style: TextStyle(
                          color: Color(0xFF71717A),
                          fontFamily: 'monospace',
                          fontSize: 11.5,
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
                                fontSize: 11.0,
                                height: 1.4,
                              ),
                              children: [
                                TextSpan(
                                  text: '${entry.formattedTime} ',
                                  style: const TextStyle(color: Color(0xFF71717A)),
                                ),
                                TextSpan(
                                  text: entry.direction == 'TX'
                                      ? '➔ '
                                      : entry.direction == 'RX'
                                          ? '⬅ '
                                          : '⚙ ',
                                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: entry.message,
                                  style: TextStyle(color: color),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
