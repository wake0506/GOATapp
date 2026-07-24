import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/training/models/training_template.dart';
import 'package:goat_app/features/training/widgets/rest_prescription_sheet.dart';
import 'package:goat_app/features/training/widgets/rest_timer_card.dart';
import 'package:goat_app/features/training/widgets/training_rest_summary.dart';
import 'package:goat_app/features/training/widgets/training_template_manager_sheet.dart';
import 'package:goat_app/models/rest_prescription.dart';
import 'package:goat_app/models/training.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const recommendation = RestRecommendation(
    recommendedSeconds: 210,
    plannedSeconds: 210,
    baseSeconds: 150,
    modifierSeconds: 60,
    source: RestSource.exerciseProfile,
    reasonCodes: [RestReasonCode.standardCompound, RestReasonCode.rirZero],
    transitionType: RestTransitionType.betweenSets,
  );

  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    testWidgets('rest timer is scroll-safe at ${size.width}x${size.height}', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Color(0xFFF4F5F7),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: RestTimerCard(
                  remainingSeconds: 182,
                  totalSeconds: 210,
                  exerciseName: '杠铃平板卧推',
                  nextSetLabel: '80.0 kg × 8',
                  recommendation: recommendation,
                  onStartNextSet: _noop,
                  onSkipRest: _noop,
                  onExtend: _noop,
                  onChangeExerciseRest: _noop,
                  onRestoreRecommended: _noop,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rest-timer-card')), findsOneWidget);
      expect(find.text('GOAT 推荐 · 03:30'), findsOneWidget);
      expect(find.text('本组接近力竭，已延长 1:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rest setting sheet saves fixed mode and remains keyboard-safe', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(360, 800));
    RestPrescription? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  result = await RestPrescriptionSheet.show(
                    context,
                    exerciseId: 'barbell_flat_bench_press',
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('当前基础建议 2:30\n训练中会根据组类型、RIR 与力竭情况动态调整'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rest-mode-fixed')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rest-fixed-seconds')), '180');
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('rest-prescription-save')));
    await tester.pumpAndSettle();
    expect(result?.mode, RestPrescriptionMode.fixed);
    expect(result?.fixedSeconds, 180);
  });

  testWidgets('training detail separates planned, actual, and legacy unknown', (
    tester,
  ) async {
    TrainingSession session({bool legacy = false}) => TrainingSession(
      id: legacy ? 'legacy' : 'v2',
      name: 'Push',
      date: '2026-07-24',
      exercises: [
        TrainingExercise(
          exerciseName: '卧推',
          bodyPart: '胸部',
          sets: [
            SetRecord(
              plannedRestSeconds: legacy ? null : 150,
              actualRestSeconds: legacy ? null : 132,
            ),
            SetRecord(
              plannedRestSeconds: legacy ? null : 180,
              actualRestSeconds: legacy ? null : 168,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TrainingRestSummary(session: session()),
              TrainingRestSummary(session: session(legacy: true)),
            ],
          ),
        ),
      ),
    );
    expect(find.text('2:45'), findsOneWidget);
    expect(find.text('2:30'), findsOneWidget);
    expect(find.text('--'), findsNWidgets(2));
  });

  testWidgets('training plan exposes a compact per-exercise rest setting', (
    tester,
  ) async {
    final bench = exerciseCatalog.firstWhere(
      (exercise) => exercise.id == 'barbell_flat_bench_press',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingTemplateEditorSheet(
            catalog: exerciseCatalog,
            existing: TrainingTemplate(
              id: 'push',
              name: 'Push',
              exerciseIds: [bench.id],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final entry = find.byKey(Key('template-rest-${bench.id}'));
    expect(entry, findsOneWidget);
    expect(find.text('GOAT休息 2:30 ›'), findsOneWidget);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rest-prescription-sheet')), findsOneWidget);
  });
}

void _noop() {}
