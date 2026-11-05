/// Documentation.

/// LLM API Configuration
class LlmConfig {
  /// Documentation.
  final String baseUrl;

  /// Documentation.
  final String apiKey;

  /// Model name
  final String model;

  /// Documentation.
  final double temperature;

  /// Documentation.
  final int maxTokens;

  /// Documentation.
  final bool streamEnabled;

  /// Documentation.
  final int timeoutSeconds;

  const LlmConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.temperature = 0.7,
    this.maxTokens = 4096,
    this.streamEnabled = true,
    this.timeoutSeconds = 60,
  });

  LlmConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    double? temperature,
    int? maxTokens,
    bool? streamEnabled,
    int? timeoutSeconds,
  }) {
    return LlmConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      streamEnabled: streamEnabled ?? this.streamEnabled,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    );
  }

  /// Documentation.
  bool get isConfigured => baseUrl.isNotEmpty && apiKey.isNotEmpty;

  /// Documentation.
  bool get isGemini => baseUrl.contains('generativelanguage.googleapis.com');

  /// Documentation.
  String get chatEndpoint => '$baseUrl/chat/completions';

  /// Documentation.
  String get streamEndpoint => '$baseUrl/chat/completions';

  /// Documentation.
  String get effectiveBaseUrl {
    if (isGemini) {
      // Implementation detail.
      final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      return '$base/v1beta/openai';
    }
    return baseUrl;
  }

  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'model': model,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'streamEnabled': streamEnabled,
      'timeoutSeconds': timeoutSeconds,
    };
  }

  factory LlmConfig.fromJson(Map<String, dynamic> json) {
    return LlmConfig(
      baseUrl: json['baseUrl'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? '',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: json['maxTokens'] as int? ?? 4096,
      streamEnabled: json['streamEnabled'] as bool? ?? true,
      timeoutSeconds: json['timeoutSeconds'] as int? ?? 60,
    );
  }

  /// Documentation.
  static const presets = {
    'deepseek': LlmConfig(
      baseUrl: 'https://api.deepseek.com',
      apiKey: '',
      model: 'deepseek-chat',
    ),
    'deepseek-reasoner': LlmConfig(
      baseUrl: 'https://api.deepseek.com',
      apiKey: '',
      model: 'deepseek-reasoner',
    ),
    'xiaomi-mimo': LlmConfig(
      baseUrl: 'https://api.xiaomimimo.com/v1',
      apiKey: '',
      model: 'mimo-v2.5-pro',
    ),
    'openai': LlmConfig(
      baseUrl: 'https://api.openai.com/v1',
      apiKey: '',
      model: 'gpt-4o',
    ),
    'gemini': LlmConfig(
      baseUrl: 'https://generativelanguage.googleapis.com',
      apiKey: '',
      model: 'gemini-1.5-flash',
    ),
  };

  /// Documentation.
  static List<MapEntry<String, LlmConfig>> get presetList {
    return presets.entries.toList();
  }

  @override
  String toString() {
    return 'LlmConfig(model: $model, baseUrl: $baseUrl)';
  }
}
