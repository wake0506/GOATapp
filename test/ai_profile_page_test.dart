import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/ai_coach/models/ai_memory.dart';
import 'package:goat_app/features/ai_coach/pages/ai_profile_page.dart';
import 'package:goat_app/features/ai_coach/repositories/ai_coach_local_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    testWidgets(
      'AI profile is responsive at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: AiProfilePage(
              preferences: preferences,
              namespace: 'guest',
              trainingSessions: const [],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('ai-profile-page')), findsOneWidget);
        expect(find.text('AI 对我的了解'), findsOneWidget);
        expect(find.text('你告诉 GOAT 的'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('user can add, edit and delete provided profile memory', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MaterialApp(
        home: AiProfilePage(
          preferences: preferences,
          namespace: 'user_a',
          trainingSessions: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ai-profile-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ai-profile-value-input')),
      '增肌',
    );
    await tester.tap(find.byKey(const Key('ai-profile-save')));
    await tester.pumpAndSettle();
    expect(find.text('增肌'), findsOneWidget);

    final state = AiCoachLocalRepository(
      preferences: preferences,
      namespace: 'user_a',
    ).load();
    final id = state.memories.single.id;
    await tester.tap(find.byKey(Key('ai-memory-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).last;
    await tester.enterText(field, '增肌并提高力量');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('增肌并提高力量'), findsOneWidget);

    await tester.tap(find.byKey(Key('ai-memory-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('增肌并提高力量'), findsNothing);
  });

  testWidgets('pending inference requires confirm or reject', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = AiCoachLocalRepository(
      preferences: preferences,
      namespace: 'user_a',
    );
    await repository.addInference(
      AiMemoryItem(
        id: 'inference_1',
        stableKey: 'preferred_equipment',
        category: AiProfileCategory.trainingPreference,
        value: '你可能偏好哑铃动作',
        sourceType: AiMemorySourceType.aiInferred,
        status: AiMemoryStatus.pendingConfirmation,
        createdAt: DateTime.utc(2026, 7, 24),
        updatedAt: DateTime.utc(2026, 7, 24),
        sourceRefs: const [
          AiMemorySourceRef(
            type: 'suggestion',
            id: 'suggestion_1',
            label: '训练建议',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AiProfilePage(
          preferences: preferences,
          namespace: 'user_a',
          trainingSessions: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('待我确认'), findsOneWidget);
    expect(find.text('你可能偏好哑铃动作'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-memory-confirm-inference_1')));
    await tester.pumpAndSettle();

    expect(repository.load().memories.single.status, AiMemoryStatus.active);
  });
}
