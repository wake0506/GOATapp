import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/ai_coach/models/ai_coach_state.dart';
import 'package:goat_app/features/ai_coach/models/ai_memory.dart';
import 'package:goat_app/features/ai_coach/models/ai_suggestion.dart';
import 'package:goat_app/features/profile/models/profile_summary.dart';
import 'package:goat_app/features/profile/pages/account_center_pages.dart';
import 'package:goat_app/features/profile/pages/profile_page.dart';
import 'package:goat_app/features/profile/services/account_deletion_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  const sizes = [Size(360, 800), Size(390, 844), Size(412, 915)];

  for (final size in sizes) {
    testWidgets(
      'profile account center is overflow-free at ${size.width}x${size.height}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(home: _profilePage(summary: _summary())),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile-account-center')), findsOneWidget);
        expect(find.text('Zhuoyang Xu'), findsOneWidget);
        expect(find.text('user@example.com'), findsOneWidget);
        expect(find.text('2 条待确认'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.scrollUntilVisible(
          find.byKey(const Key('profile-action-dataPrivacy')),
          450,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(
          find.byKey(const Key('profile-action-dataPrivacy')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'profile secondary surfaces are responsive at ${size.width}x${size.height}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        PackageInfo.setMockInitialValues(
          appName: 'GOAT',
          packageName: 'com.example.goat_app',
          version: '1.0.0',
          buildNumber: '1',
          buildSignature: '',
        );

        await tester.pumpWidget(
          MaterialApp(home: _profilePage(summary: _summary())),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('profile-edit-entry')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('profile-edit-height')));
        await tester.showKeyboard(find.byKey(const Key('profile-edit-height')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        tester.testTextInput.hide();
        Navigator.of(
          tester.element(find.byKey(const Key('profile-edit-height'))),
        ).pop();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('profile-action-trainingGoal')));
        await tester.pumpAndSettle();
        expect(find.text('力量提升'), findsOneWidget);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.text('力量提升'))).pop();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('profile-action-equipment')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('profile-equipment-save')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          MaterialApp(
            home: SuggestionHistoryPage(
              stateLoader: () => AiCoachState(
                suggestions: [
                  _suggestion('responsive', AiSuggestionStatus.proposed),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          MaterialApp(
            home: DataPrivacyPage(
              isLoggedIn: true,
              onExportCloud: () async => 'cloud.json',
              onExportLocal: () async => 'local.json',
              onOpenAiProfile: () async {},
              onDeleteAccount: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          MaterialApp(home: DeleteAccountPage(onDeleteAccount: (_) async {})),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          MaterialApp(
            home: AboutGoatPage(
              onOpenPrivacy: () async {},
              onOpenLicenses: () async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'profile visible actions are functional and no placeholders remain',
    (tester) async {
      final calls = <String>[];
      final values = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: _profilePage(
            summary: _summary(),
            calls: calls,
            onSaveValue: (category, value) async {
              values.add('${category.name}:$value');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('高级版会员'), findsNothing);
      expect(find.text('提醒设置'), findsNothing);
      expect(find.text('帮助与反馈'), findsNothing);

      await tester.tap(find.byKey(const Key('profile-summary-training')));
      await tester.pump();
      expect(calls, contains('training'));

      await tester.tap(find.byKey(const Key('profile-action-trainingGoal')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('力量提升').last);
      await tester.pumpAndSettle();
      expect(values, contains('trainingGoal:力量提升'));

      await tester.tap(find.byKey(const Key('profile-edit-entry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-edit-name')), findsOneWidget);
      expect(find.byKey(const Key('profile-edit-height')), findsOneWidget);
      expect(find.byKey(const Key('profile-edit-birth-year')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('every enabled profile row has an action id and handler', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: _profilePage(summary: _summary())),
    );
    await tester.pumpAndSettle();
    const ids = [
      ProfileActionId.trainingGoal,
      ProfileActionId.trainingExperience,
      ProfileActionId.equipment,
      ProfileActionId.trainingPreferences,
      ProfileActionId.coachingStyle,
      ProfileActionId.trainingPlans,
      ProfileActionId.aiProfile,
      ProfileActionId.suggestionHistory,
      ProfileActionId.knowledgeExplanation,
      ProfileActionId.weightHistory,
      ProfileActionId.trainingHistory,
      ProfileActionId.weeklyReview,
      ProfileActionId.allRecords,
      ProfileActionId.dataPrivacy,
      ProfileActionId.about,
      ProfileActionId.licenses,
    ];
    for (final id in ids) {
      final finder = find.byKey(Key('profile-action-${id.name}'));
      await tester.scrollUntilVisible(
        finder,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      final action = tester.widget<InkWell>(finder);
      expect(action.onTap, isNotNull, reason: id.name);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest profile stays honest and exposes login action', (
    tester,
  ) async {
    final calls = <String>[];
    final guestSummary = ProfileSummary(
      identity: const ProfileIdentity(
        isLoggedIn: false,
        displayName: '',
        email: '',
      ),
      totalTrainingSessions: 0,
      weeklyTrainingDays: 0,
      weeklyEffectiveSets: 0,
      trendWeightKg: null,
      latestWeightKg: null,
      templateCount: 0,
      activeMemoryCount: 0,
      pendingMemoryCount: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: _profilePage(summary: guestSummary, calls: calls),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本地使用'), findsOneWidget);
    expect(find.text('G O A T 玩家'), findsNothing);
    expect(find.byKey(const Key('profile-login-entry')), findsOneWidget);
    expect(find.byKey(const Key('profile-logout')), findsNothing);
    await tester.tap(find.byKey(const Key('profile-login-entry')));
    expect(calls, contains('login'));
  });

  testWidgets('suggestion history groups status and opens human details', (
    tester,
  ) async {
    final state = AiCoachState(
      suggestions: [
        _suggestion('pending', AiSuggestionStatus.proposed),
        _suggestion('applied', AiSuggestionStatus.applied),
        _suggestion('ignored', AiSuggestionStatus.dismissed),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: SuggestionHistoryPage(stateLoader: () => state)),
    );
    await tester.pumpAndSettle();

    expect(find.text('建议 pending'), findsOneWidget);
    await tester.tap(find.text('建议 pending'));
    await tester.pumpAndSettle();
    expect(find.text('建议内容'), findsOneWidget);
    expect(find.textContaining('1 条训练或趋势数据依据'), findsOneWidget);
    expect(find.textContaining('{'), findsNothing);
  });

  testWidgets('data privacy hides cloud danger actions while signed out', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DataPrivacyPage(
          isLoggedIn: false,
          onExportCloud: () async => 'cloud.json',
          onExportLocal: () async => 'local.json',
          onOpenAiProfile: () async {},
          onDeleteAccount: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('privacy-cloud-export')), findsNothing);
    expect(find.byKey(const Key('privacy-delete-account')), findsNothing);
    expect(find.byKey(const Key('privacy-local-export')), findsOneWidget);
    expect(find.textContaining('当前为本地使用'), findsOneWidget);
  });

  testWidgets('delete account requires exact phrase and final confirmation', (
    tester,
  ) async {
    var deletions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DeleteAccountPage(
          onDeleteAccount: (phrase) async {
            expect(phrase, AccountDeletionService.confirmationPhrase);
            deletions++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('delete-account-submit'));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('delete-account-confirmation')),
      'DELETE',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('delete-account-confirmation')),
      AccountDeletionService.confirmationPhrase,
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-account-final-confirm')));
    await tester.pumpAndSettle();
    expect(deletions, 1);
  });

  testWidgets('about page reads package metadata and keeps actions real', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'GOAT',
      packageName: 'com.example.goat_app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    var privacy = 0;
    var licenses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AboutGoatPage(
          onOpenPrivacy: () async => privacy++,
          onOpenLicenses: () async => licenses++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1.0.0'), findsOneWidget);
    await tester.tap(find.text('隐私与数据'));
    await tester.tap(find.text('开源许可'));
    expect(privacy, 1);
    expect(licenses, 1);
    expect(tester.takeException(), isNull);
  });
}

ProfilePage _profilePage({
  required ProfileSummary summary,
  List<String>? calls,
  Future<void> Function(AiProfileCategory, String?)? onSaveValue,
}) {
  final events = calls ?? <String>[];
  Future<void> call(String value) async => events.add(value);
  return ProfilePage(
    identity: summary.identity,
    basicData: const ProfileBasicData(
      gender: '男',
      birthYear: 2000,
      birthMonth: 1,
      birthDay: 1,
      heightCm: 175,
      currentWeightKg: 71.4,
    ),
    summaryLoader: () async => summary,
    onSaveBasic: (_) async => events.add('basic'),
    onSaveProfileValue: onSaveValue ?? (category, value) async {},
    equipmentOptions: const ['自由重量', '器械', '绳索', '徒手', '壶铃'],
    onOpenTrainingHistory: () => call('training'),
    onOpenWeeklyReview: () => call('weekly'),
    onOpenWeightHistory: () => call('weight'),
    onManageTrainingPlans: () => call('plans'),
    onOpenAiProfile: () => call('ai'),
    onOpenSuggestionHistory: () => call('suggestions'),
    onOpenKnowledgeExplanation: () => call('knowledge'),
    onOpenAllRecords: () => call('records'),
    onOpenDataPrivacy: () => call('privacy'),
    onOpenAbout: () => call('about'),
    onOpenLicenses: () => call('licenses'),
    onLogin: () => call('login'),
    onLogout: () => call('logout'),
  );
}

ProfileSummary _summary() => const ProfileSummary(
  identity: ProfileIdentity(
    isLoggedIn: true,
    displayName: 'Zhuoyang Xu',
    email: 'user@example.com',
  ),
  totalTrainingSessions: 48,
  weeklyTrainingDays: 4,
  weeklyEffectiveSets: 16,
  trendWeightKg: 71.4,
  latestWeightKg: 71.5,
  templateCount: 4,
  activeMemoryCount: 12,
  pendingMemoryCount: 2,
  trainingGoal: '增肌',
  trainingExperience: '有一定经验',
  availableEquipment: ['自由重量', '绳索'],
  coachingStyle: '详细解释',
);

AiSuggestion _suggestion(String id, AiSuggestionStatus status) => AiSuggestion(
  id: id,
  type: AiSuggestionType.training,
  title: '建议 $id',
  summary: '根据本周训练记录调整下一次安排。',
  reasonCodes: const ['weekly_training'],
  evidenceRefs: const ['weekly_review_1'],
  knowledgeRefs: const ['training_frequency_v1'],
  dataQuality: AiSuggestionDataQuality.high,
  status: status,
  createdAt: DateTime(2026, 7, 25),
);
