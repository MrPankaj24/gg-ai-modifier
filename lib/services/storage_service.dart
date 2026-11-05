/// Documentation.
///
/// Documentation.
/// Documentation.

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/llm/llm_config.dart';
import '../core/models/chat_message.dart';
import '../core/models/chat_session.dart';
import '../core/models/script_model.dart';
import '../core/models/memory_result.dart';
import '../core/models/bookmark_model.dart';
import '../core/models/skill_model.dart';

/// Documentation.
class StorageService {
  static const String _llmConfigBox = 'llm_config';
  static const String _chatHistoryBox = 'chat_history';
  static const String _sessionsBox = 'sessions';
  static const String _scriptsBox = 'scripts';
  static const String _favoritesBox = 'favorites';
  static const String _bookmarksBox = 'bookmarks';
  static const String _settingsBox = 'settings';
  static const String _skillsBox = 'skills';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Documentation.
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();
    await Hive.openBox(_llmConfigBox);
    await Hive.openBox(_chatHistoryBox);
    await Hive.openBox(_sessionsBox);
    await Hive.openBox(_scriptsBox);
    await Hive.openBox(_favoritesBox);
    await Hive.openBox(_bookmarksBox);
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_skillsBox);

    _isInitialized = true;
  }

  // Implementation detail.

  /// Documentation.
  Future<void> saveLlmConfig(LlmConfig config) async {
    final box = Hive.box(_llmConfigBox);
    await box.put('current', jsonEncode(config.toJson()));
  }

  /// Documentation.
  LlmConfig? getLlmConfig() {
    final box = Hive.box(_llmConfigBox);
    final json = box.get('current') as String?;
    if (json == null) return null;
    return LlmConfig.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  // Implementation detail.

  /// Documentation.
  Future<void> saveChatHistory(List<ChatMessage> messages) async {
    final box = Hive.box(_chatHistoryBox);
    final jsonList = messages.map((m) => m.toJson()).toList();
    await box.put('history', jsonEncode(jsonList));
  }

  /// Documentation.
  List<ChatMessage> getChatHistory() {
    final box = Hive.box(_chatHistoryBox);
    final json = box.get('history') as String?;
    if (json == null) return [];

    final List<dynamic> jsonList = jsonDecode(json) as List<dynamic>;
    return jsonList.map((item) {
      return ChatMessage.fromJson(item as Map<String, dynamic>);
    }).toList();
  }

  /// Documentation.
  Future<void> clearChatHistory() async {
    final box = Hive.box(_chatHistoryBox);
    await box.delete('history');
  }

  // Implementation detail.

  /// Documentation.
  Future<void> saveSession(ChatSession session) async {
    final box = Hive.box(_sessionsBox);
    await box.put(session.id, jsonEncode(session.toJson()));
  }

  /// Documentation.
  List<ChatSession> getAllSessions() {
    final box = Hive.box(_sessionsBox);
    final sessions = box.values.map((item) {
      final json = item as String;
      return ChatSession.fromJson(jsonDecode(json) as Map<String, dynamic>);
    }).toList();

    // Implementation detail.
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  /// Documentation.
  ChatSession? getSession(String id) {
    final box = Hive.box(_sessionsBox);
    final json = box.get(id) as String?;
    if (json == null) return null;
    return ChatSession.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Documentation.
  Future<void> deleteSession(String id) async {
    final box = Hive.box(_sessionsBox);
    await box.delete(id);
  }

  /// Documentation.
  Future<void> clearAllSessions() async {
    final box = Hive.box(_sessionsBox);
    await box.clear();
  }

  /// Documentation.
  Future<void> addMessageToSession(
    String sessionId,
    ChatMessage message,
  ) async {
    final session = getSession(sessionId);
    if (session == null) return;

    final updatedMessages = [...session.messages, message];
    final updatedSession = session.copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );
    await saveSession(updatedSession);
  }

  /// Documentation.
  List<ChatMessage> getSessionMessages(
    String sessionId, {
    bool excludeAddressData = true,
  }) {
    final session = getSession(sessionId);
    if (session == null) return [];

    if (!excludeAddressData) return session.messages;

    // Implementation detail.
    return session.messages.where((msg) {
      // Implementation detail.
      if (msg.isUser || msg.type == MessageType.text) return true;
      // Implementation detail.
      if (msg.type == MessageType.functionCall) return true;
      // Implementation detail.
      if (msg.type == MessageType.functionResult && msg.content.length > 1000)
        return false;
      return true;
    }).toList();
  }

  // Implementation detail.

  /// SaveScript
  Future<void> saveScript(ScriptModel script) async {
    final box = Hive.box(_scriptsBox);
    await box.put(script.id, jsonEncode(script.toJson()));
  }

  /// Documentation.
  List<ScriptModel> getAllScripts() {
    final box = Hive.box(_scriptsBox);
    return box.values.map((item) {
      final json = item as String;
      return ScriptModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
    }).toList();
  }

  /// Documentation.
  ScriptModel? getScript(String id) {
    final box = Hive.box(_scriptsBox);
    final json = box.get(id) as String?;
    if (json == null) return null;
    return ScriptModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  /// DeleteScript
  Future<void> deleteScript(String id) async {
    final box = Hive.box(_scriptsBox);
    await box.delete(id);
  }

  // Implementation detail.

  /// Documentation.
  Future<void> saveFavorite(MemoryResult result) async {
    final box = Hive.box(_favoritesBox);
    await box.put(result.address, jsonEncode(result.toJson()));
  }

  /// Documentation.
  List<MemoryResult> getFavorites() {
    final box = Hive.box(_favoritesBox);
    return box.values.map((item) {
      final json = item as String;
      return MemoryResult.fromJson(jsonDecode(json) as Map<String, dynamic>);
    }).toList();
  }

  /// Documentation.
  Future<void> deleteFavorite(String address) async {
    final box = Hive.box(_favoritesBox);
    await box.delete(address);
  }

  // Implementation detail.

  /// Documentation.
  Future<void> saveBookmark(BookmarkModel bookmark) async {
    final box = Hive.box(_bookmarksBox);
    await box.put(bookmark.id, jsonEncode(bookmark.toJson()));
  }

  /// Documentation.
  List<BookmarkModel> getAllBookmarks() {
    final box = Hive.box(_bookmarksBox);
    final bookmarks = box.values.map((item) {
      final json = item as String;
      return BookmarkModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
    }).toList();

    bookmarks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return bookmarks;
  }

  /// Documentation.
  List<BookmarkModel> getBookmarksByPackage(String packageName) {
    return getAllBookmarks()
        .where((b) => b.packageName == packageName)
        .toList();
  }

  /// Documentation.
  BookmarkModel? getBookmark(String id) {
    final box = Hive.box(_bookmarksBox);
    final json = box.get(id) as String?;
    if (json == null) return null;
    return BookmarkModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Documentation.
  Future<void> deleteBookmark(String id) async {
    final box = Hive.box(_bookmarksBox);
    await box.delete(id);
  }

  /// Documentation.
  Future<void> updateBookmarkValue(String id, dynamic newValue) async {
    final bookmark = getBookmark(id);
    if (bookmark == null) return;

    final updated = bookmark.copyWith(
      currentValue: newValue,
      updatedAt: DateTime.now(),
    );
    await saveBookmark(updated);
  }

  /// Documentation.
  Future<void> toggleBookmarkFreeze(String id, dynamic freezeValue) async {
    final bookmark = getBookmark(id);
    if (bookmark == null) return;

    final updated = bookmark.copyWith(
      isFrozen: !bookmark.isFrozen,
      frozenValue: bookmark.isFrozen ? null : freezeValue,
      updatedAt: DateTime.now(),
    );
    await saveBookmark(updated);
  }

  // Implementation detail.

  /// SaveSettings
  Future<void> saveSetting(String key, dynamic value) async {
    final box = Hive.box(_settingsBox);
    await box.put(key, value);
  }

  /// Documentation.
  dynamic getSetting(String key, {dynamic defaultValue}) {
    final box = Hive.box(_settingsBox);
    return box.get(key, defaultValue: defaultValue);
  }

  /// DeleteSettings
  Future<void> deleteSetting(String key) async {
    final box = Hive.box(_settingsBox);
    await box.delete(key);
  }

  // Implementation detail.

  /// Save Skill
  Future<void> saveSkill(SkillModel skill) async {
    final box = Hive.box(_skillsBox);
    await box.put(skill.id, jsonEncode(skill.toJson()));
  }

  /// Documentation.
  List<SkillModel> getAllSkills() {
    final box = Hive.box(_skillsBox);
    return box.values.map((item) {
      final json = item as String;
      return SkillModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
    }).toList();
  }

  /// Documentation.
  List<SkillModel> getEnabledSkills() {
    return getAllSkills().where((skill) => skill.isEnabled).toList();
  }

  /// Documentation.
  SkillModel? getSkill(String id) {
    final box = Hive.box(_skillsBox);
    final json = box.get(id) as String?;
    if (json == null) return null;
    return SkillModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Delete Skill
  Future<void> deleteSkill(String id) async {
    final box = Hive.box(_skillsBox);
    await box.delete(id);
  }

  /// Documentation.
  Future<void> toggleSkill(String id) async {
    final skill = getSkill(id);
    if (skill == null) return;
    final updated = skill.copyWith(
      isEnabled: !skill.isEnabled,
      updatedAt: DateTime.now(),
    );
    await saveSkill(updated);
  }

  /// Documentation.
  Future<void> dispose() async {
    await Hive.close();
    _isInitialized = false;
  }
}
