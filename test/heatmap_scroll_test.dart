import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heatmap_q/heatmap_q.dart';

void main() {
  testWidgets('scrollHeatmapCellIntoView centers the target cell in the viewport', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: controller,
              child: const SizedBox(width: 1000, height: 50),
            ),
          ),
        ),
      ),
    );

    const layout = HeatmapLayout(rowCount: 1, columnCount: 50, spacing: 0, cellWidth: 20, cellHeight: 20);

    // Cell 40 spans [800, 820); centering it in a 200-wide viewport wants
    // offset 800 - (200 - 20) / 2 = 710.
    unawaited(
      scrollHeatmapCellIntoView(controller: controller, layout: layout, row: 0, col: 40),
    );
    await tester.pumpAndSettle();

    expect(controller.offset, 710);
  });

  testWidgets('scrollHeatmapCellIntoView clamps to the scrollable range', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: controller,
              child: const SizedBox(width: 1000, height: 50),
            ),
          ),
        ),
      ),
    );

    const layout = HeatmapLayout(rowCount: 1, columnCount: 50, spacing: 0, cellWidth: 20, cellHeight: 20);

    // Cell 0 is at the very start — centering it would want a negative
    // offset, which must clamp to 0.
    unawaited(
      scrollHeatmapCellIntoView(controller: controller, layout: layout, row: 0, col: 0),
    );
    await tester.pumpAndSettle();

    expect(controller.offset, 0);
  });

  testWidgets('does nothing when the controller has no attached scroll position', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    const layout = HeatmapLayout(rowCount: 1, columnCount: 10, spacing: 0, cellWidth: 20, cellHeight: 20);

    await expectLater(
      scrollHeatmapCellIntoView(controller: controller, layout: layout, row: 0, col: 0),
      completes,
    );
  });
}
