import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/training/training_page.dart';
import 'package:goat_app/models/training.dart';

void main() {
  Widget buildPage({
    List<TrainingSession> sessions = const [],
    ValueChanged<String>? onTemplate,
  }) => MaterialApp(
    home: TrainingPage(
      sessions: sessions,
      businessDate: '2026-07-14',
      onStartTraining: () {},
      onAddRecord: () {},
      onAddTemplate: () {},
      onViewHistory: () {},
      onSelectTemplate: (template) => onTemplate?.call(template.title),
      onOpenSession: (_) {},
    ),
  );

  testWidgets('empty training state remains a complete usable page', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());

    expect(find.byKey(const Key('training-dashboard-card')), findsOneWidget);
    expect(find.text('快捷操作'), findsOneWidget);
    expect(find.text('分类模板'), findsOneWidget);
    expect(find.text('胸'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -850));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('training-empty-state'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('training-plan-section'), skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('开始你的第一节训练', skipOffstage: false), findsOneWidget);
  });

  testWidgets('recent sessions and legacy training summary are visible', (
    tester,
  ) async {
    final session = TrainingSession(
      id: 'session-1',
      name: '推日训练',
      date: '2026-07-14',
      exercises: [
        TrainingExercise(
          exerciseName: '杠铃卧推',
          bodyPart: '胸部',
          sets: [SetRecord(weight: 60, reps: 8)],
        ),
      ],
    );
    await tester.pumpWidget(buildPage(sessions: [session]));

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -850));
    await tester.pumpAndSettle();

    expect(find.text('推日训练', skipOffstage: false), findsWidgets);
    expect(
      find.textContaining('已保留 1 条训练结构', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('training-empty-state'), skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('template selection starts the training flow with a body part', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(buildPage(onTemplate: (value) => selected = value));

    await tester.tap(find.text('胸').first);
    expect(selected, '胸');
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
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
