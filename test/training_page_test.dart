import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/training/models/training_page_view_model.dart';
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
    var startCount = 0;
    var pplCount = 0;
    var fullBodyCount = 0;
    var historyCount = 0;
    var templateCount = 0;
    await tester.pumpWidget(
      buildPage(
        onStartTraining: () => startCount++,
        onPpl: () => pplCount++,
        onFullBody: () => fullBodyCount++,
        onHistory: () => historyCount++,
        onTemplates: () => templateCount++,
      ),
    );

    await tester.tap(find.text('开始一次新训练'));
    await tester.tap(find.text('PPL-推力日'));
    await tester.tap(find.text('全身循环燃脂'));
    await tester.tap(find.text('查看训练历史'));
    await tester.tap(find.text('创建 / 管理训练方案'));

    expect(startCount, 1);
    expect(pplCount, 1);
    expect(fullBodyCount, 1);
    expect(historyCount, 1);
    expect(templateCount, 1);
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
