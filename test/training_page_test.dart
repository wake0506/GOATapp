import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/training/models/training_page_view_model.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/features/training/training_page.dart';
import 'package:goat_app/models/training.dart';

void main() {
  Widget buildPage({
    List<TrainingSession> sessions = const [],
    VoidCallback? onStartTraining,
    VoidCallback? onPpl,
    VoidCallback? onFullBody,
    VoidCallback? onHistory,
    VoidCallback? onTemplates,
    VoidCallback? onWeeklyReview,
    VoidCallback? onCoverage,
  }) {
    return MaterialApp(
      home: TrainingPage(
        sessions: sessions,
        businessDate: '2026-07-14',
        onStartTraining: onStartTraining ?? () {},
        onUsePplTemplate: onPpl ?? () {},
        onUseFullBodyTemplate: onFullBody ?? () {},
        onViewHistory: onHistory ?? () {},
        onManageTemplates: onTemplates ?? () {},
        onOpenWeeklyReview: onWeeklyReview,
        onOpenCoverage: onCoverage,
      ),
    );
  }

  testWidgets('empty training page remains complete instead of blank', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());

    expect(find.text('训 练 记 录'), findsOneWidget);
    expect(find.byKey(const Key('training-status-card')), findsOneWidget);
    expect(find.byKey(const Key('training-quick-start-card')), findsOneWidget);
    expect(find.byKey(const Key('training-ai-insight-card')), findsOneWidget);
    expect(find.text('开始一次新训练'), findsOneWidget);
    expect(find.text('我的常用方案'), findsOneWidget);
    expect(find.text('PPL-推力日'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('training-load-card'), skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('最近 7 天暂无足够训练数据', skipOffstage: false), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -380));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('personal-best-card'), skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('暂无记录'), findsNWidgets(3));
  });

  testWidgets('quick start and nested entries use the existing flows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var startCount = 0;
    var pplCount = 0;
    var fullBodyCount = 0;
    var historyCount = 0;
    var templateCount = 0;
    var weeklyReviewCount = 0;
    var coverageCount = 0;
    await tester.pumpWidget(
      buildPage(
        onStartTraining: () => startCount++,
        onPpl: () => pplCount++,
        onFullBody: () => fullBodyCount++,
        onHistory: () => historyCount++,
        onTemplates: () => templateCount++,
        onWeeklyReview: () => weeklyReviewCount++,
        onCoverage: () => coverageCount++,
      ),
    );

    await tester.tap(find.text('开始一次新训练'));
    await tester.tap(find.text('PPL-推力日'));
    await tester.tap(find.text('全身循环燃脂'));
    await tester.ensureVisible(find.text('查看训练历史'));
    await tester.tap(find.text('查看训练历史'));
    await tester.ensureVisible(find.text('创建 / 管理训练方案'));
    await tester.tap(find.text('创建 / 管理训练方案'));
    await tester.ensureVisible(find.text('本周复盘'));
    await tester.tap(find.text('本周复盘'));
    await tester.ensureVisible(find.text('训练覆盖'));
    await tester.tap(find.text('训练覆盖'));

    expect(startCount, 1);
    expect(pplCount, 1);
    expect(fullBodyCount, 1);
    expect(historyCount, 1);
    expect(templateCount, 1);
    expect(weeklyReviewCount, 1);
    expect(coverageCount, 1);
  });

  testWidgets('real sessions feed status, load and personal bests', (
    tester,
  ) async {
    final session = TrainingSession(
      id: 'session-1',
      name: '推力日',
      date: '2026-07-14',
      exercises: [
        TrainingExercise(
          exerciseName: '杠铃卧推',
          bodyPart: '胸部',
          sets: [SetRecord(weight: 80, reps: 6, durationSec: 120)],
        ),
      ],
    );
    await tester.pumpWidget(buildPage(sessions: [session]));

    final viewModel = TrainingPageViewModel.fromSessions(
      sessions: [session],
      businessDate: '2026-07-14',
    );
    expect(viewModel.status.volume, 480);
    expect(viewModel.status.completedSets, 1);
    expect(viewModel.status.durationMinutes, 2);
    expect(viewModel.muscleLoads.first.value, 100);
    expect(viewModel.personalBests.first.weight, 80);
  });

  test('all catalog body parts contribute to the seven-day load summary', () {
    const bodyParts = ['胸部', '背部', '腿部', '肩部', '手臂', '核心', '臀部', '全身/体能'];
    final session = TrainingSession(
      id: 'all-groups',
      name: '全身训练',
      date: '2026-07-14',
      exercises: [
        for (final bodyPart in bodyParts)
          TrainingExercise(
            exerciseName: '$bodyPart动作',
            bodyPart: bodyPart,
            sets: [SetRecord(reps: 10)],
          ),
      ],
    );

    final viewModel = TrainingPageViewModel.fromSessions(
      sessions: [session],
      businessDate: '2026-07-14',
    );

    expect(viewModel.muscleLoads.map((load) => load.label), bodyParts);
    expect(viewModel.muscleLoads.map((load) => load.value), everyElement(100));
  });

  test('dashboard load uses effective sets and keeps full body isolated', () {
    final completedAt = DateTime(2026, 7, 14);
    final session = TrainingSession(
      id: 'effective-ui',
      name: '有效组',
      date: '2026-07-14',
      exercises: [
        TrainingExercise(
          exerciseId: 'chest',
          exerciseName: 'Press',
          bodyPart: 'chest',
          sets: [
            SetRecord(
              reps: 10,
              setType: TrainingSetType.warmup,
              completedAt: completedAt,
            ),
            SetRecord(
              reps: 10,
              setType: TrainingSetType.working,
              completedAt: completedAt,
            ),
          ],
        ),
        TrainingExercise(
          exerciseId: 'full',
          exerciseName: 'Burpee',
          bodyPart: 'fullBody',
          sets: [
            SetRecord(
              reps: 10,
              setType: TrainingSetType.working,
              completedAt: completedAt,
            ),
          ],
        ),
      ],
    );
    final viewModel = TrainingPageViewModel.fromSessions(
      sessions: [session],
      businessDate: '2026-07-14',
    );
    expect(viewModel.muscleLoads.map((load) => load.label), ['胸部', '全身/体能']);
    expect(viewModel.muscleLoads.map((load) => load.effectiveSets), [1, 1]);
  });

  testWidgets('legacy effective sets remain visible with a light explanation', (
    tester,
  ) async {
    final legacy = TrainingSession(
      id: 'legacy-ui',
      name: 'Legacy',
      date: '2026-07-14',
      exercises: [
        TrainingExercise(
          exerciseName: 'Legacy press',
          bodyPart: 'chest',
          sets: [SetRecord(reps: 10)],
        ),
      ],
    );
    await tester.pumpWidget(buildPage(sessions: [legacy]));
    await tester.scrollUntilVisible(
      find.byKey(const Key('training-load-card')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('包含部分历史训练记录'), findsOneWidget);
    await tester.tap(find.byKey(const Key('effective-sets-info')));
    await tester.pumpAndSettle();
    expect(find.text('有效训练组'), findsOneWidget);
    expect(find.textContaining('不包含热身'), findsOneWidget);
  });

  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    testWidgets('effective set area fits ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildPage());
      await tester.scrollUntilVisible(
        find.byKey(const Key('training-load-card')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('training-load-card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('small screen and enlarged text do not overflow', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.5),
        ),
        child: buildPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
