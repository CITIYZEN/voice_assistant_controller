# 🎙️ HVASSI: Voice Assistant Controller (Smart Home STT)

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%205.0+-3DDC84?logo=android&logoColor=white)](https://android.com)
[![Arduino](https://img.shields.io/badge/Firmware-Arduino%20Uno%2FNano-00979D?logo=arduino&logoColor=white)](https://arduino.cc)
[![Language](https://img.shields.io/badge/STT-Egyptian%20Arabic%20%7C%20English-blue)](#voice-command-dictionary)
[![Latency](https://img.shields.io/badge/Latency-Sub--150ms%20Zero--Lag-success)](#zero-latency-stt-architecture)

An ultra-fast, zero-latency Speech-to-Text (**STT**) Smart Home Voice Assistant mobile application targeting **Android**. Built with Flutter and an embedded **Virtual Arduino Simulator & 9600-Baud Live Serial Monitor**, this repository enables instant speech control of home appliances (Light, Fan, Plug/TV) and RGB mood lighting in both **Egyptian Arabic (`ar_EG`)** and **English (`en_US`)**, with zero physical hardware required upfront.

---

## 📋 Table of Contents
1. [Key Features](#-key-features)
2. [Project Architecture](#-project-architecture)
3. [Zero-Latency STT Architecture](#-zero-latency-stt-architecture)
4. [Voice Command Dictionary (EN & AR)](#-voice-command-dictionary-en--ar)
5. [Hardware Pinout & Wiring Diagram](#-hardware-pinout--wiring-diagram)
6. [Interactive Virtual Arduino Simulator](#-interactive-virtual-arduino-simulator)
7. [How to Build Release APK (`.apk`)](#-how-to-build-release-apk-apk)
8. [Hardware Deployment (Arduino Firmware)](#-hardware-deployment-arduino-firmware)
9. [Phase 2: Bluetooth & ESP32 Wi-Fi Bridge](#-phase-2-bluetooth--esp32-wi-fi-bridge)

---

## ⚡ Key Features

- 🏎️ **Ultra-Fast Real-Time Partial Streaming:** Utilizes `speech_to_text` with `partialResults: true` and `ListenMode.confirmation` to trigger commands instantaneously as words are spoken without waiting for silence or sentence completion.
- 🇪🇬 **Native Egyptian Arabic & English Support:** Full bidirectional keyword matching with custom **Arabic character normalization** (`أ/إ/آ -> ا`, `ة -> ه`, `ى -> ي`, stripping Tashkeel/diacritics and Tatweel).
- ⏱️ **Real-Time Latency Measurement:** Dynamic millisecond stopwatch benchmark displayed live on screen (typically **85 ms – 150 ms** detection speed).
- 🛡️ **Intelligent 1-Second Debounce:** Prevents duplicate triggering of commands during continuous partial audio streaming.
- 🎛️ **Interactive Virtual Arduino Dashboard:** Complete 3-Channel 5V relay module with glowing status indicators, spinning fan animation, and a multi-layer glowing PWM RGB LED.
- 🖥️ **Live 9600-Baud Serial Monitor:** Monospaced terminal logging outgoing `[TX -> Arduino]` commands and incoming `[RX <- Arduino]` acknowledgment responses.
- 🔌 **Modular Hardware Bridge:** Seamlessly switch between **Simulation Mode** (works right now out-of-the-box) and **Hardware Mode** (pre-wired for HC-05 Bluetooth SPP and ESP32 Wi-Fi HTTP POST).
- 📦 **Line-by-Line Documented:** Every single line in Dart, Kotlin, C++ Arduino firmware, and Android XML configuration is comprehensively commented for easy student review and academic evaluation.

---

## 🏗️ Project Architecture

```
voice_assistant_controller/
├── android/                                # Android native host project & Gradle configuration
│   └── app/src/main/
│       ├── AndroidManifest.xml             # Permissions (RECORD_AUDIO, INTERNET, BLUETOOTH, Queries)
│       └── kotlin/com/citiyzen/.../
│           └── MainActivity.kt             # Native Android entry point
├── arduino_firmware/
│   └── voice_controller.ino                # Non-blocking 9600 Baud Arduino C++ sketch & SerialDecoder
├── lib/
│   ├── main.dart                           # Futuristic dark-mode UI with hero pulsing mic & latency chip
│   ├── services/
│   │   ├── speech_service.dart             # Low-latency STT streaming engine & watchdog auto-restart
│   │   ├── command_parser.dart             # Arabic normalizer & phrase-to-token dictionary
│   │   └── hardware_bridge.dart            # State manager, simulation engine & serial logger
│   └── widgets/
│       ├── virtual_arduino_board.dart      # Interactive Uno PCB, 3 glowing relay cards & RGB diffuser
│       └── serial_monitor.dart             # 9600-baud CRT terminal with autoscroll and copy logs
├── pubspec.yaml                            # Dependencies (speech_to_text, http, cupertino_icons)
└── README.md                               # Project documentation & build guide
```

---

## ⚡ Zero-Latency STT Architecture

Traditional speech recognition engines buffer audio until the user stops speaking (often adding 1.5 – 3 seconds of silence latency). 

**HVASSI solves this with a 3-layer real-time pipeline:**
```
[User Utterance] ──> [Android SpeechRecognizer (Partial Stream)]
                             │
                             ▼ (Every spoken syllable)
                  [Arabic Normalizer & Lexical Filter]
                             │
                             ▼ (Instant Sub-String Scan)
                  [CommandParser Priority Dispatcher]
                             │
            ┌────────────────┴────────────────┐
            ▼ (Sub-150ms)                     ▼ (Instant)
     [HardwareBridge TX]               [Pulsing UI & Latency Badge]
```

### Arabic Normalization Filter
Spoken Egyptian Arabic frequently fluctuates in transcriptions depending on phone keyboard settings and acoustic models. The built-in normalizer unifies all variations:
- `أحمد` / `إضاءة` / `آلة` ➔ `ا`
- `المروحة` ➔ `المروحه`
- `على` ➔ `علي`
- Strips all Tashkeel diacritics: `َ ُ ِ ْ ّ ً ٌ ٍ`
- Strips Tatweel elongation: `ـ`

---

## 📖 Voice Command Dictionary (EN & AR)

All voice commands are mapped locally to lightweight Arduino Serial ASCII tokens:

### A. Relay Appliances (Pins D7, D8, D9)
| Device | Pin | Action | English Phrases | Egyptian Arabic Phrases | Arduino Serial Token |
| :--- | :---: | :---: | :--- | :--- | :---: |
| **Living Room Light** | **D7** | **ON** | `"turn on the light"`, `"light on"` | `"شغل النور"`, `"افتح النور"`, `"ولع النور"` | `R1_ON` |
| **Living Room Light** | **D7** | **OFF** | `"turn off the light"`, `"light off"` | `"اطفي النور"`, `"اقفل النور"`, `"طفي النور"` | `R1_OFF` |
| **Cooling Fan** | **D8** | **ON** | `"turn on the fan"`, `"fan on"` | `"شغل المروحة"`, `"افتح المروحة"` | `R2_ON` |
| **Cooling Fan** | **D8** | **OFF** | `"turn off the fan"`, `"fan off"` | `"اطفي المروحة"`, `"اقفل المروحة"` | `R2_OFF` |
| **Smart Plug / TV** | **D9** | **ON** | `"turn on the tv"`, `"plug on"` | `"شغل التلفزيون"`, `"شغل الفيشة"` | `R3_ON` |
| **Smart Plug / TV** | **D9** | **OFF** | `"turn off the tv"`, `"plug off"` | `"اطفي التلفزيون"`, `"اطفي الفيشة"` | `R3_OFF` |

### B. RGB LED Mood Lighting (Pins D3, D5, D6 PWM)
| Color / Mode | English Phrases | Egyptian Arabic Phrases | Serial Token |
| :--- | :--- | :--- | :---: |
| **Solid Red** | `"red light"`, `"red"`, `"make it red"` | `"نور أحمر"`, `"لون أحمر"` | `RGB_RED` |
| **Solid Green** | `"green light"`, `"green"`, `"set green"` | `"نور أخضر"`, `"لون أخضر"` | `RGB_GREEN` |
| **Solid Blue** | `"blue light"`, `"blue"`, `"set blue"` | `"نور أزرق"`, `"لون أزرق"` | `RGB_BLUE` |
| **Solid White** | `"white light"`, `"white"`, `"ambient white"` | `"نور أبيض"`, `"لون أبيض"` | `RGB_WHITE` |
| **Party Mode (Cycle)** | `"party mode"`, `"color cycle"`, `"rainbow"` | `"وضع الحفلة"`, `"ألوان متغيرة"` | `RGB_CYCLE` |
| **Turn Off RGB** | `"turn off rgb"`, `"rgb off"`, `"turn off led"` | `"اطفي الليد"`, `"اقفل الألوان"` | `RGB_OFF` |

### C. Master Controls
| Function | English Phrases | Egyptian Arabic Phrases | Serial Token |
| :--- | :--- | :--- | :---: |
| **Master Turn All ON** | `"turn everything on"`, `"all on"` | `"شغل كل حاجة"`, `"افتح الكل"` | `ALL_ON` |
| **Master Turn All OFF** | `"turn everything off"`, `"all off"`, `"goodnight"` | `"اطفي كل حاجة"`, `"اقفل الكل"`, `"تصبح على خير"` | `ALL_OFF` |

---

## 🔌 Hardware Pinout & Wiring Diagram

| Arduino Pin | Hardware Component | Electrical Specification | Note |
| :---: | :--- | :--- | :--- |
| **D7** | Relay Channel 1 IN | 5V Active-LOW Optocoupled | Controls 220V/110V Light |
| **D8** | Relay Channel 2 IN | 5V Active-LOW Optocoupled | Controls Cooling Fan |
| **D9** | Relay Channel 3 IN | 5V Active-LOW Optocoupled | Controls Smart Plug / TV |
| **D3 (PWM)** | RGB LED - Red Pin | 220Ω Current Limiting Resistor | Common Cathode LED |
| **D5 (PWM)** | RGB LED - Green Pin | 220Ω Current Limiting Resistor | Common Cathode LED |
| **D6 (PWM)** | RGB LED - Blue Pin | 220Ω Current Limiting Resistor | Common Cathode LED |
| **GND** | Relay GND & RGB Cathode | Ground reference | Common Ground |
| **5V** | Relay VCC | 5V DC Power rail | From Arduino or 5V PSU |
| **RX (Pin 0)** | HC-05 Bluetooth TX | 3.3V / 5V TTL | Connect via Voltage Divider |
| **TX (Pin 1)** | HC-05 Bluetooth RX | 3.3V TTL | Connect from Arduino TX |

```
                       +-------------------------+
                       |    ARDUINO UNO / NANO   |
                       |                         |
       [Light Bulb] <--| D7  ---------------> IN1|--+ 3-Channel
       [Cooling Fan]<--| D8  ---------------> IN2|  | 5V Relay
       [Plug / TV]  <--| D9  ---------------> IN3|--+ Module
                       |                         |
  [220Ω] - Red Channel | D3 (PWM)                |
[220Ω] - Green Channel | D5 (PWM)                |--> RGB LED
 [220Ω] - Blue Channel | D6 (PWM)                |    (Common Cathode)
                       |                         |
      [HC-05 BT TX] -->| RX (D0)                 |
      [HC-05 BT RX] <--| TX (D1)                 |
                       +-------------------------+
```

---

## 📱 Interactive Virtual Arduino Simulator

When you run the app on Android:
1. **Simulation Mode is active by default** — zero physical wires or hardware are needed.
2. Tap the **Microphone** and speak e.g. `"شغل النور"` or `"turn on the fan"`.
3. The app transcribes the audio in real-time, displays the measured detection latency (e.g. `⚡ 124 ms`), and transmits `R1_ON\n`.
4. In the **Virtual Arduino Board**:
   - The **TX/RX LEDs** flash.
   - The corresponding **Relay Card** glows, displays the active pin badge, and the fan begins spinning with live rotation physics.
5. In the **Live Serial Monitor**:
   - View formatted logs:
     ```
     [17:42:01.120] ➔ [TX -> Arduino]: "R1_ON\n"
     [17:42:01.145] ⬅ [RX <- Arduino]: "ACK: Relay 1 ON"
     ```
6. You can also tap any relay card or RGB color chip manually for rapid testing.

---

## 🚀 How to Build Release APK (`.apk`)

To generate a standalone release APK that you can transfer directly to an Android phone:

### 1. Ensure Flutter is Installed
Check that Flutter is in your system `PATH`:
```bash
flutter doctor
```

### 2. Fetch Dependencies
Navigate to the repository root and run:
```bash
flutter pub get
```

### 3. Build the Release APK
Run the official Flutter release build command:
```bash
flutter build apk --release
```

> **Target Output Path:**
> Once compilation completes, your installation `.apk` is located at:
> ```
> build/app/outputs/flutter-apk/app-release.apk
> ```
> Send this file to your phone via USB, WhatsApp, or Google Drive, enable *"Install unknown apps"* on Android, and launch your voice assistant!

---

## 🛠️ Hardware Deployment (Arduino Firmware)

To run with real physical microcontrollers:
1. Open the [arduino_firmware/voice_controller.ino](arduino_firmware/voice_controller.ino) sketch in the **Arduino IDE**.
2. Select your board (**Tools > Board > Arduino Uno**).
3. Connect your Arduino via USB and select the COM port.
4. Click **Upload** (Ctrl + U).
5. Open the Serial Monitor at **9600 Baud** to verify the boot message:
   ```
   [ARDUINO BOOT]: HVASSI Voice Controller Online. 9600 Baud.
   ```

---

## 📡 Phase 2: Bluetooth & ESP32 Wi-Fi Bridge

The app is architected with a modular bridge pattern (`lib/services/hardware_bridge.dart`):

### Option A: Bluetooth HC-05 / HM-10 (Classic SPP)
1. Pair your Android phone with `HC-05` (Default PIN: `1234`).
2. Uncomment `flutter_bluetooth_serial: ^0.4.0` in `pubspec.yaml`.
3. Switch the top bar mode badge in the app to **HW (Hardware)**.

### Option B: ESP32 Local Wi-Fi HTTP REST Server
1. The app includes a pre-wired HTTP POST dispatcher transmitting commands to:
   ```
   POST http://<ESP32_IP>:80/command
   Body: cmd=R1_ON
   ```
2. Simply configure the target ESP32 IP in the app settings modal sheet.

---

## 📄 License
This project is open-source under the **MIT License**. Created for academic smart home research and voice automation engineering.
