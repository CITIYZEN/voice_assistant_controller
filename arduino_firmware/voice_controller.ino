/*
 * ======================================================================================
 * PROJECT: HVASSI Smart Home Voice Controller - Arduino Firmware
 * BAUD RATE: 9600 Baud (8-N-1)
 * COMPATIBILITY: Arduino Uno, Nano, Mega, ESP8266, ESP32
 * AUTHOR: CITIYZEN (Smart Home Voice Controller Project)
 * ======================================================================================
 */

// Pin definition for Relay 1 controlling Living Room Light (Digital Pin D7)
const int PIN_RELAY_1 = 7;

// Pin definition for Relay 2 controlling Cooling Fan (Digital Pin D8)
const int PIN_RELAY_2 = 8;

// Pin definition for Relay 3 controlling Smart Plug / TV (Digital Pin D9)
const int PIN_RELAY_3 = 9;

// PWM Pin definition for Common Cathode RGB LED Red channel (Digital Pin D3)
const int PIN_RGB_RED = 3;

// PWM Pin definition for Common Cathode RGB LED Green channel (Digital Pin D5)
const int PIN_RGB_GREEN = 5;

// PWM Pin definition for Common Cathode RGB LED Blue channel (Digital Pin D6)
const int PIN_RGB_BLUE = 6;

// Logic level defining when an active-low relay module is energized (LOW for optocoupler relays)
const int RELAY_ON = LOW;

// Logic level defining when an active-low relay module is de-energized (HIGH turns relay off)
const int RELAY_OFF = HIGH;

// Buffer string storing incoming characters received from the serial stream
String inputBuffer = "";

// Flag indicating whether dynamic rainbow cycle party mode is currently active
bool isPartyModeActive = false;

// Tracks elapsed time in milliseconds for non-blocking rainbow color cycling
unsigned long lastColorUpdate = 0;

// Current hue angle in degrees (0 - 359) for smooth rainbow transitions
int currentHue = 0;

// Function prototype declarations
void processCommand(String command);
void setRgbColor(int r, int g, int b);
void updateRainbowCycle();
void setHueColor(int hue);

// Arduino setup function executed once at microcontroller boot
void setup() {
  // Pre-allocates SRAM buffer memory to prevent dynamic heap fragmentation on ATmega328P
  inputBuffer.reserve(32);

  // Configures the hardware UART serial port for communication at 9600 Baud
  Serial.begin(9600);

  // Sets Relay 1 pin as digital output
  pinMode(PIN_RELAY_1, OUTPUT);

  // Sets Relay 2 pin as digital output
  pinMode(PIN_RELAY_2, OUTPUT);

  // Sets Relay 3 pin as digital output
  pinMode(PIN_RELAY_3, OUTPUT);

  // Initializes all relays in the de-energized (OFF) state upon boot
  digitalWrite(PIN_RELAY_1, RELAY_OFF);
  digitalWrite(PIN_RELAY_2, RELAY_OFF);
  digitalWrite(PIN_RELAY_3, RELAY_OFF);

  // Sets RGB LED Red PWM pin as digital output
  pinMode(PIN_RGB_RED, OUTPUT);

  // Sets RGB LED Green PWM pin as digital output
  pinMode(PIN_RGB_GREEN, OUTPUT);

  // Sets RGB LED Blue PWM pin as digital output
  pinMode(PIN_RGB_BLUE, OUTPUT);

  // Extinguishes RGB LED upon boot
  setRgbColor(0, 0, 0);

  // Transmits startup boot message to serial monitor
  Serial.println(F("[ARDUINO BOOT]: HVASSI Voice Controller Online. 9600 Baud."));
}

// Arduino main execution loop running continuously
void loop() {
  // Reads any available bytes arriving on the serial stream (Bluetooth or USB UART)
  while (Serial.available() > 0) {
    // Reads a single character from the incoming serial stream
    char incomingChar = (char)Serial.read();

    // Checks if the incoming character is a carriage return or newline delimiter
    if (incomingChar == '\n' || incomingChar == '\r') {
      // Strips leading/trailing whitespace from buffered command token
      inputBuffer.trim();

      // If buffer is not empty, process the complete serial token
      if (inputBuffer.length() > 0) {
        // Dispatches token to the command decoder
        processCommand(inputBuffer);
        // Resets the input buffer for the next incoming command
        inputBuffer = "";
      }
    } else {
      // Appends character to the accumulated command string buffer
      inputBuffer += incomingChar;

      // Microcontroller SRAM safety guard: flush buffer if noisy serial data exceeds capacity
      if (inputBuffer.length() > 32) {
        inputBuffer = "";
      }
    }
  }

  // If party mode is enabled, smoothly animate rainbow color cycle non-blockingly
  if (isPartyModeActive) {
    updateRainbowCycle();
  }
}

// Decodes incoming serial tokens and switches physical relays and PWM RGB pins
void processCommand(String command) {
  // Converts command to uppercase to ensure case-insensitive token handling
  command.toUpperCase();

  // =========================================================================
  // RELAY 1: LIVING ROOM LIGHT (PIN D7)
  // =========================================================================
  if (command == "R1_ON") {
    // Energizes Relay 1
    digitalWrite(PIN_RELAY_1, RELAY_ON);
    // Sends acknowledgment string matching Flutter app parser
    Serial.println(F("ACK: Relay 1 ON"));
  }
  else if (command == "R1_OFF") {
    // De-energizes Relay 1
    digitalWrite(PIN_RELAY_1, RELAY_OFF);
    // Sends acknowledgment string
    Serial.println(F("ACK: Relay 1 OFF"));
  }

  // =========================================================================
  // RELAY 2: COOLING FAN (PIN D8)
  // =========================================================================
  else if (command == "R2_ON") {
    // Energizes Relay 2
    digitalWrite(PIN_RELAY_2, RELAY_ON);
    // Sends acknowledgment string
    Serial.println(F("ACK: Relay 2 ON"));
  }
  else if (command == "R2_OFF") {
    // De-energizes Relay 2
    digitalWrite(PIN_RELAY_2, RELAY_OFF);
    // Sends acknowledgment string
    Serial.println(F("ACK: Relay 2 OFF"));
  }

  // =========================================================================
  // RELAY 3: SMART PLUG / TV (PIN D9)
  // =========================================================================
  else if (command == "R3_ON") {
    // Energizes Relay 3
    digitalWrite(PIN_RELAY_3, RELAY_ON);
    // Sends acknowledgment string
    Serial.println(F("ACK: Relay 3 ON"));
  }
  else if (command == "R3_OFF") {
    // De-energizes Relay 3
    digitalWrite(PIN_RELAY_3, RELAY_OFF);
    // Sends acknowledgment string
    Serial.println(F("ACK: Relay 3 OFF"));
  }

  // =========================================================================
  // RGB LED MOOD LIGHTING CONTROLS (PINS D3, D5, D6)
  // =========================================================================
  else if (command == "RGB_RED") {
    // Disables dynamic party mode cycle
    isPartyModeActive = false;
    // Sets color to full Red
    setRgbColor(255, 0, 0);
    // Sends acknowledgment
    Serial.println(F("ACK: RGB RED"));
  }
  else if (command == "RGB_GREEN") {
    // Disables dynamic party mode cycle
    isPartyModeActive = false;
    // Sets color to full Green
    setRgbColor(0, 255, 0);
    // Sends acknowledgment
    Serial.println(F("ACK: RGB GREEN"));
  }
  else if (command == "RGB_BLUE") {
    // Disables dynamic party mode cycle
    isPartyModeActive = false;
    // Sets color to full Blue
    setRgbColor(0, 0, 255);
    // Sends acknowledgment
    Serial.println(F("ACK: RGB BLUE"));
  }
  else if (command == "RGB_WHITE") {
    // Disables dynamic party mode cycle
    isPartyModeActive = false;
    // Sets color to balanced White
    setRgbColor(255, 255, 255);
    // Sends acknowledgment
    Serial.println(F("ACK: RGB WHITE"));
  }
  else if (command == "RGB_CYCLE") {
    // Activates dynamic party mode rainbow cycling
    isPartyModeActive = true;
    // Sends acknowledgment
    Serial.println(F("ACK: RGB CYCLE"));
  }
  else if (command == "RGB_OFF") {
    // Disables dynamic party mode cycle
    isPartyModeActive = false;
    // Extinguishes all RGB channels
    setRgbColor(0, 0, 0);
    // Sends acknowledgment
    Serial.println(F("ACK: RGB OFF"));
  }

  // =========================================================================
  // MASTER CONTROLS: ALL ON / ALL OFF
  // =========================================================================
  else if (command == "ALL_ON") {
    // Disables party cycle
    isPartyModeActive = false;
    // Energizes all three relays
    digitalWrite(PIN_RELAY_1, RELAY_ON);
    digitalWrite(PIN_RELAY_2, RELAY_ON);
    digitalWrite(PIN_RELAY_3, RELAY_ON);
    // Sets RGB to bright ambient white
    setRgbColor(255, 255, 255);
    // Sends master acknowledgment
    Serial.println(F("ACK: ALL RELAYS ON"));
  }
  else if (command == "ALL_OFF") {
    // Disables party cycle
    isPartyModeActive = false;
    // De-energizes all three relays
    digitalWrite(PIN_RELAY_1, RELAY_OFF);
    digitalWrite(PIN_RELAY_2, RELAY_OFF);
    digitalWrite(PIN_RELAY_3, RELAY_OFF);
    // Extinguishes RGB mood light
    setRgbColor(0, 0, 0);
    // Sends master acknowledgment
    Serial.println(F("ACK: ALL RELAYS OFF"));
  }

  // Handler for unrecognized tokens
  else {
    Serial.print(F("ERR: Unrecognized Command ["));
    Serial.print(command);
    Serial.println(F("]"));
  }
}

// Writes 8-bit PWM duty cycle values (0-255) to RGB pins
void setRgbColor(int r, int g, int b) {
  // Writes analog PWM duty cycle to Red pin D3
  analogWrite(PIN_RGB_RED, r);
  // Writes analog PWM duty cycle to Green pin D5
  analogWrite(PIN_RGB_GREEN, g);
  // Writes analog PWM duty cycle to Blue pin D6
  analogWrite(PIN_RGB_BLUE, b);
}

// Smoothly cycles rainbow colors every 20 milliseconds without blocking serial reception
void updateRainbowCycle() {
  // Checks if 20ms update period has elapsed
  if (millis() - lastColorUpdate >= 20) {
    // Updates timestamp
    lastColorUpdate = millis();
    // Converts current hue angle into RGB color values
    setHueColor(currentHue);
    // Increments hue angle
    currentHue = (currentHue + 1) % 360;
  }
}

// Converts a Hue angle (0 - 359) into corresponding Red, Green, Blue PWM values
void setHueColor(int hue) {
  int r = 0, g = 0, b = 0;
  int sector = hue / 60;
  int fract = (hue % 60) * 255 / 60;

  switch (sector) {
    case 0:
      r = 255;
      g = fract;
      b = 0;
      break;
    case 1:
      r = 255 - fract;
      g = 255;
      b = 0;
      break;
    case 2:
      r = 0;
      g = 255;
      b = fract;
      break;
    case 3:
      r = 0;
      g = 255 - fract;
      b = 255;
      break;
    case 4:
      r = fract;
      g = 0;
      b = 255;
      break;
    case 5:
    default:
      r = 255;
      g = 0;
      b = 255 - fract;
      break;
  }

  setRgbColor(r, g, b);
}
