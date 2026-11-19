/// Target languages supported by Gemini Live Translation.
///
/// The API auto-detects the spoken language, so these are the only values the
/// user needs to choose from for `translationConfig.targetLanguageCode`.
class TranslationLanguage {
  const TranslationLanguage({required this.name, required this.code});

  final String name;
  final String code;
}

const String defaultTargetLanguageCode = 'fr';

const List<TranslationLanguage> translationLanguages = <TranslationLanguage>[
  TranslationLanguage(name: 'Afrikaans', code: 'af'),
  TranslationLanguage(name: 'Akan', code: 'ak'),
  TranslationLanguage(name: 'Albanian', code: 'sq'),
  TranslationLanguage(name: 'Amharic', code: 'am'),
  TranslationLanguage(name: 'Arabic', code: 'ar'),
  TranslationLanguage(name: 'Armenian', code: 'hy'),
  TranslationLanguage(name: 'Azerbaijani', code: 'az'),
  TranslationLanguage(name: 'Basque', code: 'eu'),
  TranslationLanguage(name: 'Belarusian', code: 'be'),
  TranslationLanguage(name: 'Bengali', code: 'bn'),
  TranslationLanguage(name: 'Bulgarian', code: 'bg'),
  TranslationLanguage(name: 'Burmese (Myanmar)', code: 'my'),
  TranslationLanguage(name: 'Catalan', code: 'ca'),
  TranslationLanguage(name: 'Chinese (Simplified)', code: 'zh-Hans'),
  TranslationLanguage(name: 'Chinese (Traditional)', code: 'zh-Hant'),
  TranslationLanguage(name: 'Croatian', code: 'hr'),
  TranslationLanguage(name: 'Czech', code: 'cs'),
  TranslationLanguage(name: 'Danish', code: 'da'),
  TranslationLanguage(name: 'Dutch', code: 'nl'),
  TranslationLanguage(name: 'English', code: 'en'),
  TranslationLanguage(name: 'Estonian', code: 'et'),
  TranslationLanguage(name: 'Filipino', code: 'fil'),
  TranslationLanguage(name: 'Finnish', code: 'fi'),
  TranslationLanguage(name: 'French', code: 'fr'),
  TranslationLanguage(name: 'Galician', code: 'gl'),
  TranslationLanguage(name: 'Georgian', code: 'ka'),
  TranslationLanguage(name: 'German', code: 'de'),
  TranslationLanguage(name: 'Greek', code: 'el'),
  TranslationLanguage(name: 'Gujarati', code: 'gu'),
  TranslationLanguage(name: 'Hausa', code: 'ha'),
  TranslationLanguage(name: 'Hebrew', code: 'he'),
  TranslationLanguage(name: 'Hindi', code: 'hi'),
  TranslationLanguage(name: 'Hungarian', code: 'hu'),
  TranslationLanguage(name: 'Icelandic', code: 'is'),
  TranslationLanguage(name: 'Indonesian', code: 'id'),
  TranslationLanguage(name: 'Italian', code: 'it'),
  TranslationLanguage(name: 'Japanese', code: 'ja'),
  TranslationLanguage(name: 'Javanese', code: 'jv'),
  TranslationLanguage(name: 'Kannada', code: 'kn'),
  TranslationLanguage(name: 'Kazakh', code: 'kk'),
  TranslationLanguage(name: 'Khmer', code: 'km'),
  TranslationLanguage(name: 'Kinyarwanda', code: 'rw'),
  TranslationLanguage(name: 'Korean', code: 'ko'),
  TranslationLanguage(name: 'Lao', code: 'lo'),
  TranslationLanguage(name: 'Latvian', code: 'lv'),
  TranslationLanguage(name: 'Lithuanian', code: 'lt'),
  TranslationLanguage(name: 'Macedonian', code: 'mk'),
  TranslationLanguage(name: 'Malay', code: 'ms'),
  TranslationLanguage(name: 'Malayalam', code: 'ml'),
  TranslationLanguage(name: 'Marathi', code: 'mr'),
  TranslationLanguage(name: 'Mongolian', code: 'mn'),
  TranslationLanguage(name: 'Nepali', code: 'ne'),
  TranslationLanguage(name: 'Norwegian (no)', code: 'no'),
  TranslationLanguage(name: 'Norwegian (nb)', code: 'nb'),
  TranslationLanguage(name: 'Persian', code: 'fa'),
  TranslationLanguage(name: 'Polish', code: 'pl'),
  TranslationLanguage(name: 'Portuguese (Brazil)', code: 'pt-BR'),
  TranslationLanguage(name: 'Portuguese (Portugal)', code: 'pt-PT'),
  TranslationLanguage(name: 'Punjabi', code: 'pa'),
  TranslationLanguage(name: 'Romanian', code: 'ro'),
  TranslationLanguage(name: 'Russian', code: 'ru'),
  TranslationLanguage(name: 'Serbian', code: 'sr'),
  TranslationLanguage(name: 'Sindhi', code: 'sd'),
  TranslationLanguage(name: 'Sinhala', code: 'si'),
  TranslationLanguage(name: 'Slovak', code: 'sk'),
  TranslationLanguage(name: 'Slovenian', code: 'sl'),
  TranslationLanguage(name: 'Spanish', code: 'es'),
  TranslationLanguage(name: 'Sundanese', code: 'su'),
  TranslationLanguage(name: 'Swahili', code: 'sw'),
  TranslationLanguage(name: 'Swedish', code: 'sv'),
  TranslationLanguage(name: 'Tamil', code: 'ta'),
  TranslationLanguage(name: 'Telugu', code: 'te'),
  TranslationLanguage(name: 'Thai', code: 'th'),
  TranslationLanguage(name: 'Turkish', code: 'tr'),
  TranslationLanguage(name: 'Ukrainian', code: 'uk'),
  TranslationLanguage(name: 'Urdu', code: 'ur'),
  TranslationLanguage(name: 'Uzbek', code: 'uz'),
  TranslationLanguage(name: 'Vietnamese', code: 'vi'),
  TranslationLanguage(name: 'Zulu', code: 'zu'),
];

bool isSupportedTargetLanguage(String code) {
  return translationLanguages.any((language) => language.code == code);
}

String targetLanguageName(String code) {
  for (final language in translationLanguages) {
    if (language.code == code) return language.name;
  }
  return code;
}
