import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService with ChangeNotifier {
  // Current language code
  String _currentLanguage = 'en';
  final String _languageKey = 'app_language';

  // Map of translations for each language
  final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'settings': 'Settings',
      'language': 'Language',
      'darkMode': 'Dark Mode',
      'textSize': 'Text Size',
      'languageChanged': 'Language changed',
      'cancel': 'CANCEL',
      'selectLanguage': 'Select Language',
      // Add more translations as needed
    },
    'hi': {
      'settings': 'सेटिंग्स',
      'language': 'भाषा',
      'darkMode': 'डार्क मोड',
      'textSize': 'टेक्स्ट का आकार',
      'languageChanged': 'भाषा बदल गई',
      'cancel': 'रद्द करें',
      'selectLanguage': 'भाषा चुनें',
      // Add more translations as needed
    },
    'bn': {
      'settings': 'সেটিংস',
      'language': 'ভাষা',
      'darkMode': 'ডার্ক মোড',
      'textSize': 'টেক্সট সাইজ',
      'languageChanged': 'ভাষা পরিবর্তন হয়েছে',
      'cancel': 'বাতিল',
      'selectLanguage': 'ভাষা নির্বাচন করুন',
      // Add more translations as needed
    },
    'te': {
      'settings': 'సెట్టింగులు',
      'language': 'భాష',
      'darkMode': 'డార్క్ మోడ్',
      'textSize': 'టెక్స్ట్ పరిమాణం',
      'languageChanged': 'భాష మార్చబడింది',
      'cancel': 'రద్దు చేయండి',
      'selectLanguage': 'భాషను ఎంచుకోండి',
      // Add more translations as needed
    },
    'mr': {
      'settings': 'सेटिंग्ज',
      'language': 'भाषा',
      'darkMode': 'डार्क मोड',
      'textSize': 'अक्षर आकार',
      'languageChanged': 'भाषा बदलली',
      'cancel': 'रद्द करा',
      'selectLanguage': 'भाषा निवडा',
      // Add more translations as needed
    },
  };

  LanguageService() {
    loadSavedLanguage();
  }

  String get currentLanguage => _currentLanguage;

  // Load saved language from SharedPreferences
  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_languageKey) ?? 'en';
    notifyListeners();
  }

  // Change current language
  Future<void> changeLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    notifyListeners();
  }

  // Get translated text for a key
  String translate(String key) {
    if (_localizedValues[_currentLanguage]?.containsKey(key) ?? false) {
      return _localizedValues[_currentLanguage]![key]!;
    }
    // Fallback to English
    return _localizedValues['en']?[key] ?? key;
  }

  // Get language name from language code
  String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिन्दी (Hindi)';
      case 'bn':
        return 'বাংলা (Bengali)';
      case 'te':
        return 'తెలుగు (Telugu)';
      case 'mr':
        return 'मराठी (Marathi)';
      default:
        return 'English';
    }
  }

  // List of supported languages
  List<Map<String, String>> get supportedLanguages => [
    {'code': 'en', 'name': 'English'},
    {'code': 'hi', 'name': 'हिन्दी (Hindi)'},
    {'code': 'bn', 'name': 'বাংলা (Bengali)'},
    {'code': 'te', 'name': 'తెలుగు (Telugu)'},
    {'code': 'mr', 'name': 'मराठी (Marathi)'},
  ];
}