import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heatmap_q/heatmap_q.dart';

void main() {
  testWidgets('renders without error inside a bounded box', (tester) async {
    final grid = HeatmapGrid<int>.dense([
      [1, 2],
      [3, 4],
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 100,
          height: 100,
          child: Heatmap<int>(
            grid: grid,
            colorResolver: HeatmapColorResolver<int>.palette(
              colors: const [Colors.black, Colors.white],
              value: (v) => v,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('onCellTap reports the (row, col) and data that was tapped', (tester) async {
    final grid = HeatmapGrid<int>.dense([
      [1, 2],
      [3, 4],
    ]);

    HeatmapCellContext<int>? tapped;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 100,
            height: 100,
            child: Heatmap<int>(
              grid: grid,
              colorResolver: HeatmapColorResolver<int>.builder((cell) => Colors.black),
              spacing: 0,
              onCellTap: (cell) => tapped = cell,
            ),
          ),
        ),
      ),
    );

    // Grid is 2x2 over a 100x100 box with no spacing -> each cell is 50x50.
    // Tap inside the bottom-right cell (row 1, col 1), value 4.
    await tester.tapAt(const Offset(75, 75));
    await tester.pump();

    expect(tapped, isNotNull);
    expect(tapped!.row, 1);
    expect(tapped!.col, 1);
    expect(tapped!.data, 4);
  });

  testWidgets('does not repaint the widget tree when driven by an external Listenable',
      (tester) async {
    final grid = HeatmapGrid<int>.dense([
      [1, 2],
    ]);
    final repaint = ValueNotifier<double>(0);
    var buildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            buildCount++;
            return SizedBox(
              width: 100,
              height: 50,
              child: Heatmap<int>(
                grid: grid,
                colorResolver: HeatmapColorResolver<int>.builder((cell) => Colors.black),
                repaint: repaint,
              ),
            );
          },
        ),
      ),
    );

    expect(buildCount, 1);

    // Driving the painter through `repaint` should never trigger a widget
    // rebuild — that's the whole point of the mechanism.
    repaint.value = 1;
    await tester.pump();

    expect(buildCount, 1);
  });

  testWidgets('Heatmap.calendar builds a working calendar grid without spelling out the type',
      (tester) async {
    HeatmapCellContext<HeatmapCalendarCell<int>>? tapped;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 100,
            height: 100,
            child: Heatmap.calendar<int>(
              start: DateTime(2024, 1, 1),
              end: DateTime(2024, 1, 1),
              valueForDay: (day) => 5,
              colorResolver: HeatmapColorResolver.builder((cell) => Colors.black),
              onCellTap: (cell) => tapped = cell,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);

    // Jan 1 2024 is a Monday -> row 0, col 0 with the default firstDayOfWeek.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();

    expect(tapped, isNotNull);
    expect(tapped!.data.value, 5);
    expect(tapped!.data.date, DateTime(2024, 1, 1));
  });

  testWidgets('rowLabelBuilder/columnLabelBuilder position labels against the grid, skipping nulls',
      (tester) async {
    final grid = HeatmapGrid<int>.dense([
      [1, 2],
      [3, 4],
    ]);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 140,
            height: 130,
            child: Heatmap<int>(
              grid: grid,
              spacing: 0,
              colorResolver: HeatmapColorResolver<int>.builder((cell) => Colors.black),
              rowLabelWidth: 20,
              columnLabelHeight: 10,
              rowLabelBuilder: (row) => row == 1 ? Text('R$row') : null,
              columnLabelBuilder: (col) => Text('C$col'),
            ),
          ),
        ),
      ),
    );

    // Only row 1 has a label; both columns do.
    expect(find.text('R0'), findsNothing);
    expect(find.text('R1'), findsOneWidget);
    expect(find.text('C0'), findsOneWidget);
    expect(find.text('C1'), findsOneWidget);

    // Column labels sit above the grid, offset past the reserved row-label
    // width; row labels sit left of the grid, offset past the column-label
    // height.
    final c0Position = tester.getTopLeft(find.text('C0'));
    expect(c0Position.dx, greaterThanOrEqualTo(20));
    expect(c0Position.dy, lessThan(10));

    final r1Position = tester.getTopLeft(find.text('R1'));
    expect(r1Position.dx, lessThan(20));
    expect(r1Position.dy, greaterThanOrEqualTo(10));
  });

  testWidgets('a fixed cellWidth/cellHeight reports the grid\'s real size, not the viewport\'s',
      (tester) async {
    final grid = HeatmapGrid<int>.dense([
      List.generate(20, (i) => i),
    ]);

    const heatmapKey = Key('heatmap');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 100, // far narrower than the grid's real width
          height: 20,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Heatmap<int>(
              key: heatmapKey,
              grid: grid,
              spacing: 0,
              cellWidth: 10,
              cellHeight: 10,
              colorResolver: HeatmapColorResolver<int>.builder((cell) => Colors.black),
            ),
          ),
        ),
      ),
    );

    // 20 columns * 10px = 200 — wider than the 100px viewport, proving this
    // composes with an ordinary scroll view instead of shrinking to fit.
    final paintSize = tester.getSize(
      find.descendant(of: find.byKey(heatmapKey), matching: find.byType(CustomPaint)),
    );
    expect(paintSize.width, 200);
    expect(tester.takeException(), isNull);
  });
}
