/// Documentation.
///
/// Documentation.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_config.dart';
import '../models/chat_message.dart';
import 'function_handler.dart';
import 'prompt_builder.dart';

/// Documentation.
class LlmService {
  LlmConfig _config;
  final FunctionHandler _functionHandler;
  final PromptBuilder _promptBuilder;

  http.Client? _httpClient;
  bool _isStreaming = false;

  LlmService({
    required LlmConfig config,
    required FunctionHandler functionHandler,
    required PromptBuilder promptBuilder,
  })  : _config = config,
        _functionHandler = functionHandler,
        _promptBuilder = promptBuilder {
    promptBuilder.setModelName(config.model);
  }

  /// Documentation.
  LlmConfig get config => _config;

  /// Documentation.
  bool get isStreaming => _isStreaming;

  /// Documentation.
  void updateConfig(LlmConfig newConfig) {
    _config = newConfig;
    _promptBuilder.setModelName(newConfig.model);
  }

  /// Documentation.
  String _getEndpoint() {
    // Implementation detail.
    final base = _config.effectiveBaseUrl.trimRight('/');
    return '$base/chat/completions';
  }

  /// Documentation.
  Future<ChatMessage> sendMessage(
    String userMessage, {
    List<ChatMessage> history = const [],
  }) async {
    if (!_config.isConfigured) {
      return ChatMessage.assistant('⚠️ Configure the LLM API in Settings first');
    }

    try {
      final messages = _promptBuilder.buildMessages(
        userMessage: userMessage,
        history: history,
      );

      final response = await _makeRequest(messages, stream: false);

      if (response == null) {
        return ChatMessage.assistant('❌ Request failed; check the network and API configuration');
      }

      final choice = response['choices']?[0];
      if (choice == null) {
        return ChatMessage.assistant('❌ Unexpected response format ');
      }

      final message = choice['message'];
      final content = message['content'] as String? ?? '';

      // Implementation detail.
      if (message['tool_calls'] != null) {
        final toolCalls = message['tool_calls'] as List;
        if (toolCalls.isNotEmpty) {
          final toolCall = toolCalls[0];
          final funcName = toolCall['function']['name'] as String;
          final funcArgs = jsonDecode(toolCall['function']['arguments'] as String);

          // Implementation detail.
          final result = await _functionHandler.executeFunction(funcName, funcArgs);

          // Implementation detail.
          final summary = await _sendFunctionResult(
            funcName: funcName,
            arguments: funcArgs,
            result: result,
            history: history,
            toolCallId: toolCall['id'] as String?,
          );

          return summary;
        }
      }

      return ChatMessage.assistant(content);
    } catch (e) {
      return ChatMessage.assistant('❌ Error occurred: $e');
    }
  }

  /// Documentation.
  Stream<String> sendMessageStream(
    String userMessage, {
    List<ChatMessage> history = const [],
  }) async* {
    if (!_config.isConfigured) {
      yield '⚠️ Configure the LLM API in Settings first';
      return;
    }

    _isStreaming = true;

    try {
      final messages = _promptBuilder.buildMessages(
        userMessage: userMessage,
        history: history,
      );

      final endpoint = _getEndpoint();
      final request = http.Request('POST', Uri.parse(endpoint));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer ${_config.apiKey}';
      request.body = jsonEncode({
        'model': _config.model,
        'messages': messages,
        'temperature': _config.temperature,
        'max_tokens': _config.maxTokens,
        'stream': true,
        'tools': _functionHandler.getToolDefinitions(),
      });

      final streamedResponse = await _getClient().send(request);

      if (streamedResponse.statusCode != 200) {
        yield '❌ API Request failed (${streamedResponse.statusCode})';
        _isStreaming = false;
        return;
      }

      String buffer = '';

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;

        final lines = buffer.split('\n');
        buffer = lines.last;

        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isEmpty || !line.startsWith('data: ')) continue;

          final data = line.substring(6);
          if (data == '[DONE]') continue;

          try {
            final json = jsonDecode(data);
            final delta = json['choices']?[0]?['delta'];

            if (delta != null) {
              if (delta['tool_calls'] != null) {
                final toolCalls = delta['tool_calls'] as List;
                if (toolCalls.isNotEmpty) {
                  final funcName = toolCalls[0]['function']?['name'] as String?;
                  if (funcName != null) {
                    yield '\n\n🔧 Executing: $funcName...\n';
                  }
                }
              }

              final content = delta['content'] as String?;
              if (content != null) {
                yield content;
              }
            }
          } catch (e) {
            // Implementation detail.
          }
        }
      }
    } catch (e) {
      yield '\n\n❌ Streaming response error : $e';
    } finally {
      _isStreaming = false;
    }
  }

  /// Documentation.
  Future<ChatMessage> _sendFunctionResult({
    required String funcName,
    required Map<String, dynamic> arguments,
    required dynamic result,
    required List<ChatMessage> history,
    String? toolCallId,
  }) async {
    try {
      final messages = _promptBuilder.buildFunctionResultMessages(
        funcName: funcName,
        arguments: arguments,
        result: result,
        history: history,
      );

      // Implementation detail.
      if (toolCallId != null) {
        messages.add({
          'role': 'tool',
          'tool_call_id': toolCallId,
          'content': result.toString(),
        });
      }

      final response = await _makeRequest(messages, stream: false);

      if (response == null) {
        return ChatMessage.assistant('Function completed, but no AI summary was available');
      }

      final content =
          response['choices']?[0]?['message']?['content'] as String? ?? '';
      return ChatMessage.assistant(content);
    } catch (e) {
      return ChatMessage.assistant('Function completed: $result');
    }
  }

  /// Documentation.
  Future<Map<String, dynamic>?> _makeRequest(
    List<Map<String, dynamic>> messages, {
    bool stream = false,
  }) async {
    try {
      final endpoint = _getEndpoint();
      final response = await _getClient().post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_config.apiKey}',
        },
        body: jsonEncode({
          'model': _config.model,
          'messages': messages,
          'temperature': _config.temperature,
          'max_tokens': _config.maxTokens,
          'stream': stream,
          'tools': _functionHandler.getToolDefinitions(),
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('API Request failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('API request error: $e');
      return null;
    }
  }

  /// Documentation.
  http.Client _getClient() {
    _httpClient ??= http.Client();
    return _httpClient!;
  }

  /// Documentation.
  void dispose() {
    _httpClient?.close();
    _httpClient = null;
    _isStreaming = false;
  }
}
