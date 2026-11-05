/// Documentation.
/// Documentation.
/// Documentation.
/// Documentation.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/chat_message.dart';
import '../../core/models/chat_session.dart';
import '../../main.dart';
import '../process/process_selector.dart';
import 'markdown_webview.dart';

/// Documentation.
final chatMessagesProvider = StateProvider<List<ChatMessage>>((ref) => []);

/// Documentation.
final chatSessionsProvider = StateProvider<List<ChatSession>>((ref) => []);

/// Documentation.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  /// Documentation.
  bool _isMultiSelectMode = false;
  final Set<String> _selectedSessionIds = {};

  @override
  void initState() {
    super.initState();
    _loadChatSessions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reloadSessions();
  }

  void _reloadSessions() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final storage = ref.read(storageServiceProvider);
      final savedSessions = storage.getAllSessions();
      final currentSessions = ref.read(chatSessionsProvider);

      final mergedMap = <String, ChatSession>{};
      for (final s in currentSessions) {
        mergedMap[s.id] = s;
      }
      for (final s in savedSessions) {
        mergedMap[s.id] = s;
      }

      // Implementation detail.
      try {
        const channel = MethodChannel('com.yl.aigg/bridge');
        final result = await channel.invokeMethod('getOverlayChats');
        if (result != null && result is List) {
          for (final chatData in result) {
            if (chatData is! Map) continue;
            final chatId = chatData['id'] as String? ?? '';
            // Implementation detail.
            if (mergedMap.containsKey(chatId)) continue;

            DateTime? sessionTime;
            if (chatId.startsWith('chat_')) {
              final ms = int.tryParse(chatId.substring(5));
              if (ms != null) sessionTime = DateTime.fromMillisecondsSinceEpoch(ms);
            }

            final messages = <ChatMessage>[];
            final chatMessages = chatData['messages'] as List? ?? [];
            for (final msg in chatMessages) {
              if (msg is! Map) continue;
              final sender = msg['sender'] as String? ?? '';
              final message = msg['message'] as String? ?? '';
              final tsMs = msg['timestamp'] as int?;
              final msgTime = tsMs != null
                  ? DateTime.fromMillisecondsSinceEpoch(tsMs)
                  : sessionTime;
              final isUser = sender.contains('我') ||
                  sender.contains('Me') ||
                  sender.contains('User');
              if (isUser) {
                messages.add(ChatMessage.user(message).copyWith(timestamp: msgTime));
              } else {
                messages.add(ChatMessage.assistant(message).copyWith(timestamp: msgTime));
              }
            }

            if (messages.isNotEmpty) {
              final session = ChatSession.fromMessages(messages).copyWith(id: chatId);
              mergedMap[session.id] = session;
              // Implementation detail.
              await storage.saveSession(session);
            }
          }
        }
      } catch (_) {}

      final merged = mergedMap.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      ref.read(chatSessionsProvider.notifier).state = merged;
    });
  }

  void _loadChatSessions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = ref.read(storageServiceProvider);
      final savedSessions = storage.getAllSessions();
      _loadOverlayChats(savedSessions);
      if (savedSessions.isNotEmpty) {
        ref.read(chatSessionsProvider.notifier).state = savedSessions;
      }
    });
  }

  /// Documentation.
  Future<void> _loadOverlayChats(List<ChatSession> existingSessions) async {
    try {
      const channel = MethodChannel('com.yl.aigg/bridge');
      final result = await channel.invokeMethod('getOverlayChats');
      if (result == null || result is! List || result.isEmpty) return;

      final storage = ref.read(storageServiceProvider);
      final existingIds = existingSessions.map((s) => s.id).toSet();
      final overlaySessions = <ChatSession>[];

      for (final chatData in result) {
        if (chatData is! Map) continue;
        final chatId = chatData['id'] as String? ?? '';
        // Implementation detail.
        if (existingIds.contains(chatId)) continue;

        // Implementation detail.
        DateTime? sessionTime;
        if (chatId.startsWith('chat_')) {
          final ms = int.tryParse(chatId.substring(5));
          if (ms != null) sessionTime = DateTime.fromMillisecondsSinceEpoch(ms);
        }

        final messages = <ChatMessage>[];
        final chatMessages = chatData['messages'] as List? ?? [];
        for (final msg in chatMessages) {
          if (msg is! Map) continue;
          final sender = msg['sender'] as String? ?? '';
          final message = msg['message'] as String? ?? '';
          final tsMs = msg['timestamp'] as int?;
          final msgTime = tsMs != null
              ? DateTime.fromMillisecondsSinceEpoch(tsMs)
              : sessionTime;
          final isUser = sender.contains('我');
          if (isUser) {
            messages.add(ChatMessage.user(message).copyWith(timestamp: msgTime));
          } else {
            messages.add(ChatMessage.assistant(message).copyWith(timestamp: msgTime));
          }
        }

        if (messages.isNotEmpty) {
          final session = ChatSession.fromMessages(messages).copyWith(id: chatId);
          overlaySessions.add(session);
        }
      }

      if (overlaySessions.isNotEmpty && mounted) {
        // Implementation detail.
        for (final s in overlaySessions) {
          await storage.saveSession(s);
        }
        final current = ref.read(chatSessionsProvider);
        final merged = [...overlaySessions, ...current]
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        ref.read(chatSessionsProvider.notifier).state = merged;
      }
    } catch (_) {}
  }

  /// Clear all records
  void _clearAllSessions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        title: const Text('Clear all records'),
        content: const Text('Clear all chat records? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              ref.read(chatSessionsProvider.notifier).state = [];
              final storage = ref.read(storageServiceProvider);
              await storage.clearAllSessions();
              await storage.clearChatHistory();
              try {
                const channel = MethodChannel('com.yl.aigg/bridge');
                await channel.invokeMethod('clearOverlayChats');
              } catch (_) {}
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('✅ All chat records cleared')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  /// Documentation.
  String _generateMarkdown(ChatSession session) {
    final buffer = StringBuffer();
    buffer.writeln('# ${session.title}');
    buffer.writeln();
    buffer.writeln('> Created: ${session.createdAt.toString().substring(0, 19)}');
    buffer.writeln('> Updated: ${session.updatedAt.toString().substring(0, 19)}');
    buffer.writeln('> ${session.summary}');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    for (final msg in session.messages) {
      if (msg.isUser) {
        buffer.writeln('## 👤 User');
      } else {
        buffer.writeln('## 🤖 GG-AI');
      }
      buffer.writeln();
      buffer.writeln(msg.content);
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }

    buffer.writeln('*Exported: ${DateTime.now().toString().substring(0, 19)}*');
    return buffer.toString();
  }

  /// Documentation.
  Future<void> _exportSingleSession(ChatSession session) async {
    try {
      final markdown = _generateMarkdown(session);
      final safeTitle = session.title.replaceAll(
        RegExp(r'[^\w\u4e00-\u9fa5]'),
        '_',
      );
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${safeTitle}_$timestamp.md';

      const channel = MethodChannel('com.yl.aigg/bridge');
      final filePath = await channel.invokeMethod('exportChatToFile', {
        'fileName': fileName,
        'content': markdown,
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('✅ Exported to: $filePath')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Export failed: $e')));
      }
    }
  }

  /// Documentation.
  Future<void> _exportMultipleSessions(List<ChatSession> sessions) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('# GG-AI Bulk export of GG-AI chat history');
      buffer.writeln();
      buffer.writeln('> Exported: ${DateTime.now().toString().substring(0, 19)}');
      buffer.writeln('> ${sessions.length} sessions');
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();

      for (int i = 0; i < sessions.length; i++) {
        buffer.writeln(_generateMarkdown(sessions[i]));
        if (i < sessions.length - 1) {
          buffer.writeln('\n\n');
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'GG-AI_bulk export _$timestamp.md';

      const channel = MethodChannel('com.yl.aigg/bridge');
      final filePath = await channel.invokeMethod('exportChatToFile', {
        'fileName': fileName,
        'content': buffer.toString(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ export  ${sessions.length}  sessions to: $filePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Export failed: $e')));
      }
    }
  }

  /// Documentation.
  void _showExportDialog() {
    final sessions = ref.read(chatSessionsProvider);
    if (sessions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No chat records to export')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        title: const Text('Export chat records'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.file_download,
                color: Color(0xFF3D5AFE),
              ),
              title: const Text('Export all to file'),
              subtitle: Text('Export ${sessions.length} sessions as a Markdown file'),
              onTap: () {
                Navigator.pop(context);
                _exportMultipleSessions(sessions);
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist, color: Color(0xFF536DFE)),
              title: const Text('Choose export'),
              subtitle: const Text('Choose sessions to export'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isMultiSelectMode = true;
                  _selectedSessionIds.clear();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Documentation.
  void _refreshSessions() {
    _reloadSessions();
    // Implementation detail.
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        final sessions = ref.read(chatSessionsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Refreshed; ${sessions.length} sessions'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    });
  }

  void _viewSession(ChatSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatSessionDetailPage(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(chatSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isMultiSelectMode
            ? Text('Select ${_selectedSessionIds.length} items')
            : const Row(
                children: [
                  Icon(Icons.history, color: Color(0xFF3D5AFE)),
                  SizedBox(width: 8),
                  Text('Chat History'),
                ],
              ),
        leading: _isMultiSelectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isMultiSelectMode = false;
                    _selectedSessionIds.clear();
                  });
                },
              )
            : null,
        actions: _isMultiSelectMode
            ? [
                // Select all/Deselect all
                IconButton(
                  icon: Icon(
                    _selectedSessionIds.length == sessions.length
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  tooltip: _selectedSessionIds.length == sessions.length
                      ? 'Deselect all'
                      : 'Select all',
                  onPressed: () {
                    setState(() {
                      if (_selectedSessionIds.length == sessions.length) {
                        _selectedSessionIds.clear();
                      } else {
                        _selectedSessionIds.addAll(sessions.map((s) => s.id));
                      }
                    });
                  },
                ),
                // Export selected
                IconButton(
                  icon: const Icon(Icons.file_download),
                  tooltip: 'Export selected',
                  onPressed: _selectedSessionIds.isEmpty
                      ? null
                      : () {
                          final selected = sessions
                              .where((s) => _selectedSessionIds.contains(s.id))
                              .toList();
                          setState(() {
                            _isMultiSelectMode = false;
                            _selectedSessionIds.clear();
                          });
                          _exportMultipleSessions(selected);
                        },
                ),
              ]
            : [
                // refresh button
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh chat records',
                  onPressed: _refreshSessions,
                ),
                // export button
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Export chat records',
                  onPressed: _showExportDialog,
                ),
                // Clearbutton
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: 'Clear all records',
                  onPressed: _clearAllSessions,
                ),
                // Overlaybutton
                IconButton(
                  icon: const Icon(Icons.chat_bubble),
                  tooltip: 'Start overlay chat',
                  onPressed: () {
                    const channel = MethodChannel('com.yl.aigg/bridge');
                    channel.invokeMethod('startOverlay');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('💡 Overlay started. Tap the bubble → AI Chat'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              ],
      ),
      body: Column(
        children: [
          // Implementation detail.
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF3D5AFE).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF3D5AFE),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Instructions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3D5AFE),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• • Live chat: use AI Chat in the overlay\n'
                  '• • History: view all chat history here\n'
                  '• • In-game use: the overlay is better for quick chats\n'
                  '• • Manual refresh: after the overlay saves a chat, tap the 🔄 refresh button\n'
                  '• • Export: only individual chats can be exported as Markdown\n'
                  '• • Export paths: Android 10 /AI-gg/; Android 11+ /Documents/AI-gg/',
                  style: TextStyle(color: Color(0xFF4A6572), fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          const channel = MethodChannel('com.yl.aigg/bridge');
                          channel.invokeMethod('startOverlay');
                        },
                        icon: const Icon(Icons.chat_bubble, size: 16),
                        label: const Text('Start overlay chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3D5AFE),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Implementation detail.
          Expanded(
            child: sessions.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Color(0xFF4A6572)),
                        SizedBox(height: 16),
                        Text('No chat records', style: TextStyle(color: Color(0xFF4A6572))),
                        SizedBox(height: 8),
                        Text(
                          'Use the overlay to start an AI chat',
                          style: TextStyle(color: Color(0xFF4A6572), fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return _buildSessionCard(session);
                    },
                  ),
          ),

          // Implementation detail.
          if (sessions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFFFFFFF),
              child: Row(
                children: [
                  const Icon(Icons.analytics, size: 16, color: Color(0xFF4A6572)),
                  const SizedBox(width: 8),
                  Text(
                    '${sessions.length} chat sessions',
                    style: const TextStyle(color: Color(0xFF4A6572), fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    'Last updated: ${DateTime.now().toString().substring(0, 16)}',
                    style: const TextStyle(color: Color(0xFF4A6572), fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(ChatSession session) {
    final isSelected = _selectedSessionIds.contains(session.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected
          ? const Color(0xFF3D5AFE).withOpacity(0.15)
          : const Color(0xFFFFFFFF),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: _isMultiSelectMode
            ? Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedSessionIds.add(session.id);
                    } else {
                      _selectedSessionIds.remove(session.id);
                    }
                  });
                },
                activeColor: const Color(0xFF3D5AFE),
              )
            : Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF3D5AFE).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getSessionIcon(session.title),
                  color: const Color(0xFF3D5AFE),
                  size: 24,
                ),
              ),
        title: Text(
          session.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              session.previewText,
              style: const TextStyle(color: Color(0xFF4A6572), fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Color(0xFF4A6572)),
                const SizedBox(width: 4),
                Text(
                  session.formattedTime,
                  style: TextStyle(color: Color(0xFF4A6572), fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.chat_bubble_outline,
                  size: 14,
                  color: Color(0xFF4A6572),
                ),
                const SizedBox(width: 4),
                Text(
                  '${session.messages.length}  messages',
                  style: TextStyle(color: Color(0xFF4A6572), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: _isMultiSelectMode
            ? null
            : PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.file_download, size: 16),
                        SizedBox(width: 8),
                        Text('Export as Markdown'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'export':
                      _exportSingleSession(session);
                      break;
                    case 'delete':
                      _deleteSession(session);
                      break;
                  }
                },
              ),
        onTap: _isMultiSelectMode
            ? () {
                setState(() {
                  if (isSelected) {
                    _selectedSessionIds.remove(session.id);
                  } else {
                    _selectedSessionIds.add(session.id);
                  }
                });
              }
            : () => _viewSession(session),
        onLongPress: _isMultiSelectMode
            ? null
            : () {
                setState(() {
                  _isMultiSelectMode = true;
                  _selectedSessionIds.add(session.id);
                });
              },
      ),
    );
  }

  void _deleteSession(ChatSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        title: const Text('Delete chat'),
        content: Text('Delete "${session.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final sessions = ref.read(chatSessionsProvider);
              ref.read(chatSessionsProvider.notifier).state = sessions
                  .where((s) => s.id != session.id)
                  .toList();
              final storage = ref.read(storageServiceProvider);
              await storage.deleteSession(session.id);
              // Implementation detail.
              if (session.id.startsWith('chat_')) {
                try {
                  const channel = MethodChannel('com.yl.aigg/bridge');
                  await channel.invokeMethod('deleteOverlayChat', {'sessionId': session.id});
                } catch (_) {}
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _getSessionIcon(String title) {
    if (title.contains('💰') || title.contains('金币')) {
      return Icons.monetization_on;
    } else if (title.contains('❤️') || title.contains('血量') || title.contains('health')) {
      return Icons.favorite;
    } else if (title.contains('⚡') || title.contains('energy')) {
      return Icons.flash_on;
    } else if (title.contains('📜') || title.contains('Script')) {
      return Icons.code;
    } else if (title.contains('🔍') || title.contains('Search')) {
      return Icons.search;
    } else if (title.contains('❓') || title.contains('help ')) {
      return Icons.help;
    } else {
      return Icons.chat;
    }
  }
}

/// Documentation.
class ChatSessionDetailPage extends StatefulWidget {
  final ChatSession session;

  const ChatSessionDetailPage({super.key, required this.session});

  @override
  State<ChatSessionDetailPage> createState() => _ChatSessionDetailPageState();
}

class _ChatSessionDetailPageState extends State<ChatSessionDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export as Markdown',
            onPressed: () async {
              try {
                final buffer = StringBuffer();
                buffer.writeln('# ${widget.session.title}');
                buffer.writeln();
                buffer.writeln('> Created: ${widget.session.createdAt.toString().substring(0, 19)}');
                buffer.writeln('> ${widget.session.summary}');
                buffer.writeln();
                buffer.writeln('---');
                buffer.writeln();
                for (final msg in widget.session.messages) {
                  buffer.writeln('## ${msg.isUser ? "👤 User" : "🤖 GG-AI"}');
                  buffer.writeln();
                  buffer.writeln(msg.content);
                  buffer.writeln();
                  buffer.writeln('---');
                  buffer.writeln();
                }
                buffer.writeln('*Exported: ${DateTime.now().toString().substring(0, 19)}*');

                final safeTitle = widget.session.title.replaceAll(RegExp(r'[^\w\u4e00-\u9fa5]'), '_');
                final timestamp = DateTime.now().millisecondsSinceEpoch;
                final fileName = '${safeTitle}_$timestamp.md';

                const channel = MethodChannel('com.yl.aigg/bridge');
                final filePath = await channel.invokeMethod('exportChatToFile', {'fileName': fileName, 'content': buffer.toString()});

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Exported to: $filePath')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Export failed: $e')));
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy to clipboard',
            onPressed: () {
              final exportText =
                  '=== ${widget.session.title} ===\n'
                  'Time:  ${widget.session.createdAt.toString().substring(0, 19)}\n\n'
                  '${widget.session.messages.map((msg) {
                    final role = msg.isUser ? 'User' : 'AI assistant';
                    return '$role: ${msg.content}';
                  }).join('\n\n')}';

              Clipboard.setData(ClipboardData(text: exportText));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Chat copied to clipboard')));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Implementation detail.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFFFFFFF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.session.summary, style: const TextStyle(color: Color(0xFF4A6572))),
                const SizedBox(height: 4),
                Text('Created: ${widget.session.createdAt.toString().substring(0, 19)}', style: const TextStyle(color: Color(0xFF4A6572), fontSize: 12)),
              ],
            ),
          ),
          // Implementation detail.
          Expanded(
            child: MarkdownWebView(
              messages: widget.session.messages,
              maxWidth: MediaQuery.of(context).size.width,
            ),
          ),
        ],
      ),
    );
  }
}
