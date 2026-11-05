import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_gg666/app.dart';
import 'package:ai_gg666/core/models/chat_session.dart';
import 'package:ai_gg666/main.dart';
import 'package:ai_gg666/services/storage_service.dart';

class _TestStorageService extends StorageService {
  @override
  List<ChatSession> getAllSessions() => const [];
}

void main() {
  testWidgets('App launches correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(_TestStorageService()),
        ],
        child: GgModifierApp(),
      ),
    );
    await tester.pump();

    // Verify that the main navigation is rendered.
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
