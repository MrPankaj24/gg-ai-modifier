/// Documentation.

/// Documentation.
enum MessageRole {
  system('system'),
  user('user'),
  assistant('assistant');

  final String value;
  const MessageRole(this.value);
}

/// Documentation.
enum MessageType {
  text, // Implementation detail.
  functionCall, // Implementation detail.
  functionResult, // Implementation detail.
  error, // Implementation detail.
  system, // Implementation detail.
}

/// Documentation.
class ChatMessage {
  /// Documentation.
  final String id;

  /// Documentation.
  final MessageRole role;

  /// Documentation.
  final String content;

  /// Documentation.
  final MessageType type;

  /// Documentation.
  final DateTime timestamp;

  /// Documentation.
  final FunctionCall? functionCall;

  /// Documentation.
  final FunctionResult? functionResult;

  /// Documentation.
  final bool isLoading;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.type = MessageType.text,
    DateTime? timestamp,
    this.functionCall,
    this.functionResult,
    this.isLoading = false,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    FunctionCall? functionCall,
    FunctionResult? functionResult,
    bool? isLoading,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      functionCall: functionCall ?? this.functionCall,
      functionResult: functionResult ?? this.functionResult,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Documentation.
  bool get isUser => role == MessageRole.user;

  /// Documentation.
  bool get isAssistant => role == MessageRole.assistant;

  /// Documentation.
  bool get isSystem => role == MessageRole.system;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.value,
      'content': content,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'functionCall': functionCall?.toJson(),
      'functionResult': functionResult?.toJson(),
      'isLoading': isLoading,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: MessageRole.values.firstWhere(
        (e) => e.value == json['role'],
        orElse: () => MessageRole.user,
      ),
      content: json['content'] as String? ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      functionCall: json['functionCall'] != null
          ? FunctionCall.fromJson(json['functionCall'] as Map<String, dynamic>)
          : null,
      functionResult: json['functionResult'] != null
          ? FunctionResult.fromJson(
              json['functionResult'] as Map<String, dynamic>,
            )
          : null,
      isLoading: json['isLoading'] as bool? ?? false,
    );
  }

  /// Documentation.
  factory ChatMessage.user(String content, {String? id}) {
    return ChatMessage(
      id: id ?? _generateId(),
      role: MessageRole.user,
      content: content,
    );
  }

  /// Documentation.
  factory ChatMessage.assistant(String content, {String? id}) {
    return ChatMessage(
      id: id ?? _generateId(),
      role: MessageRole.assistant,
      content: content,
    );
  }

  /// Documentation.
  factory ChatMessage.system(String content, {String? id}) {
    return ChatMessage(
      id: id ?? _generateId(),
      role: MessageRole.system,
      content: content,
      type: MessageType.system,
    );
  }

  /// Documentation.
  factory ChatMessage.loading({String? id}) {
    return ChatMessage(
      id: id ?? _generateId(),
      role: MessageRole.assistant,
      content: '',
      isLoading: true,
    );
  }

  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  String toString() {
    return 'ChatMessage(role: ${role.value}, content: ${content.length > 50 ? "${content.substring(0, 50)}..." : content})';
  }
}

/// Documentation.
class FunctionCall {
  /// Documentation.
  final String name;

  /// Documentation.
  final Map<String, dynamic> arguments;

  const FunctionCall({required this.name, required this.arguments});

  Map<String, dynamic> toJson() {
    return {'name': name, 'arguments': arguments};
  }

  factory FunctionCall.fromJson(Map<String, dynamic> json) {
    return FunctionCall(
      name: json['name'] as String,
      arguments: Map<String, dynamic>.from(json['arguments'] as Map? ?? {}),
    );
  }

  @override
  String toString() {
    return 'FunctionCall(name: $name, args: $arguments)';
  }
}

/// Documentation.
class FunctionResult {
  /// Documentation.
  final String name;

  /// execute results
  final dynamic result;

  /// whether succeeded
  final bool success;

  /// error information
  final String? error;

  const FunctionResult({
    required this.name,
    this.result,
    this.success = true,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {'name': name, 'result': result, 'success': success, 'error': error};
  }

  factory FunctionResult.fromJson(Map<String, dynamic> json) {
    return FunctionResult(
      name: json['name'] as String,
      result: json['result'],
      success: json['success'] as bool? ?? true,
      error: json['error'] as String?,
    );
  }
}
