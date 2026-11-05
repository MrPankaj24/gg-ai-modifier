/// Documentation.
///
/// Documentation.

import '../models/chat_message.dart';

/// Documentation.
enum AiReadDepth {
  sample20(20, 'first  20  '),
  sample30(30, 'first  30  '),
  sample50(50, 'first  50  '),
  sample100(100, 'first  100  '),
  full(-1, 'all results ');

  final int value;
  final String label;
  const AiReadDepth(this.value, this.label);
}

/// Documentation.
class PromptBuilder {
  /// current  AI Read Depth
  AiReadDepth _readDepth = AiReadDepth.sample50;
  String _modelName = '';

  /// Settings AI Read Depth
  void setReadDepth(AiReadDepth depth) {
    _readDepth = depth;
  }

  /// Settingscurrent Model name
  void setModelName(String name) {
    _modelName = name;
  }

  /// Documentation.
  AiReadDepth get readDepth => _readDepth;

  /// Documentation.
  static String buildSystemPrompt(String modelName) {
    final modelInfo = _getModelInfo(modelName);
    return '''
You are GG-AI, a game-memory modification assistant. The underlying model is: $modelInfo.
When asked which model you are, answer exactly "$modelInfo". GG-AI is the application name, not the model name.

Capabilities:
1. Guide users through exact, fuzzy, range, and AOB searches.
2. Analyze results and identify likely target addresses.
3. Generate Lua scripts when explicitly requested.
4. Explain memory-editing concepts clearly and safely.

Never bypass online verification or modify server-side data. Remind users that memory editing may violate game terms, and limit guidance to single-player games and research.
Use the available tools for real operations; never invent search results or addresses. When results are numerous, use the provided samples and statistics to guide another value-change search.
The client supports Markdown, syntax highlighting, LaTeX, and Mermaid diagrams. Use Mermaid code blocks for diagrams.
Reply in concise, friendly English with numbered steps. Mark results with ✅ or ❌ and format addresses and values as code.
''';
  }

  static String _getModelInfo(String modelName) {
    final m = modelName.toLowerCase();
    if (m.contains('deepseek-reasoner') || m.contains('deepseek-r1')) return 'DeepSeek-R1 (DeepSeek,reasoningmodel)';
    if (m.contains('deepseek')) return 'DeepSeek-V3 (DeepSeek,general-purpose chatmodel)';
    if (m.contains('mimo')) return 'MiMo-v2.5-Pro (Xiaomi,language model)';
    if (m.contains('gpt-4o')) return 'GPT-4o (OpenAI ,multimodalmodel)';
    if (m.contains('gpt-4')) return 'GPT-4 (OpenAI ,language model)';
    if (m.contains('gpt-3.5')) return 'GPT-3.5-Turbo (OpenAI ,language model)';
    if (m.contains('claude')) return 'Claude (Anthropic ,language model)';
    if (m.contains('qwen') || m.contains('tongyi')) return 'Qwen (Alibaba,language model)';
    if (m.contains('glm') || m.contains('chatglm')) return 'ChatGLM (Zhipu AI,language model)';
    return modelName;
  }

  /// Documentation.
  List<Map<String, dynamic>> buildMessages({
    required String userMessage,
    List<ChatMessage> history = const [],
  }) {
    final messages = <Map<String, dynamic>>[];

    // SystemNotice
    messages.add({'role': 'system', 'content': buildSystemPrompt(_modelName)});

    // Implementation detail.
    final recentHistory = history.length > 20
        ? history.sublist(history.length - 20)
        : history;

    for (final msg in recentHistory) {
      if (msg.isSystem) continue;

      messages.add({'role': msg.role.value, 'content': msg.content});
    }

    // Implementation detail.
    messages.add({'role': 'user', 'content': userMessage});

    return messages;
  }

  /// Documentation.
  List<Map<String, dynamic>> buildFunctionResultMessages({
    required String funcName,
    required Map<String, dynamic> arguments,
    required dynamic result,
    required List<ChatMessage> history,
  }) {
    final messages = <Map<String, dynamic>>[];

    // SystemNotice
    messages.add({'role': 'system', 'content': buildSystemPrompt(_modelName)});

    // Implementation detail.
    final recentHistory = history.length > 20
        ? history.sublist(history.length - 20)
        : history;

    for (final msg in recentHistory) {
      if (msg.isSystem) continue;

      messages.add({'role': msg.role.value, 'content': msg.content});
    }

    // Implementation detail.
    messages.add({
      'role': 'assistant',
      'content': null,
      'function_call': {'name': funcName, 'arguments': arguments},
    });

    // Implementation detail.
    messages.add({'role': 'tool', 'content': result.toString()});

    return messages;
  }
}
