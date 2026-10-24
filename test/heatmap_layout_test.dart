import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heatmap_q/heatmap_q.dart';

void main() {
  group('HeatmapLayout', () {
    const layout = HeatmapLayout(
      rowCount: 2,
      columnCount: 2,
      size: Size(22, 22),
      spacing: 2,
    );

    test('computes cell size from the available space minus spacing', () {
      expect(layout.cellWidth, 10);
      expect(layout.cellHeight, 10);
    });

    test('rectAt places cells with spacing between them', () {
      expect(layout.rectAt(0, 0), const Rect.fromLTWH(0, 0, 10, 10));
      expect(layout.rectAt(0, 1), const Rect.fromLTWH(12, 0, 10, 10));
      expect(layout.rectAt(1, 0), const Rect.fromLTWH(0, 12, 10, 10));
    });

    test('cellAt maps a position back to (row, col)', () {
      expect(layout.cellAt(const Offset(5, 5)), (0, 0));
      expect(layout.cellAt(const Offset(15, 5)), (0, 1));
      expect(layout.cellAt(const Offset(5, 15)), (1, 0));
    });

    test('cellAt returns null for positions in the gap between cells', () {
      expect(layout.cellAt(const Offset(10.5, 5)), isNull);
    });

    test('cellAt returns null outside the grid', () {
      expect(layout.cellAt(const Offset(-1, 0)), isNull);
      expect(layout.cellAt(const Offset(100, 100)), isNull);
    });

    test('an empty grid never reports a hit', () {
      const empty = HeatmapLayout(
        rowCount: 0,
        columnCount: 0,
        size: Size(10, 10),
        spacing: 2,
      );
      expect(empty.cellAt(const Offset(1, 1)), isNull);
    });

    test('contentSize matches size when cell size is derived, not fixed', () {
      expect(layout.contentSize, const Size(22, 22));
    });
  });

  group('HeatmapLayout with an explicit cell size', () {
    const layout = HeatmapLayout(
      rowCount: 2,
      columnCount: 5,
      spacing: 3,
      cellWidth: 12,
      cellHeight: 12,
    );

    test('cellWidth/cellHeight use the explicit value, not a derived one', () {
      expect(layout.cellWidth, 12);
      expect(layout.cellHeight, 12);
    });

    test('contentSize is derived from the fixed cell size, independent of any box', () {
      // 5 columns of 12 + 4 gaps of 3 = 72; 2 rows of 12 + 1 gap of 3 = 27.
      expect(layout.contentSize, const Size(72, 27));
    });

    test('an explicit cell size on only one axis still derives the other from size', () {
      const mixed = HeatmapLayout(
        rowCount: 2,
        columnCount: 2,
        spacing: 0,
        size: Size(999, 40), // width irrelevant — cellWidth is explicit
        cellWidth: 20,
      );
      expect(mixed.cellWidth, 20);
      expect(mixed.cellHeight, 20); // derived: 40 / 2 rows
      expect(mixed.contentSize, const Size(40, 40));
    });

    test('an unbounded size on the explicit-cellWidth axis is fine — it is never read', () {
      const layout = HeatmapLayout(
        rowCount: 2,
        columnCount: 2,
        spacing: 0,
        size: Size(double.infinity, 40),
        cellWidth: 20,
      );
      expect(layout.cellWidth, 20);
      expect(layout.cellHeight, 20);
    });
  });

  group('HeatmapLayout with an unbounded size and no explicit cell size', () {
    test('cellWidth asserts with a clear message instead of returning infinity', () {
      const layout = HeatmapLayout(
        rowCount: 2,
        columnCount: 2,
        spacing: 0,
        size: Size(double.infinity, 40),
      );
      expect(() => layout.cellWidth, throwsA(isA<AssertionError>()));
    });

    test('cellHeight asserts with a clear message instead of returning infinity', () {
      const layout = HeatmapLayout(
        rowCount: 2,
        columnCount: 2,
        spacing: 0,
        size: Size(40, double.infinity),
      );
      expect(() => layout.cellHeight, throwsA(isA<AssertionError>()));
    });
  });
}
