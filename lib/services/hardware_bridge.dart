// Imports asynchronous tools for handling timers and future callbacks.
import 'dart:async';
// Imports Flutter material library for Color classes and ChangeNotifier base class.
import 'package:flutter/material.dart';
// Imports the HTTP client package for transmitting commands to ESP32 Wi-Fi bridge.
import 'package:http/http.dart' as http;

// Enumeration defining the operational mode of the hardware bridge.
enum BridgeMode {
  // Standalone simulation mode with zero physical hardware dependencies.
  simulation,
  // Hardware transmission mode for real Arduino / ESP32 modules.
  hardware,
}

// Enumeration defining the physical communication transport used in Hardware Mode.
enum HardwareTransport {
  // Bluetooth Classic SPP (Serial Port Profile) for HC-05 / HC-06 modules.
  bluetooth,
  // Local Wi-Fi HTTP REST API for ESP32 microcontrollers.
  wifiHttp,
}

// Enumeration representing the active color or animated pattern of the RGB LED.
enum RgbMode {
  // LED extinguished (black).
  off,
  // Solid vibrant Red.
  red,
  // Solid vibrant Green.
  green,
  // Solid vibrant Blue.
  blue,
  // Solid ambient White.
  white,
  // Dynamic color cycling rainbow party mode.
  cycle,
}

// Model representing a single serial communication entry for the live monitor.
class SerialLogEntry {
  // Timestamp when the communication event occurred.
  final DateTime timestamp;

  // Transmission direction: 'TX' (outgoing), 'RX' (incoming), or 'SYS' (system message).
  final String direction;

  // The actual serial string payload sent or received.
  final String message;

  // Constructor initializing all fields of the serial log entry.
  SerialLogEntry({
    // Sets timestamp.
    required this.timestamp,
    // Sets direction.
    required this.direction,
    // Sets message content.
    required this.message,
  });

  // Formats time into a clean HH:mm:ss.SSS timestamp string.
  String get formattedTime {
    // Extracts hour string padded with leading zero.
    final h = timestamp.hour.toString().padLeft(2, '0');
    // Extracts minute string padded with leading zero.
    final m = timestamp.minute.toString().padLeft(2, '0');
    // Extracts second string padded with leading zero.
    final s = timestamp.second.toString().padLeft(2, '0');
    // Extracts millisecond string padded with three digits.
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    // Combines parts into standard serial console timestamp format.
    return '$h:$m:$s.$ms';
  }
}

// HardwareBridge manages state synchronization, serial logging, and communication routing.
class HardwareBridge extends ChangeNotifier {
  // Active operational mode (defaults to simulation mode for out-of-the-box operation).
  BridgeMode _mode = BridgeMode.simulation;

  // Active hardware transport for hardware mode (defaults to Wi-Fi HTTP).
  HardwareTransport _transport = HardwareTransport.wifiHttp;

  // Configurable IP address of the target ESP32 Wi-Fi smart controller.
  String _esp32IpAddress = '192.168.4.1';

  // Configurable port number for the ESP32 HTTP server.
  int _esp32Port = 80;

  // Current power state of Relay 1 (Living Room Light - Pin D7).
  bool _relay1On = false;

  // Current power state of Relay 2 (Cooling Fan - Pin D8).
  bool _relay2On = false;

  // Current power state of Relay 3 (Smart Plug / TV - Pin D9).
  bool _relay3On = false;

  // Current color state of the virtual RGB LED.
  RgbMode _rgbMode = RgbMode.off;

  // Transient TX LED blink indicator flag for the virtual Arduino board.
  bool _txBlinking = false;

  // Transient RX LED blink indicator flag for the virtual Arduino board.
  bool _rxBlinking = false;

  // History list of serial monitor log entries.
  final List<SerialLogEntry> _serialLogs = [];

  // Maximum number of entries kept in memory to prevent performance degradation.
  static const int _maxLogHistory = 300;

  // Constructor adding initial startup greeting to the serial monitor log.
  HardwareBridge() {
    // Appends initial system announcement log.
    _addLog('SYS', 'HVASSI Hardware Bridge initialized. Simulation Mode ACTIVE (9600 Baud).');
  }

  // Getter for current operating mode.
  BridgeMode get mode => _mode;

  // Getter for current hardware transport protocol.
  HardwareTransport get transport => _transport;

  // Getter for ESP32 IP address.
  String get esp32IpAddress => _esp32IpAddress;

  // Getter for ESP32 Port.
  int get esp32Port => _esp32Port;

  // Getter for Relay 1 (Light) power state.
  bool get relay1On => _relay1On;

  // Getter for Relay 2 (Fan) power state.
  bool get relay2On => _relay2On;

  // Getter for Relay 3 (Plug/TV) power state.
  bool get relay3On => _relay3On;

  // Getter for active RGB mode.
  RgbMode get rgbMode => _rgbMode;

  // Getter for TX activity LED state.
  bool get txBlinking => _txBlinking;

  // Getter for RX activity LED state.
  bool get rxBlinking => _rxBlinking;

  // Getter providing unmodifiable view of serial log entries.
  List<SerialLogEntry> get serialLogs => List.unmodifiable(_serialLogs);

  // Switches between Simulation Mode and Hardware Mode.
  void setMode(BridgeMode newMode) {
    // Checks if mode changed.
    if (_mode != newMode) {
      // Updates mode.
      _mode = newMode;
      // Logs the mode change event to the serial console.
      _addLog('SYS', 'Operating Mode switched to: ${_mode == BridgeMode.simulation ? "SIMULATION" : "HARDWARE"}');
      // Notifies listeners to update UI representations.
      notifyListeners();
    }
  }

  // Configures the active physical hardware communication transport.
  void setTransport(HardwareTransport newTransport) {
    // Updates transport selection.
    _transport = newTransport;
    // Logs transport selection.
    _addLog('SYS', 'Hardware Transport set to: ${_transport == HardwareTransport.wifiHttp ? "ESP32 Wi-Fi HTTP" : "Bluetooth Classic HC-05"}');
    // Notifies UI listeners.
    notifyListeners();
  }

  // Updates the target ESP32 Wi-Fi IP address.
  void setEsp32Ip(String ip, [int port = 80]) {
    // Updates IP.
    _esp32IpAddress = ip.trim();
    // Updates port.
    _esp32Port = port;
    // Logs configuration change.
    _addLog('SYS', 'ESP32 endpoint updated to http://$_esp32IpAddress:$_esp32Port/command');
    // Notifies listeners.
    notifyListeners();
  }

  // Main entry point to transmit a serial command token to the smart home system.
  Future<void> sendCommand(String token) async {
    // Formats the serial command payload with carriage return and newline terminator.
    final payload = '$token\\n';

    // Logs outgoing TX message to serial monitor.
    _addLog('TX', '[TX -> Arduino]: "$payload"');

    // Triggers visual TX LED pulse on the virtual Arduino board.
    _triggerTxPulse();

    // Routes command execution according to active operational mode.
    if (_mode == BridgeMode.simulation) {
      // Executes virtual command simulation.
      await _executeSimulation(token);
    } else {
      // Dispatches command to real hardware module.
      await _executeHardware(token);
    }
  }

  // Executes command simulation by updating virtual board state and issuing simulated ACK.
  Future<void> _executeSimulation(String token) async {
    // Simulates realistic 25-millisecond microcontroller UART reception latency.
    await Future.delayed(const Duration(milliseconds: 25));

    // String holding the simulated Arduino acknowledgment response.
    String ackResponse;

    // Evaluates token to update virtual hardware state and formulate response.
    switch (token) {
      // Relay 1 (Light) ON
      case 'R1_ON':
        _relay1On = true;
        ackResponse = 'ACK: Relay 1 ON';
        break;

      // Relay 1 (Light) OFF
      case 'R1_OFF':
        _relay1On = false;
        ackResponse = 'ACK: Relay 1 OFF';
        break;

      // Relay 2 (Fan) ON
      case 'R2_ON':
        _relay2On = true;
        ackResponse = 'ACK: Relay 2 ON';
        break;

      // Relay 2 (Fan) OFF
      case 'R2_OFF':
        _relay2On = false;
        ackResponse = 'ACK: Relay 2 OFF';
        break;

      // Relay 3 (Plug/TV) ON
      case 'R3_ON':
        _relay3On = true;
        ackResponse = 'ACK: Relay 3 ON';
        break;

      // Relay 3 (Plug/TV) OFF
      case 'R3_OFF':
        _relay3On = false;
        ackResponse = 'ACK: Relay 3 OFF';
        break;

      // RGB Red
      case 'RGB_RED':
        _rgbMode = RgbMode.red;
        ackResponse = 'ACK: RGB RED';
        break;

      // RGB Green
      case 'RGB_GREEN':
        _rgbMode = RgbMode.green;
        ackResponse = 'ACK: RGB GREEN';
        break;

      // RGB Blue
      case 'RGB_BLUE':
        _rgbMode = RgbMode.blue;
        ackResponse = 'ACK: RGB BLUE';
        break;

      // RGB White
      case 'RGB_WHITE':
        _rgbMode = RgbMode.white;
        ackResponse = 'ACK: RGB WHITE';
        break;

      // RGB Party Mode Cycle
      case 'RGB_CYCLE':
        _rgbMode = RgbMode.cycle;
        ackResponse = 'ACK: RGB CYCLE';
        break;

      // RGB Turn Off
      case 'RGB_OFF':
        _rgbMode = RgbMode.off;
        ackResponse = 'ACK: RGB OFF';
        break;

      // Master All Devices ON
      case 'ALL_ON':
        _relay1On = true;
        _relay2On = true;
        _relay3On = true;
        _rgbMode = RgbMode.white;
        ackResponse = 'ACK: ALL RELAYS ON';
        break;

      // Master All Devices OFF
      case 'ALL_OFF':
        _relay1On = false;
        _relay2On = false;
        _relay3On = false;
        _rgbMode = RgbMode.off;
        ackResponse = 'ACK: ALL RELAYS OFF';
        break;

      // Default handler for unrecognized commands
      default:
        ackResponse = 'ERR: Unknown Token "$token"';
        break;
    }

    // Triggers visual RX LED pulse on the virtual Arduino board.
    _triggerRxPulse();

    // Logs simulated Arduino acknowledgment to the live serial monitor.
    _addLog('RX', '[RX <- Arduino]: "$ackResponse"');

    // Notifies UI widgets to refresh their visual indicators immediately.
    notifyListeners();
  }

  // Dispatches command to physical hardware module via Wi-Fi HTTP or Bluetooth SPP.
  Future<void> _executeHardware(String token) async {
    // If using Wi-Fi HTTP transport to talk with ESP32:
    if (_transport == HardwareTransport.wifiHttp) {
      // Constructs endpoint URI for the ESP32 REST server.
      final url = Uri.parse('http://$_esp32IpAddress:$_esp32Port/command');

      try {
        // Sends HTTP POST request with command payload.
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'cmd': token},
        ).timeout(const Duration(milliseconds: 2500));

        // Triggers RX LED pulse upon receiving response.
        _triggerRxPulse();

        // Checks if microcontroller returned successful 200 OK status.
        if (response.statusCode == 200) {
          // Logs hardware response body to serial monitor.
          _addLog('RX', '[RX <- ESP32]: "${response.body.trim()}"');
          // Optimistically mirrors state on virtual dashboard as well.
          _mirrorStateLocally(token);
        } else {
          // Logs non-200 HTTP status response.
          _addLog('RX', '[RX <- ESP32]: "HTTP Error ${response.statusCode}"');
        }
      } catch (e) {
        // Logs network connection or timeout exception.
        _addLog('SYS', '[Bridge Network Error]: Cannot reach $url ($e)');
      }
    } else {
      // Bluetooth Classic HC-05 SPP branch (Pre-wired for Phase 2 integration).
      _addLog('SYS', '[Bluetooth Bridge]: Sending "$token\\n" via HC-05 Bluetooth SPP...');
      // Mirrors state locally for seamless developer preview.
      _mirrorStateLocally(token);
    }
  }

  // Internal helper to update dashboard state flags when hardware acknowledgment occurs.
  void _mirrorStateLocally(String token) {
    if (token == 'R1_ON') _relay1On = true;
    if (token == 'R1_OFF') _relay1On = false;
    if (token == 'R2_ON') _relay2On = true;
    if (token == 'R2_OFF') _relay2On = false;
    if (token == 'R3_ON') _relay3On = true;
    if (token == 'R3_OFF') _relay3On = false;
    if (token == 'RGB_RED') _rgbMode = RgbMode.red;
    if (token == 'RGB_GREEN') _rgbMode = RgbMode.green;
    if (token == 'RGB_BLUE') _rgbMode = RgbMode.blue;
    if (token == 'RGB_WHITE') _rgbMode = RgbMode.white;
    if (token == 'RGB_CYCLE') _rgbMode = RgbMode.cycle;
    if (token == 'RGB_OFF') _rgbMode = RgbMode.off;
    if (token == 'ALL_ON') {
      _relay1On = true;
      _relay2On = true;
      _relay3On = true;
      _rgbMode = RgbMode.white;
    }
    if (token == 'ALL_OFF') {
      _relay1On = false;
      _relay2On = false;
      _relay3On = false;
      _rgbMode = RgbMode.off;
    }
    notifyListeners();
  }

  // Manual interactive switch to toggle a specific relay from the UI dashboard.
  void toggleRelay(int relayNumber) {
    // Toggles Relay 1.
    if (relayNumber == 1) {
      sendCommand(_relay1On ? 'R1_OFF' : 'R1_ON');
    }
    // Toggles Relay 2.
    else if (relayNumber == 2) {
      sendCommand(_relay2On ? 'R2_OFF' : 'R2_ON');
    }
    // Toggles Relay 3.
    else if (relayNumber == 3) {
      sendCommand(_relay3On ? 'R3_OFF' : 'R3_ON');
    }
  }

  // Manual interactive selector to change the RGB LED mode from the UI.
  void setRgb(RgbMode mode) {
    // Maps selected enum to corresponding serial token.
    switch (mode) {
      case RgbMode.red:
        sendCommand('RGB_RED');
        break;
      case RgbMode.green:
        sendCommand('RGB_GREEN');
        break;
      case RgbMode.blue:
        sendCommand('RGB_BLUE');
        break;
      case RgbMode.white:
        sendCommand('RGB_WHITE');
        break;
      case RgbMode.cycle:
        sendCommand('RGB_CYCLE');
        break;
      case RgbMode.off:
        sendCommand('RGB_OFF');
        break;
    }
  }

  // Appends a new log entry to the live monitor history.
  void _addLog(String direction, String message) {
    // Inserts new log at the end of the history list.
    _serialLogs.add(
      SerialLogEntry(
        timestamp: DateTime.now(),
        direction: direction,
        message: message,
      ),
    );

    // Trims oldest logs if history exceeds maximum capacity.
    if (_serialLogs.length > _maxLogHistory) {
      _serialLogs.removeAt(0);
    }

    // Notifies UI to re-render serial console.
    notifyListeners();
  }

  // Clears all log entries from the serial monitor display.
  void clearLogs() {
    // Clears the list.
    _serialLogs.clear();
    // Adds reset announcement.
    _addLog('SYS', 'Serial log cleared by user.');
    // Notifies UI listeners.
    notifyListeners();
  }

  // Pulses the virtual Arduino board TX LED briefly.
  void _triggerTxPulse() {
    _txBlinking = true;
    notifyListeners();
    Timer(const Duration(milliseconds: 90), () {
      _txBlinking = false;
      notifyListeners();
    });
  }

  // Pulses the virtual Arduino board RX LED briefly.
  void _triggerRxPulse() {
    _rxBlinking = true;
    notifyListeners();
    Timer(const Duration(milliseconds: 90), () {
      _rxBlinking = false;
      notifyListeners();
    });
  }
}
