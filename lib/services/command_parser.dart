// Data model encapsulating the parsed command details and metadata.
class CommandResult {
  // Serial command token sent to Arduino or ESP32 (e.g., 'R1_ON', 'RGB_RED').
  final String token;

  // Spoken phrase that triggered this command detection.
  final String matchedPhrase;

  // Human-readable English description of the executed action.
  final String description;

  // Category of the device affected (e.g., 'Relay', 'RGB', 'Master').
  final String category;

  // Constructor initializing all required fields for a command result.
  const CommandResult({
    // Sets the token property.
    required this.token,
    // Sets the matched phrase property.
    required this.matchedPhrase,
    // Sets the description property.
    required this.description,
    // Sets the category property.
    required this.category,
  });
}

// Internal representation of a voice command rule mapping keywords to tokens.
class _VoiceCommandRule {
  // Serial token to be transmitted to the hardware.
  final String token;

  // Friendly description of the command function.
  final String description;

  // Functional category of the command.
  final String category;

  // List of English and Franco-Arabic (Arabizi) trigger phrases.
  final List<String> englishPhrases;

  // List of Egyptian Arabic trigger phrases.
  final List<String> arabicPhrases;

  // Constructor for the voice command rule definition.
  const _VoiceCommandRule({
    // Sets the token.
    required this.token,
    // Sets the description.
    required this.description,
    // Sets the category.
    required this.category,
    // Sets the English and Franco phrases.
    required this.englishPhrases,
    // Sets the Arabic phrases.
    required this.arabicPhrases,
  });
}

// CommandParser maps spoken English, Egyptian Arabic, and Franco-Arabic inputs to Arduino Serial tokens.
class CommandParser {
  // Comprehensive list of smart home voice command rules structured by priority:
  // Priority 1: SECTION C (Master Controls)
  // Priority 2: SECTION B (RGB LED Mood Lighting)
  // Priority 3: SECTION A (Relay Appliances)
  static const List<_VoiceCommandRule> _rules = [
    // -------------------------------------------------------------
    // PRIORITY 1 - SECTION C: MASTER CONTROLS
    // Evaluated first so full-system phrases take precedence over individual relays.
    // -------------------------------------------------------------
    _VoiceCommandRule(
      // Token turning on all smart home appliances simultaneously.
      token: 'ALL_ON',
      // Friendly description of master turn on.
      description: 'Master Control: Turn All Devices ON',
      // Category identifier.
      category: 'Master',
      // Spoken English and Franco-Arabic phrases for master ON.
      englishPhrases: [
        'turn everything on',
        'turn all on',
        'turn all devices on',
        'all on',
        'everything on',
        'turn on everything',
        // Franco-Arabic (Arabizi) variants:
        'shaghal kol haga',
        'shaghal kol 7aga',
        'eftah kol haga',
        'eftah kol 7aga',
        'iftah kol haga',
        'iftah kol 7aga',
        'shaghal el kol',
        'eftah el kol',
        'kollo on',
        'kolo on',
      ],
      // Spoken Egyptian Arabic phrases for master ON (normalized forms).
      arabicPhrases: [
        'شغل كل حاجه',
        'افتح كل حاجه',
        'شغل الكل',
        'افتح الكل',
        'شغل كله',
        'افتح كله',
        'ولع كل حاجه',
      ],
    ),
    _VoiceCommandRule(
      // Token turning off all smart home appliances simultaneously.
      token: 'ALL_OFF',
      // Friendly description of master turn off.
      description: 'Master Control: Turn All Devices OFF (Goodnight)',
      // Category identifier.
      category: 'Master',
      // Spoken English and Franco-Arabic phrases for master OFF.
      englishPhrases: [
        'turn everything off',
        'turn all off',
        'turn all devices off',
        'all off',
        'everything off',
        'turn off everything',
        'goodnight',
        'good night',
        'sleep mode',
        // Franco-Arabic (Arabizi) variants:
        'itfi kol haga',
        'itfi kol 7aga',
        'etfi kol haga',
        'etfi kol 7aga',
        'eqfel kol haga',
        'eqfel kol 7aga',
        'e2fel kol haga',
        'ekfel kol haga',
        'itfi el kol',
        'etfi el kol',
        'eqfel el kol',
        'kollo off',
        'kolo off',
        'tisbah ala kheir',
        'tesbah ala kheir',
        'tisba7 3la 5air',
      ],
      // Spoken Egyptian Arabic phrases for master OFF (normalized forms).
      arabicPhrases: [
        'اطفي كل حاجه',
        'اقفل كل حاجه',
        'اطفي الكل',
        'اقفل الكل',
        'اطفي كله',
        'اقفل كله',
        'طفي كله',
        'طفي كل حاجه',
        'تصبح علي خير',
        'تصبح على خير',
        'وضع النوم',
      ],
    ),

    // -------------------------------------------------------------
    // PRIORITY 2 - SECTION B: RGB LED MOOD LIGHTING CONTROLS
    // Evaluated second so specific lighting requests (e.g., 'اطفي النور الملون')
    // never mistakenly trigger Relay 1 ('اطفي النور').
    // -------------------------------------------------------------
    // RGB Red Color
    _VoiceCommandRule(
      // Token to illuminate RGB LED in solid Red.
      token: 'RGB_RED',
      // Friendly description of RGB Red.
      description: 'RGB LED: Red Mood Lighting',
      // Category identifier.
      category: 'RGB',
      // Spoken English and Franco-Arabic phrases for Red.
      englishPhrases: [
        'turn on the red light',
        'turn on red light',
        'red light',
        'red color',
        'change to red',
        'make it red',
        'set red',
        'red led',
        // Franco-Arabic variants:
        'noor ahmar',
        'noor a7mar',
        'lawn ahmar',
        'shaghal el ahmar',
        'eftah el ahmar',
        'iftah el ahmar',
      ],
      // Spoken Egyptian Arabic phrases for Red (normalized).
      arabicPhrases: [
        'شغل النور الاحمر',
        'افتح النور الاحمر',
        'نور احمر',
        'لون احمر',
        'خليه احمر',
        'شغل الاحمر',
        'ليد احمر',
        'اضاءه حمرا',
        'نور احمر هادي',
      ],
    ),
    // RGB Green Color
    _VoiceCommandRule(
      // Token to illuminate RGB LED in solid Green.
      token: 'RGB_GREEN',
      // Friendly description of RGB Green.
      description: 'RGB LED: Green Mood Lighting',
      // Category identifier.
      category: 'RGB',
      // Spoken English and Franco-Arabic phrases for Green.
      englishPhrases: [
        'turn on the green light',
        'turn on green light',
        'green light',
        'green color',
        'change to green',
        'make it green',
        'set green',
        'green led',
        // Franco-Arabic variants:
        'noor akhdar',
        'noor a5dar',
        'lawn akhdar',
        'shaghal el akhdar',
        'eftah el akhdar',
        'iftah el akhdar',
      ],
      // Spoken Egyptian Arabic phrases for Green (normalized).
      arabicPhrases: [
        'شغل النور الاخضر',
        'افتح النور الاخضر',
        'نور اخضر',
        'لون اخضر',
        'خليه اخضر',
        'شغل الاخضر',
        'ليد اخضر',
        'اضاءه خضرا',
      ],
    ),
    // RGB Blue Color
    _VoiceCommandRule(
      // Token to illuminate RGB LED in solid Blue.
      token: 'RGB_BLUE',
      // Friendly description of RGB Blue.
      description: 'RGB LED: Blue Mood Lighting',
      // Category identifier.
      category: 'RGB',
      // Spoken English and Franco-Arabic phrases for Blue.
      englishPhrases: [
        'turn on the blue light',
        'turn on blue light',
        'blue light',
        'blue color',
        'change to blue',
        'make it blue',
        'set blue',
        'blue led',
        // Franco-Arabic variants:
        'noor azraq',
        'noor azra2',
        'noor azrak',
        'lawn azraq',
        'shaghal el azraq',
        'eftah el azraq',
        'iftah el azraq',
      ],
      // Spoken Egyptian Arabic phrases for Blue (normalized).
      arabicPhrases: [
        'شغل النور الازرق',
        'افتح النور الازرق',
        'نور ازرق',
        'لون ازرق',
        'خليه ازرق',
        'شغل الازرق',
        'ليد ازرق',
        'اضاءه زرقا',
      ],
    ),
    // RGB White Color
    _VoiceCommandRule(
      // Token to illuminate RGB LED in solid White.
      token: 'RGB_WHITE',
      // Friendly description of RGB White.
      description: 'RGB LED: White Ambient Lighting',
      // Category identifier.
      category: 'RGB',
      // Spoken English and Franco-Arabic phrases for White.
      englishPhrases: [
        'turn on the white light',
        'turn on white light',
        'white light',
        'white color',
        'change to white',
        'make it white',
        'set white',
        'white led',
        // Franco-Arabic variants:
        'noor abyad',
        'lawn abyad',
        'shaghal el abyad',
        'eftah el abyad',
        'iftah el abyad',
      ],
      // Spoken Egyptian Arabic phrases for White (normalized).
      arabicPhrases: [
        'شغل النور الابيض',
        'افتح النور الابيض',
        'نور ابيض',
        'لون ابيض',
        'خليه ابيض',
        'شغل الابيض',
        'ليد ابيض',
        'اضاءه بيضا',
      ],
    ),
    // RGB Party Mode / Color Cycle
    _VoiceCommandRule(
      // Token to activate continuous dynamic color rainbow cycling.
      token: 'RGB_CYCLE',
      // Friendly description of RGB Party Mode.
      description: 'RGB LED: Party Mode (Dynamic Rainbow Cycle)',
      // Category identifier.
      category: 'RGB',
      // Spoken English and Franco-Arabic phrases for Party Mode.
      englishPhrases: [
        'party mode',
        'color cycle',
        'rainbow mode',
        'party lights',
        'cycle colors',
        'disco mode',
        // Franco-Arabic variants:
        'mode el hafleh',
        'shaghal el hafleh',
        'alwan motaghayerah',
        'alwan motaghaira',
        'shaghal el disco',
      ],
      // Spoken Egyptian Arabic phrases for Party Mode (corrected and normalized).
      arabicPhrases: [
        'وضع الحفله',
        'الوان متغيره',
        'الوان متغيرة',
        'الوان الطيف',
        'مود الحفله',
        'شغل الحفله',
        'الوان متحركه',
        'شغل الديسكو',
      ],
    ),
    // RGB Turn Off
    _VoiceCommandRule(
      // Token to extinguish RGB LED.
      token: 'RGB_OFF',
      // Friendly description of RGB OFF.
      description: 'RGB LED: Turn Off Mood Lighting',
      // Category identifier.
      category: 'RGB',
      // Spoken English and Franco-Arabic phrases for turning off RGB.
      englishPhrases: [
        'turn off rgb',
        'rgb off',
        'turn off mood light',
        'turn off led',
        'turn off colors',
        // Franco-Arabic variants:
        'itfi el led',
        'etfi el led',
        'eqfel el led',
        'e2fel el led',
        'itfi el alwan',
        'etfi el alwan',
        'eqfel el alwan',
        'itfi enoor el melawen',
        'etfi enoor el melawen',
        'itfi el noor el melawen',
        'etfi el noor el melawen',
      ],
      // Spoken Egyptian Arabic phrases for turning off RGB (normalized).
      arabicPhrases: [
        'اطفي النور الملون',
        'اقفل النور الملون',
        'طفي النور الملون',
        'اطفي الالوان',
        'اقفل الالوان',
        'اطفي الليد',
        'اقفل الليد',
        'طفي الليد',
      ],
    ),

    // -------------------------------------------------------------
    // PRIORITY 3 - SECTION A: RELAY APPLIANCES (Light, Fan, Plug/TV)
    // Evaluated third so specific RGB and master commands are processed beforehand.
    // -------------------------------------------------------------
    // Relay 1: Light (Pin D7) - ON
    _VoiceCommandRule(
      // Token to energize Relay 1.
      token: 'R1_ON',
      // Description of Relay 1 ON state.
      description: 'Relay 1 ON: Living Room Light (Pin D7)',
      // Category identifier.
      category: 'Relay',
      // Spoken English and Franco-Arabic phrases for turning on the light.
      englishPhrases: [
        // English:
        'turn on the light',
        'turn on light',
        'light on',
        'lights on',
        'turn light on',
        'switch on light',
        'turn on room light',
        // Franco-Arabic (Arabizi) - Exact phrases reported by user:
        'iftah enoor',
        'iftah el noor',
        'iftah elnoor',
        'eftah enoor',
        'eftah el noor',
        'eftah elnoor',
        'shaghal enoor',
        'shaghal el noor',
        'shaghal elnoor',
        'sha8al enoor',
        'sha8al el noor',
        'walla3 enoor',
        'walla3 el noor',
        'wala3 el noor',
        'shaghal noor el oda',
        'iftah noor el oda',
        'eftah noor el oda',
        'noor on',
        'el noor on',
        'enoor on',
      ],
      // Spoken Egyptian Arabic phrases for turning on the light (normalized).
      arabicPhrases: [
        'شغل نور الاوضه',
        'نور الاوضه',
        'شغل الاضاءه',
        'افتح الاضاءه',
        'شغل النور',
        'افتح النور',
        'ولع النور',
        'نور اون',
        'شغل اللمبه',
        'افتح اللمبه',
      ],
    ),
    // Relay 1: Light (Pin D7) - OFF
    _VoiceCommandRule(
      // Token to de-energize Relay 1.
      token: 'R1_OFF',
      // Description of Relay 1 OFF state.
      description: 'Relay 1 OFF: Living Room Light (Pin D7)',
      // Category identifier.
      category: 'Relay',
      // Spoken English and Franco-Arabic phrases for turning off the light.
      englishPhrases: [
        // English:
        'turn off the light',
        'turn off light',
        'light off',
        'lights off',
        'turn light off',
        'switch off light',
        'turn off room light',
        // Franco-Arabic (Arabizi):
        'itfi enoor',
        'itfi el noor',
        'itfi elnoor',
        'etfi enoor',
        'etfi el noor',
        'etfi elnoor',
        'eqfel enoor',
        'eqfel el noor',
        'eqfel elnoor',
        'ekfel enoor',
        'ekfel el noor',
        'e2fel enoor',
        'e2fel el noor',
        'itfi noor el oda',
        'etfi noor el oda',
        'eqfel noor el oda',
        'noor off',
        'el noor off',
        'enoor off',
      ],
      // Spoken Egyptian Arabic phrases for turning off the light (normalized).
      arabicPhrases: [
        'اطفي نور الاوضه',
        'اقفل نور الاوضه',
        'اطفي النور',
        'اقفل النور',
        'طفي النور',
        'نور اوف',
        'اطفي الاضاءه',
        'اقفل الاضاءه',
        'اطفي اللمبه',
        'اقفل اللمبه',
      ],
    ),

    // Relay 2: Fan (Pin D8) - ON
    _VoiceCommandRule(
      // Token to energize Relay 2.
      token: 'R2_ON',
      // Description of Relay 2 ON state.
      description: 'Relay 2 ON: Cooling Fan (Pin D8)',
      // Category identifier.
      category: 'Relay',
      // Spoken English and Franco-Arabic phrases for turning on the fan.
      englishPhrases: [
        'turn on the fan',
        'turn on fan',
        'fan on',
        'turn fan on',
        'start fan',
        'switch on fan',
        // Franco-Arabic (Arabizi):
        'shaghal el marwaha',
        'shaghal elmarwaha',
        'sha8al el marwaha',
        'eftah el marwaha',
        'iftah el marwaha',
        'iftah elmarwaha',
        'shaghal el fan',
        'marwaha on',
        'el marwaha on',
      ],
      // Spoken Egyptian Arabic phrases for turning on the fan (normalized).
      arabicPhrases: [
        'شغل المروحه',
        'افتح المروحه',
        'ولع المروحه',
        'شغل الفان',
        'مروحه اون',
      ],
    ),
    // Relay 2: Fan (Pin D8) - OFF
    _VoiceCommandRule(
      // Token to de-energize Relay 2.
      token: 'R2_OFF',
      // Description of Relay 2 OFF state.
      description: 'Relay 2 OFF: Cooling Fan (Pin D8)',
      // Category identifier.
      category: 'Relay',
      // Spoken English and Franco-Arabic phrases for turning off the fan.
      englishPhrases: [
        'turn off the fan',
        'turn off fan',
        'fan off',
        'turn fan off',
        'stop fan',
        'switch off fan',
        // Franco-Arabic (Arabizi):
        'itfi el marwaha',
        'etfi el marwaha',
        'itfi elmarwaha',
        'etfi elmarwaha',
        'eqfel el marwaha',
        'ekfel el marwaha',
        'e2fel el marwaha',
        'waghaf el marwaha',
        'marwaha off',
        'el marwaha off',
      ],
      // Spoken Egyptian Arabic phrases for turning off the fan (normalized).
      arabicPhrases: [
        'اطفي المروحه',
        'اقفل المروحه',
        'طفي المروحه',
        'وقف المروحه',
        'مروحه اوف',
      ],
    ),

    // Relay 3: Plug / TV (Pin D9) - ON
    _VoiceCommandRule(
      // Token to energize Relay 3.
      token: 'R3_ON',
      // Description of Relay 3 ON state.
      description: 'Relay 3 ON: Smart Plug / TV (Pin D9)',
      // Category identifier.
      category: 'Relay',
      // Spoken English and Franco-Arabic phrases for turning on the TV/plug.
      englishPhrases: [
        'turn on the tv',
        'turn on tv',
        'tv on',
        'turn tv on',
        'plug on',
        'turn on plug',
        'turn on the plug',
        'switch on tv',
        'turn on socket',
        // Franco-Arabic (Arabizi):
        'shaghal el tv',
        'eftah el tv',
        'iftah el tv',
        'sha8al el tv',
        'shaghal el television',
        'eftah el television',
        'iftah el television',
        'shaghal el fesha',
        'eftah el fesha',
        'iftah el fesha',
        'shaghal el shasha',
        'eftah el shasha',
        'iftah el shasha',
      ],
      // Spoken Egyptian Arabic phrases for turning on the TV/plug (normalized).
      arabicPhrases: [
        'شغل التلفزيون',
        'افتح التلفزيون',
        'شغل التليفزيون',
        'افتح التليفزيون',
        'شغل الفيشه',
        'افتح الفيشه',
        'شغل الشاشه',
        'افتح الشاشه',
        'ولع التلفزيون',
      ],
    ),
    // Relay 3: Plug / TV (Pin D9) - OFF
    _VoiceCommandRule(
      // Token to de-energize Relay 3.
      token: 'R3_OFF',
      // Description of Relay 3 OFF state.
      description: 'Relay 3 OFF: Smart Plug / TV (Pin D9)',
      // Category identifier.
      category: 'Relay',
      // Spoken English and Franco-Arabic phrases for turning off the TV/plug.
      englishPhrases: [
        'turn off the tv',
        'turn off tv',
        'tv off',
        'turn tv off',
        'plug off',
        'turn off plug',
        'turn off the plug',
        'switch off tv',
        'turn off socket',
        // Franco-Arabic (Arabizi):
        'itfi el tv',
        'etfi el tv',
        'eqfel el tv',
        'e2fel el tv',
        'ekfel el tv',
        'itfi el television',
        'etfi el television',
        'eqfel el television',
        'itfi el fesha',
        'etfi el fesha',
        'eqfel el fesha',
        'itfi el shasha',
        'etfi el shasha',
        'eqfel el shasha',
      ],
      // Spoken Egyptian Arabic phrases for turning off the TV/plug (normalized).
      arabicPhrases: [
        'اطفي التلفزيون',
        'اقفل التلفزيون',
        'اطفي التليفزيون',
        'اقفل التليفزيون',
        'اطفي الفيشه',
        'اقفل الفيشه',
        'اطفي الشاشه',
        'اقفل الشاشه',
        'طفي التلفزيون',
      ],
    ),
  ];

  // Normalizes Arabic text by unifying alefs, tah marbuta, and removing tashkeel / diacritics.
  static String normalizeArabic(String text) {
    // Stores intermediate processed string.
    var normalized = text;

    // Normalizes various forms of Alef (أ, إ, آ, ٱ) into a simple bare Alef (ا).
    normalized = normalized.replaceAll(RegExp(r'[أإآٱ]'), 'ا');

    // Normalizes Teh Marbuta (ة) into Heh (ه) to handle dialect phonetic variations.
    normalized = normalized.replaceAll(RegExp(r'ة'), 'ه');

    // Normalizes Alef Maksura (ى) into Yeh (ي).
    normalized = normalized.replaceAll(RegExp(r'ى'), 'ي');

    // Removes Arabic diacritics and Tashkeel marks (Fatha, Damma, Kasra, Sukun, Tanween, Shadda).
    normalized = normalized.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');

    // Removes Tatweel / Kashida elongation character (ـ).
    normalized = normalized.replaceAll(RegExp(r'\u0640'), '');

    // Normalizes punctuation and multiple consecutive whitespace characters into a single space.
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Returns the clean normalized Arabic string.
    return normalized;
  }

  // Pre-processes input transcript by converting English to lowercase and normalizing Arabic.
  static String preprocessTranscript(String transcript) {
    // Converts text to lowercase for case-insensitive English matching.
    var processed = transcript.toLowerCase();
    // Normalizes any Arabic characters contained in the utterance.
    processed = normalizeArabic(processed);
    // Returns the sanitized transcript.
    return processed;
  }

  // Parses spoken transcript instantaneously into a matching CommandResult, or null if no command recognized.
  static CommandResult? parse(String rawTranscript) {
    // Ignores empty or whitespace-only inputs.
    if (rawTranscript.trim().isEmpty) return null;

    // Sanitizes and normalizes the input transcript string.
    final sanitizedInput = preprocessTranscript(rawTranscript);

    // Iterates through all defined voice command rules in priority sequence:
    // Section C (Master Controls) -> Section B (RGB LED) -> Section A (Relay Appliances).
    for (final rule in _rules) {
      // 1. Checks matching against English & Franco-Arabic command trigger phrases.
      for (final englishPhrase in rule.englishPhrases) {
        final target = englishPhrase.toLowerCase().trim();
        if (sanitizedInput.contains(target)) {
          return CommandResult(
            token: rule.token,
            matchedPhrase: englishPhrase,
            description: rule.description,
            category: rule.category,
          );
        }
      }

      // 2. Checks matching against Egyptian Arabic command trigger phrases.
      for (final arabicPhrase in rule.arabicPhrases) {
        final target = normalizeArabic(arabicPhrase);
        if (sanitizedInput.contains(target)) {
          return CommandResult(
            token: rule.token,
            matchedPhrase: arabicPhrase,
            description: rule.description,
            category: rule.category,
          );
        }
      }
    }

    // Returns null if no defined rule matched the spoken transcript.
    return null;
  }
}
