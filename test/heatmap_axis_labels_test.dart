import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heatmap_q/heatmap_q.dart';

void main() {
  testWidgets('HeatmapRowLabels positions labels against cellHeight, skipping nulls', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: HeatmapRowLabels(
            rowCount: 3,
            cellHeight: 10,
            spacing: 2,
            columnLabelHeight: 5,
            labelBuilder: (row) => row == 1 ? null : Text('R$row'),
          ),
        ),
      ),
    );

    expect(find.text('R0'), findsOneWidget);
    expect(find.text('R1'), findsNothing);
    expect(find.text('R2'), findsOneWidget);

    // Row 0 top = columnLabelHeight (5) + rectAt(0,0).top (0) = 5.
    expect(tester.getTopLeft(find.text('R0')).dy, 5);
    // Row 2 top = 5 + (2 * (10 + 2)) = 29.
    expect(tester.getTopLeft(find.text('R2')).dy, 29);

    final box = tester.renderObject<RenderBox>(find.byType(HeatmapRowLabels));
    // height = columnLabelHeight + (3*10 + 2*2) = 5 + 34 = 39.
    expect(box.size.height, 39);
  });

  testWidgets('HeatmapColumnLabels positions labels against cellWidth, skipping nulls', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: HeatmapColumnLabels(
            columnCount: 3,
            cellWidth: 10,
            spacing: 2,
            rowLabelWidth: 5,
            labelBuilder: (col) => col == 1 ? null : Text('C$col'),
          ),
        ),
      ),
    );

    expect(find.text('C0'), findsOneWidget);
    expect(find.text('C1'), findsNothing);
    expect(find.text('C2'), findsOneWidget);

    expect(tester.getTopLeft(find.text('C0')).dx, 5);
    expect(tester.getTopLeft(find.text('C2')).dx, 29);

    final box = tester.renderObject<RenderBox>(find.byType(HeatmapColumnLabels));
    expect(box.size.width, 39);
  });
}
