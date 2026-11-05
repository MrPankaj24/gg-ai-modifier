/// Documentation.
/// Documentation.

import 'chat_message.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;
  final String summary;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.summary = '',
  });

  /// Documentation.
  factory ChatSession.fromMessages(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return ChatSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Empty conversation',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messages: [],
      );
    }

    // Implementation detail.
    String title = 'New conversation';
    final firstUserMessage = messages.firstWhere(
      (msg) => msg.isUser,
      orElse: () => messages.first,
    );

    if (firstUserMessage.content.isNotEmpty) {
      title = _generateTitle(firstUserMessage.content);
    }

    return ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      createdAt: messages.first.timestamp ?? DateTime.now(),
      updatedAt: messages.last.timestamp ?? DateTime.now(),
      messages: messages,
      summary: _generateSummary(messages),
    );
  }

  /// Documentation.
  static String _generateTitle(String firstMessage) {
    // Implementation detail.
    String cleaned = firstMessage.trim().replaceAll(RegExp(r'\s+'), ' ');

    // Implementation detail.
    if (cleaned.contains('金币') || cleaned.contains('money')) {
      return '💰 Coin modification';
    } else if (cleaned.contains('血量') || cleaned.contains('health') || cleaned.contains('生命') || cleaned.contains('life') || cleaned.contains('HP')) {
      return '❤️ Health modification';
    } else if (cleaned.contains('能量') || cleaned.contains('energy') || cleaned.contains('MP') || cleaned.contains('魔法') || cleaned.contains('magic')) {
      return '⚡ Energy modification';
    } else if (cleaned.contains('脚本') || cleaned.contains('Script') || cleaned.contains('代码')) {
      return '📜 Script generation';
    } else if (cleaned.contains('搜索') || cleaned.contains('Search') || cleaned.contains('查找') || cleaned.contains('find')) {
      return '🔍 Memory search';
    } else if (cleaned.contains('help ') || cleaned.contains('help')) {
      return '❓ Usage help';
    } else {
      // Implementation detail.
      if (cleaned.length > 20) {
        return cleaned.substring(0, 20) + '...';
      }
      return cleaned;
    }
  }

  /// Documentation.
  static String _generateSummary(List<ChatMessage> messages) {
    if (messages.isEmpty) return '';

    final userMessages = messages.where((msg) => msg.isUser).length;
    final aiMessages = messages.where((msg) => !msg.isUser).length;

    return '$userMessages  user messages, $aiMessages AI replies';
  }

  /// Documentation.
  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);

    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}  minutes ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}  hours ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}  days ago';
    } else {
      return '${updatedAt.month}/${updatedAt.day}';
    }
  }

  /// Documentation.
  String get previewText {
    if (messages.isEmpty) return 'No messages';

    final lastMessage = messages.last;
    String preview = lastMessage.content.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (preview.length > 50) {
      preview = preview.substring(0, 50) + '...';
    }

    return preview;
  }

  /// Documentation.
  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    String? summary,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      summary: summary ?? this.summary,
    );
  }

  /// Documentation.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'messages': messages.map((msg) => msg.toJson()).toList(),
      'summary': summary,
    };
  }

  /// Documentation.
  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      messages: (json['messages'] as List)
          .map((msgJson) => ChatMessage.fromJson(msgJson))
          .toList(),
      summary: json['summary'] as String? ?? '',
    );
  }
}
