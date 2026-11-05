/// Lua Scriptdata model

/// Scriptinformation
class ScriptModel {
  /// Script ID
  final String id;

  /// Script name
  final String name;

  /// ScriptDescription
  final String description;

  /// Scriptcontent  (Lua code)
  final String content;

  /// Documentation.
  final DateTime createdAt;

  /// Documentation.
  final DateTime updatedAt;

  /// Documentation.
  final bool isBuiltin;

  /// Documentation.
  final bool isAiGenerated;

  /// Documentation.
  final List<String> tags;

  /// Documentation.
  final int executionCount;

  /// Documentation.
  final DateTime? lastExecutedAt;

  ScriptModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.content,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isBuiltin = false,
    this.isAiGenerated = false,
    this.tags = const [],
    this.executionCount = 0,
    this.lastExecutedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  ScriptModel copyWith({
    String? id,
    String? name,
    String? description,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isBuiltin,
    bool? isAiGenerated,
    List<String>? tags,
    int? executionCount,
    DateTime? lastExecutedAt,
  }) {
    return ScriptModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      tags: tags ?? this.tags,
      executionCount: executionCount ?? this.executionCount,
      lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isBuiltin': isBuiltin,
      'isAiGenerated': isAiGenerated,
      'tags': tags,
      'executionCount': executionCount,
      'lastExecutedAt': lastExecutedAt?.toIso8601String(),
    };
  }

  factory ScriptModel.fromJson(Map<String, dynamic> json) {
    return ScriptModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isBuiltin: json['isBuiltin'] as bool? ?? false,
      isAiGenerated: json['isAiGenerated'] as bool? ?? false,
      tags: List<String>.from(json['tags'] as List? ?? []),
      executionCount: json['executionCount'] as int? ?? 0,
      lastExecutedAt: json['lastExecutedAt'] != null
          ? DateTime.parse(json['lastExecutedAt'] as String)
          : null,
    );
  }

  /// Documentation.
  factory ScriptModel.aiGenerated({
    required String name,
    required String content,
    String description = '',
    List<String> tags = const [],
  }) {
    return ScriptModel(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      content: content,
      isAiGenerated: true,
      tags: tags,
    );
  }

  @override
  String toString() {
    return 'ScriptModel(id: $id, name: $name, isBuiltin: $isBuiltin)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScriptModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
