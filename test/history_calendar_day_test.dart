import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/history/widgets/history_calendar_day.dart';

void main() {
  testWidgets('training ring surrounds the date and record check sits below', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 52,
            height: 60,
            child: HistoryCalendarDay(
              day: 21,
              dateKey: '2026-07-21',
              isSelected: false,
              hasRecord: true,
              hasTraining: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final date = find.byKey(const Key('history-calendar-date-2026-07-21'));
    final check = find.byKey(const Key('history-calendar-check-2026-07-21'));
    final decoration =
        tester.widget<Container>(date).decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.border, isNotNull);
    expect(tester.getCenter(check).dy, greaterThan(tester.getCenter(date).dy));
  });
}
