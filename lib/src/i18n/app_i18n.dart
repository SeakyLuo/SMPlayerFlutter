import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const smPlayerFallbackLocale = 'en-US';
const smPlayerSupportedLocaleNames = {
  'en-US',
  'zh-CN',
  'zh-Hant',
  'fr',
  'ru',
  'ja',
  'de',
  'pt-BR',
  'es',
  'it',
  'nl',
  'cs',
  'uk',
  'sv',
  'id',
};

final smPlayerSupportedLocales =
    smPlayerSupportedLocaleNames.map(smPlayerLocaleFromName).toList();

final smPlayerI18nProvider = FutureProvider<SmPlayerI18n>((ref) async {
  final platformLocale = PlatformDispatcher.instance.locale;
  final locale = resolveSmPlayerLocale(platformLocale);
  final fallbackMessages = await _loadLocaleMessages(smPlayerFallbackLocale);
  if (locale == smPlayerFallbackLocale) {
    return SmPlayerI18n(locale: locale, messages: fallbackMessages);
  }

  final localeMessages = await _loadLocaleMessages(locale);
  return SmPlayerI18n(
    locale: locale,
    messages: {...fallbackMessages, ...localeMessages},
  );
});

class SmPlayerI18n {
  const SmPlayerI18n({required this.locale, required this.messages});

  final String locale;
  final Map<String, String> messages;

  String t(String key, [Map<String, Object> values = const {}]) {
    final template = messages[key] ?? key;
    return values.entries.fold(
      template,
      (text, entry) => text.replaceAll('{${entry.key}}', '${entry.value}'),
    );
  }
}

class SmPlayerI18nScope extends InheritedWidget {
  const SmPlayerI18nScope({
    super.key,
    required this.i18n,
    required super.child,
  });

  final SmPlayerI18n i18n;

  static SmPlayerI18n of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<SmPlayerI18nScope>();
    return scope!.i18n;
  }

  static SmPlayerI18n? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SmPlayerI18nScope>()
        ?.i18n;
  }

  @override
  bool updateShouldNotify(SmPlayerI18nScope oldWidget) {
    return oldWidget.i18n != i18n;
  }
}

extension SmPlayerI18nBuildContext on BuildContext {
  SmPlayerI18n get smPlayerI18n => SmPlayerI18nScope.of(this);
  SmPlayerI18n? get maybeSmPlayerI18n => SmPlayerI18nScope.maybeOf(this);
}

String resolveSmPlayerLocale(Locale locale) {
  final normalized = _normalizeLocale(locale);
  if (smPlayerSupportedLocaleNames.contains(normalized)) {
    return normalized;
  }

  final languageCode = locale.languageCode.toLowerCase();
  if (languageCode == 'zh') {
    return 'zh-CN';
  }

  return smPlayerSupportedLocaleNames.contains(languageCode)
      ? languageCode
      : smPlayerFallbackLocale;
}

Locale smPlayerLocaleFromName(String locale) {
  final parts = locale.split('-');
  return switch (parts.length) {
    1 => Locale(parts[0]),
    2 => Locale(parts[0], parts[1]),
    _ => Locale(parts[0]),
  };
}

String _normalizeLocale(Locale locale) {
  final languageCode = locale.languageCode.toLowerCase();
  final countryCode = locale.countryCode;
  final scriptCode = locale.scriptCode;

  if (languageCode == 'zh' &&
      (scriptCode == 'Hant' || countryCode == 'TW' || countryCode == 'HK')) {
    return 'zh-Hant';
  }

  if (languageCode == 'pt' && countryCode == 'BR') {
    return 'pt-BR';
  }

  if (countryCode == null || countryCode.isEmpty) {
    return languageCode;
  }

  return '$languageCode-$countryCode';
}

Future<Map<String, String>> _loadLocaleMessages(String locale) async {
  final raw = await rootBundle.loadString('locales/$locale.json');
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return decoded.map((key, value) => MapEntry(key, value as String));
}
