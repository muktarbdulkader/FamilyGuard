import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kLocalePreferenceKey = 'app_locale_preference';
const String _kLegacyLocaleKey = 'app_language';

/// Model representing a supported language in FamilyGuard
class AppLanguage {
  final String code;
  final String englishName;
  final String nativeName;
  final String flag;
  final bool isRtl;

  const AppLanguage({
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.flag,
    this.isRtl = false,
  });

  Locale get locale => Locale(code);
}

/// Central registry of supported languages in FamilyGuard.
/// Structured so new languages can be added easily in a single place.
class AppLanguages {
  static const List<AppLanguage> supported = [
    AppLanguage(
      code: 'en',
      englishName: 'English',
      nativeName: 'English',
      flag: '🇬🇧',
      isRtl: false,
    ),
    AppLanguage(
      code: 'om',
      englishName: 'Afaan Oromo',
      nativeName: 'Afaan Oromoo',
      flag: '🌳',
      isRtl: false,
    ),
    AppLanguage(
      code: 'am',
      englishName: 'Amharic',
      nativeName: 'አማርኛ',
      flag: '🇪🇹',
      isRtl: false,
    ),
    AppLanguage(
      code: 'ar',
      englishName: 'Arabic',
      nativeName: 'العربية',
      flag: '🇸🇦',
      isRtl: true,
    ),
  ];

  static AppLanguage fromCode(String code) {
    return supported.firstWhere(
      (lang) => lang.code == code,
      orElse: () => supported.first,
    );
  }
}

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code =
          prefs.getString(_kLocalePreferenceKey) ??
          prefs.getString(_kLegacyLocaleKey);
      if (code != null &&
          AppLanguages.supported.any((lang) => lang.code == code)) {
        state = Locale(code);
      }
    } catch (e) {
      debugPrint('Locale preference load error: $e');
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocalePreferenceKey, locale.languageCode);
      await prefs.setString(_kLegacyLocaleKey, locale.languageCode);
    } catch (e) {
      debugPrint('Locale preference save error: $e');
    }

    String? userId;
    if (Firebase.apps.isNotEmpty) {
      try {
        userId = FirebaseAuth.instance.currentUser?.uid;
      } on FirebaseException catch (error) {
        debugPrint('Preferred locale auth lookup error: $error');
      }
    }
    if (userId != null) {
      unawaited(_savePreferredLocale(userId, locale.languageCode));
    }
  }

  Future<void> _savePreferredLocale(String userId, String languageCode) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'preferredLocale': languageCode,
      });
    } catch (e) {
      debugPrint('Preferred locale sync error: $e');
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

/// Provider returning the active AppLanguage configuration
final currentLanguageProvider = Provider<AppLanguage>((ref) {
  final currentLocale = ref.watch(localeProvider);
  return AppLanguages.fromCode(currentLocale.languageCode);
});
