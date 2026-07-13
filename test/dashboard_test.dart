import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/dashboard/dashboard_data.dart';
import 'package:goat_app/features/dashboard/dashboard_page.dart';

DashboardData _dashboard({
  double target = 2000,
  bool showAiTip = true,
  bool withMeals = true,
}) {
  return DashboardData(
    businessDate: '2026-07-13',
    isToday: true,
    caloriesIn: 860,
    caloriesBurn: 320,
    caloriesTarget: target,
    macros: const [
      DashboardMacro(label: 'PRO', current: 80, target: 150),
      DashboardMacro(label: 'CHO', current: 110, target: 200),
      DashboardMacro(label: 'FAT', current: 30, target: 60),
    ],
    meals: [
      DashboardMealSummary(
        mealType: '早餐',
        title: '早餐',
        calories: withMeals ? 420 : 0,
        foodNames: withMeals ? const ['燕麦', '鸡蛋', '牛奶'] : const [],
        moreCount: withMeals ? 2 : 0,
        isEmpty: !withMeals,
      ),
      const DashboardMealSummary(
        mealType: '午餐',
        title: '午餐',
        calories: 0,
        foodNames: [],
        moreCount: 0,
        isEmpty: true,
      ),
      const DashboardMealSummary(
        mealType: '晚餐',
        title: '晚餐',
        calories: 0,
        foodNames: [],
        moreCount: 0,
        isEmpty: true,
      ),
      const DashboardMealSummary(
        mealType: '加餐',
        title: '加餐',
        calories: 0,
        foodNames: [],
        moreCount: 0,
        isEmpty: true,
      ),
    ],
    activity: const DashboardActivitySummary(
      exerciseCalories: 320,
      exerciseCount: 2,
      exerciseNames: ['跑步'],
      trainingSessionCount: 1,
      trainingExerciseCount: 3,
      trainingNames: ['上肢训练'],
    ),
    waterMl: 1850,
    waterGoalMl: 2500,
    weightKg: 71.25,
    showAiTip: showAiTip,
    isAiTipLoading: false,
    aiTip: '今天记得补充水分',
  );
}

Widget _pumpDashboard(
  WidgetTester tester, {
  required DashboardData data,
  required List<String> events,
}) {
  return DashboardPage(
    data: data,
    onOpenAssistant: () => events.add('assistant'),
    onOpenSettings: () => events.add('settings'),
    onRecordDiet: () => events.add('diet'),
    onRecordWater: () => events.add('water'),
    onRecordExercise: () => events.add('exercise'),
    onRecordWeight: () => events.add('weight'),
    onOpenMeal: events.add,
    onAddMeal: (meal) => events.add('add:$meal'),
    onOpenTraining: () => events.add('training'),
    onRefreshAi: () => events.add('ai'),
  );
}

void main() {
  testWidgets('dashboard shows calorie hierarchy and macros', (tester) async {
    final events = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _pumpDashboard(tester, data: _dashboard(), events: events),
      ),
    );

    expect(find.text('今日热量概览'), findsOneWidget);
    expect(find.text('860'), findsWidgets);
    expect(find.text('净摄入'), findsOneWidget);
    expect(find.text('目标'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.text('CHO'), findsOneWidget);
    expect(find.text('FAT'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(find.text('71.25 kg'), findsOneWidget);
  });

  testWidgets('dashboard target zero remains stable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _pumpDashboard(tester, data: _dashboard(target: 0), events: []),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('dashboard quick actions call real entry callbacks', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _pumpDashboard(tester, data: _dashboard(), events: events),
      ),
    );

    for (final label in ['记录饮食', '记录饮水', '记录运动', '记录体重']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    expect(events, containsAll(['diet', 'water', 'exercise', 'weight']));
  });

  testWidgets('all meal add buttons keep their meal type', (tester) async {
    final events = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _pumpDashboard(tester, data: _dashboard(), events: events),
      ),
    );
    for (final meal in ['早餐', '午餐', '晚餐', '加餐']) {
      await tester.ensureVisible(find.byTooltip('添加$meal'));
      await tester.tap(find.byTooltip('添加$meal'));
      await tester.pump();
    }
    expect(events, containsAll(['add:早餐', 'add:午餐', 'add:晚餐', 'add:加餐']));
  });

  testWidgets('meal cards show empty state and truncate long summaries', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _pumpDashboard(tester, data: _dashboard(), events: events),
      ),
    );
    expect(find.text('暂无记录'), findsNWidgets(3));
    expect(find.text('另有 2 项'), findsOneWidget);
    final breakfastCard = find.byKey(const ValueKey('dashboard-meal-早餐'));
    await tester.ensureVisible(breakfastCard);
    await tester.tap(breakfastCard);
    expect(events, contains('早餐'));
  });

  testWidgets('dashboard hides AI card without a key', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _pumpDashboard(
          tester,
          data: _dashboard(showAiTip: false),
          events: [],
        ),
      ),
    );
    expect(find.text('今日建议'), findsNothing);
    expect(find.text('今日饮食'), findsOneWidget);
  });

  testWidgets('dashboard remains usable with large text on a small surface', (
    tester,
  ) async {
    final events = <String>[];
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: MaterialApp(
          home: _pumpDashboard(tester, data: _dashboard(), events: events),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('快捷记录'), findsOneWidget);
    expect(find.text('记录饮水'), findsOneWidget);
  });
}
