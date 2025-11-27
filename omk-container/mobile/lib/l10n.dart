import 'package:flutter/material.dart';

class Strings {
  Strings(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('pcm'),
    Locale('fr'),
    Locale('zh'),
  ];

  static Strings of(BuildContext context) {
    return Localizations.of<Strings>(context, Strings) ?? Strings(const Locale('en'));
  }

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'app_title': 'OMK Container',
      'bubble_label': 'Open OMK assistant',
      'mini_chat_title': 'Hive Assistant',
      'input_hint': 'Type a note or question',
      'quick_analyze': 'Analyze page',
      'quick_summarize': 'Summarize',
      'quick_report': 'Report phishing',
      'quick_guard_me': 'Guard me',
      'settings_title': 'Settings',
      'toggle_floating': 'Floating assistant',
      'privacy_section': 'Privacy controls',
      'history_purge': 'Purge history',
      'ttl_label': 'Security memory TTL (minutes)',
      'model_selection': 'Preferred model',
      'permissions_title': 'Permissions & Safety',
      'onboarding_mission_title': 'Carry your persona',
      'onboarding_mission_body': 'OMK Container carries your AI persona across devices with explicit consent.',
      'onboarding_privacy_title': 'Privacy first',
      'onboarding_privacy_body': 'Your memories stay encrypted on-device by default. You choose what to share.',
      'onboarding_quick_title': 'Quick setup',
      'onboarding_quick_body': 'Enable the floating assistant and review permissions at your own pace.',
      'onboarding_skip': 'Skip for now',
      'onboarding_next': 'Next',
      'onboarding_start': 'Get started',
      'perm_overlay_title': 'Floating bubble (overlay)',
      'perm_overlay_reason': 'Allows OMK to show a small assistant bubble above other apps so you can get help without switching screens.',
      'perm_vpn_title': 'Local inspection (VPN)',
      'perm_vpn_reason': 'Used only for on-device traffic inspection and safety analysis. Traffic is not tunneled to third-party servers.',
      'perm_access_title': 'Accessibility',
      'perm_access_reason': 'Lets OMK detect text in focused fields to offer contextual suggestions.',
      'perm_screenshot_title': 'Screenshots',
      'perm_screenshot_reason': 'Optional. Allows OMK to attach low-resolution snapshots to safety/abuse reports.',
      'perm_mic_title': 'Microphone',
      'perm_mic_reason': 'Enables voice input and journaling. Audio is processed according to your privacy settings.',
      'why_data_title': 'Why we ask for this',
      'why_data_legal': 'We request this permission only to provide the described feature. Data is processed under the OMK Container privacy policy and is never sold.',
    },
    'pcm': {
      // Nigerian Pidgin placeholders (keys only for now)
    },
    'fr': {
      // French placeholders
    },
    'zh': {
      // Chinese placeholders
    },
  };

  String _t(String key) {
    final lang = _values[locale.languageCode] ?? _values['en']!;
    return lang[key] ?? _values['en']![key] ?? key;
  }

  String get appTitle => _t('app_title');
  String get bubbleLabel => _t('bubble_label');
  String get miniChatTitle => _t('mini_chat_title');
  String get inputHint => _t('input_hint');
  String get quickAnalyze => _t('quick_analyze');
  String get quickSummarize => _t('quick_summarize');
  String get quickReport => _t('quick_report');
  String get quickGuardMe => _t('quick_guard_me');
  String get settingsTitle => _t('settings_title');
  String get toggleFloating => _t('toggle_floating');
  String get privacySection => _t('privacy_section');
  String get historyPurge => _t('history_purge');
  String get ttlLabel => _t('ttl_label');
  String get modelSelection => _t('model_selection');
  String get permissionsTitle => _t('permissions_title');
  String get onboardingMissionTitle => _t('onboarding_mission_title');
  String get onboardingMissionBody => _t('onboarding_mission_body');
  String get onboardingPrivacyTitle => _t('onboarding_privacy_title');
  String get onboardingPrivacyBody => _t('onboarding_privacy_body');
  String get onboardingQuickTitle => _t('onboarding_quick_title');
  String get onboardingQuickBody => _t('onboarding_quick_body');
  String get onboardingSkip => _t('onboarding_skip');
  String get onboardingNext => _t('onboarding_next');
  String get onboardingStart => _t('onboarding_start');
  String get permOverlayTitle => _t('perm_overlay_title');
  String get permOverlayReason => _t('perm_overlay_reason');
  String get permVpnTitle => _t('perm_vpn_title');
  String get permVpnReason => _t('perm_vpn_reason');
  String get permAccessTitle => _t('perm_access_title');
  String get permAccessReason => _t('perm_access_reason');
  String get permScreenshotTitle => _t('perm_screenshot_title');
  String get permScreenshotReason => _t('perm_screenshot_reason');
  String get permMicTitle => _t('perm_mic_title');
  String get permMicReason => _t('perm_mic_reason');
  String get whyDataTitle => _t('why_data_title');
  String get whyDataLegal => _t('why_data_legal');
}

class StringsDelegate extends LocalizationsDelegate<Strings> {
  const StringsDelegate();

  @override
  bool isSupported(Locale locale) {
    return Strings.supportedLocales
        .map((e) => e.languageCode)
        .contains(locale.languageCode);
  }

  @override
  Future<Strings> load(Locale locale) async {
    return Strings(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<Strings> old) => false;
}
