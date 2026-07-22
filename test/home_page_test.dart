import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/home/home_page.dart';
import 'package:goat_app/features/analytics/models/weight_trend.dart';
import 'package:goat_app/features/home/widgets/macro_half_ring.dart';
import 'package:goat_app/models/consumed_record.dart';
import 'package:goat_app/models/daily_macro_stats.dart';
import 'package:goat_app/widgets/goat_page_header.dart';

void main() {
  Widget buildHome({
    DailyMacroStats? stats,
    double targetKcal = 2000,
    double weight = 70.25,
    double? previousWeight = 70.45,
    int waterMl = 1200,
    List<ConsumedRecord> consumed = const [],
    VoidCallback? onEditTarget,
    VoidCallback? onQuickWater,
    VoidCallback? onOpenWater,
    VoidCallback? onOpenWeight,
    ValueChanged<String>? onAddMeal,
    ValueChanged<String>? onVoiceMeal,
    VoidCallback? onTraining,
    WeightTrend? weightTrend,
  }) {
    return MaterialApp(
      home: HomePage(
        businessDate: '2026-07-14',
        isToday: true,
        stats:
            stats ??
            DailyMacroStats(kcalIn: 1620, p: 120, c: 180, f: 45, burn: 320),
        targetKcal: targetKcal,
        targetProtein: 150,
        targetCarbs: 250,
        targetFat: 60,
        waterMl: waterMl,
        weight: weight,
        previousWeight: previousWeight,
        consumed: consumed,
        aiContent: '',
        isAiLoading: false,
        showAiCard: true,
        onEditTarget: onEditTarget ?? () {},
        onRequestAiAdvice: () {},
        onDismissAi: () {},
        onQuickAddWater: onQuickWater ?? () {},
        onOpenWater: onOpenWater ?? () {},
        onOpenWeight: onOpenWeight ?? () {},
        onOpenMeal: (_) {},
        onAddMeal: onAddMeal ?? (_) {},
        onVoiceMeal: onVoiceMeal ?? (_) {},
        onOpenTraining: onTraining ?? () {},
        onAddExercise: () {},
        weightTrend: weightTrend,
      ),
    );
  }

  testWidgets(
    'hero keeps net intake as the primary value and three macro rings',
    (tester) async {
      await tester.pumpWidget(buildHome());

      expect(find.byKey(const Key('home-hero-card')), findsOneWidget);
      expect(find.text('净摄入'), findsOneWidget);
      expect(find.text('1300'), findsOneWidget);
      expect(find.byType(MacroHalfRing), findsNWidgets(3));
      expect(find.text('PRO'), findsOneWidget);
      expect(find.text('CHO'), findsOneWidget);
      expect(find.text('FAT'), findsOneWidget);
    },
  );

  testWidgets(
    'home weight card keeps current weight primary and trend secondary',
    (tester) async {
      await tester.pumpWidget(
        buildHome(
          weightTrend: WeightTrend(
            anchorDate: DateTime(2026, 7, 14),
            windowDays: 7,
            readingCount: 7,
            dataQuality: WeightTrendDataQuality.complete,
            sevenDayAverageKg: 71.48,
            change7dKg: -0.35,
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains('70.25'),
        ),
        findsOneWidget,
      );
      expect(find.text('趋势 71.48 kg'), findsOneWidget);
      expect(find.text('近7天 -0.35 kg'), findsOneWidget);
    },
  );

  testWidgets('home weight trend explains unavailable partial states', (
    tester,
  ) async {
    Future<void> pumpTrend(WeightTrend trend) =>
        tester.pumpWidget(buildHome(weightTrend: trend));

    await pumpTrend(
      WeightTrend(
        anchorDate: DateTime(2026, 7, 14),
        windowDays: 7,
        readingCount: 0,
        dataQuality: WeightTrendDataQuality.unavailable,
      ),
    );
    expect(find.text('暂无趋势数据'), findsOneWidget);

    await pumpTrend(
      WeightTrend(
        anchorDate: DateTime(2026, 7, 14),
        windowDays: 7,
        readingCount: 1,
        dataQuality: WeightTrendDataQuality.singleReading,
        sevenDayAverageKg: 71.2,
      ),
    );
    expect(find.text('数据仍不足'), findsOneWidget);

    await pumpTrend(
      WeightTrend(
        anchorDate: DateTime(2026, 7, 14),
        windowDays: 7,
        readingCount: 4,
        dataQuality: WeightTrendDataQuality.partial,
        sevenDayAverageKg: 71.3,
      ),
    );
    expect(find.text('数据积累中'), findsOneWidget);
  });

  testWidgets('home uses the shared GOAT page header typography', (
    tester,
  ) async {
    await tester.pumpWidget(buildHome());

    final header = tester.widget<GoatPageHeader>(find.byType(GoatPageHeader));
    expect(header.title, 'G O A T');
    expect(GoatHeaderTypography.pageTitle.letterSpacing, 4);
  });

  testWidgets('water card has a stable layout for every water state', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final viewport in const [Size(320, 640), Size(360, 800)]) {
      await tester.binding.setSurfaceSize(viewport);
      for (final waterMl in [0, 250, 2000]) {
        await tester.pumpWidget(buildHome(waterMl: waterMl));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byKey(const Key('home-metrics-row')),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byKey(const Key('home-metrics-row')), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('$waterMl / 2000 ml'),
          ),
          findsOneWidget,
        );
        expect(find.text('+250ml'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('responsive viewports keep the second meal row scrollable', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final viewport in const [
      Size(360, 800),
      Size(390, 844),
      Size(412, 915),
    ]) {
      await tester.binding.setSurfaceSize(viewport);
      await tester.pumpWidget(buildHome(waterMl: 0));
      await tester.pumpAndSettle();

      final firstViewport = tester.getRect(
        find.byKey(const Key('home-first-viewport-section')),
      );
      expect(firstViewport.bottom, greaterThan(0));
      final secondRow = find.byKey(const Key('home-meals-second-row'));
      await tester.scrollUntilVisible(
        secondRow,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('home-meals-second-row')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('zero goal remains safe and target editor stays reachable', (
    tester,
  ) async {
    var editCount = 0;
    await tester.pumpWidget(
      buildHome(targetKcal: 0, onEditTarget: () => editCount++),
    );

    expect(find.byTooltip('编辑今日目标'), findsOneWidget);
    await tester.tap(find.byTooltip('编辑今日目标').first);
    expect(editCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'water quick action, detail and weight actions use real page callbacks',
    (tester) async {
      var quickWaterCount = 0;
      var openWaterCount = 0;
      var openWeightCount = 0;
      await tester.pumpWidget(
        buildHome(
          onQuickWater: () => quickWaterCount++,
          onOpenWater: () => openWaterCount++,
          onOpenWeight: () => openWeightCount++,
        ),
      );

      await tester.tap(find.text('+250ml'));
      await tester.tap(find.text('饮水记录'));
      await tester.tap(find.text('体重记录'));

      expect(quickWaterCount, 1);
      expect(openWaterCount, 1);
      expect(openWeightCount, 1);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains('70.25'),
        ),
        findsOneWidget,
      );
      expect(find.text('↓ 0.20 kg'), findsOneWidget);
    },
  );

  testWidgets(
    'all meal cards preserve manual and voice entries with their meal type',
    (tester) async {
      final manualMeals = <String>[];
      final voiceMeals = <String>[];
      await tester.pumpWidget(
        buildHome(onAddMeal: manualMeals.add, onVoiceMeal: voiceMeals.add),
      );

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -460));
      await tester.pumpAndSettle();
      for (final meal in ['早餐', '午餐']) {
        await tester.tap(find.byTooltip('$meal添加食物').first);
        await tester.tap(find.byTooltip('$meal语音录入').first);
      }
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -280));
      await tester.pumpAndSettle();
      for (final meal in ['晚餐', '加餐']) {
        await tester.tap(find.byTooltip('$meal添加食物').first);
        await tester.tap(find.byTooltip('$meal语音录入').first);
      }

      expect(manualMeals, ['早餐', '午餐', '晚餐', '加餐']);
      expect(voiceMeals, ['早餐', '午餐', '晚餐', '加餐']);
    },
  );

  testWidgets(
    'meal macro summary and training link remain visible on the real home page',
    (tester) async {
      var trainingCount = 0;
      final breakfast = ConsumedRecord(
        id: 'meal-1',
        name: '燕麦',
        p: 12,
        c: 45,
        f: 8,
        kcal: 320,
        mealType: '早餐',
        date: '2026-07-14',
      );
      await tester.pumpWidget(
        buildHome(consumed: [breakfast], onTraining: () => trainingCount++),
      );

      expect(
        find.text('碳 45g · 蛋 12g · 脂 8g', skipOffstage: false),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('同步自训练看板'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('同步自训练看板'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('同步自训练看板'));
      expect(trainingCount, 1);
    },
  );

  testWidgets('small screen and enlarged text avoid critical overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.5),
        ),
        child: buildHome(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -620));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
