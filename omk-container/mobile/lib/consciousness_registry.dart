import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum ConsciousnessProviderId {
  openai,
  gemini,
  claude,
  grok,
  deepseek,
  local,
}

class ConsciousnessProviderConfig {
  ConsciousnessProviderConfig({
    this.apiKey,
    this.baseUrl,
    this.preferredModel,
    this.useWebSession = false,
  });

  String? apiKey;
  String? baseUrl;
  String? preferredModel;
  bool useWebSession;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'preferredModel': preferredModel,
      'useWebSession': useWebSession,
    };
  }

  factory ConsciousnessProviderConfig.fromJson(Map<String, dynamic> json) {
    return ConsciousnessProviderConfig(
      apiKey: json['apiKey'] as String?,
      baseUrl: json['baseUrl'] as String?,
      preferredModel: json['preferredModel'] as String?,
      useWebSession: (json['useWebSession'] as bool?) ?? false,
    );
  }
}

class PersonaProfile {
  PersonaProfile({
    required this.name,
    required this.formality,
    required this.concision,
    required this.keywords,
    required this.bio,
    required this.rules,
  });

  String name;
  int formality;
  int concision;
  String keywords;
  String bio;
  String rules;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'formality': formality,
      'concision': concision,
      'keywords': keywords,
      'bio': bio,
      'rules': rules,
    };
  }

  factory PersonaProfile.fromJson(Map<String, dynamic> json) {
    return PersonaProfile(
      name: (json['name'] as String?) ?? 'My Hive',
      formality: (json['formality'] as int?) ?? 50,
      concision: (json['concision'] as int?) ?? 50,
      keywords: (json['keywords'] as String?) ?? '',
      bio: (json['bio'] as String?) ?? '',
      rules: (json['rules'] as String?) ?? '',
    );
  }
}

class UserProfile {
  UserProfile({
    required this.personality,
    required this.allergies,
    required this.preferences,
    required this.location,
    required this.interests,
    required this.education,
    required this.socials,
    this.displayName = '',
    this.ageBand = '',
    this.email = '',
    this.phone = '',
  });

  String personality;
  String allergies;
  String preferences;
  String location;
  String interests;
  String education;
  String socials;
  String displayName;
  String ageBand;
  String email;
  String phone;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'personality': personality,
      'allergies': allergies,
      'preferences': preferences,
      'location': location,
      'interests': interests,
      'education': education,
      'socials': socials,
      'displayName': displayName,
      'ageBand': ageBand,
      'email': email,
      'phone': phone,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      personality: (json['personality'] as String?) ?? '',
      allergies: (json['allergies'] as String?) ?? '',
      preferences: (json['preferences'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      interests: (json['interests'] as String?) ?? '',
      education: (json['education'] as String?) ?? '',
      socials: (json['socials'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? '',
      ageBand: (json['ageBand'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
    );
  }
}

class ConsciousnessRegistry {
  ConsciousnessRegistry({
    required this.active,
    required this.providers,
    this.persona,
    this.userProfile,
  });

  ConsciousnessProviderId active;
  Map<ConsciousnessProviderId, ConsciousnessProviderConfig> providers;
  PersonaProfile? persona;
  UserProfile? userProfile;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'active': active.name,
      'providers': providers.map((key, value) => MapEntry(key.name, value.toJson())),
      'persona': persona?.toJson(),
      'userProfile': userProfile?.toJson(),
    };
  }

  factory ConsciousnessRegistry.fromJson(Map<String, dynamic> json) {
    final rawProviders = (json['providers'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final mapped = <ConsciousnessProviderId, ConsciousnessProviderConfig>{};
    for (final entry in rawProviders.entries) {
      final id = ConsciousnessProviderId.values.firstWhere(
        (e) => e.name == entry.key,
        orElse: () => ConsciousnessProviderId.gemini,
      );
      final cfgJson = entry.value;
      if (cfgJson is Map<String, dynamic>) {
        mapped[id] = ConsciousnessProviderConfig.fromJson(cfgJson);
      }
    }
    ConsciousnessProviderId activeId;
    final rawActive = json['active'] as String?;
    if (rawActive != null) {
      activeId = ConsciousnessProviderId.values.firstWhere(
        (e) => e.name == rawActive,
        orElse: () => ConsciousnessProviderId.gemini,
      );
    } else {
      activeId = ConsciousnessProviderId.gemini;
    }
    return ConsciousnessRegistry(
      active: activeId,
      providers: mapped,
      persona: json['persona'] is Map<String, dynamic>
          ? PersonaProfile.fromJson(json['persona'] as Map<String, dynamic>)
          : null,
      userProfile: json['userProfile'] is Map<String, dynamic>
          ? UserProfile.fromJson(json['userProfile'] as Map<String, dynamic>)
          : null,
    );
  }

  ConsciousnessProviderConfig configFor(ConsciousnessProviderId id) {
    return providers[id] ??= ConsciousnessProviderConfig();
  }
}

class ConsciousnessRegistryStore {
  static const String _key = 'omk_consciousness_registry_v1';

  static Future<ConsciousnessRegistry> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return _defaultRegistry();
    }
    try {
      final jsonMap = jsonDecode(raw);
      if (jsonMap is Map<String, dynamic>) {
        return ConsciousnessRegistry.fromJson(jsonMap);
      }
    } catch (_) {}
    return _defaultRegistry();
  }

  static Future<void> save(ConsciousnessRegistry registry) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(registry.toJson());
    await prefs.setString(_key, encoded);
  }

  static ConsciousnessRegistry _defaultRegistry() {
    final providers = <ConsciousnessProviderId, ConsciousnessProviderConfig>{};
    for (final id in ConsciousnessProviderId.values) {
      providers[id] = ConsciousnessProviderConfig();
    }
    return ConsciousnessRegistry(
      active: ConsciousnessProviderId.gemini,
      providers: providers,
      persona: PersonaProfile(
        name: 'My Hive',
        formality: 50,
        concision: 50,
        keywords: '',
        bio: '',
        rules: '',
      ),
      userProfile: UserProfile(
        personality: '',
        allergies: '',
        preferences: '',
        location: '',
        interests: '',
        education: '',
        socials: '',
      ),
    );
  }
}
