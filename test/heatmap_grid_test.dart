import 'package:flutter_test/flutter_test.dart';
import 'package:heatmap_q/heatmap_q.dart';

void main() {
  group('DenseHeatmapGrid', () {
    test('reports dimensions and returns cell values', () {
      final grid = HeatmapGrid<int>.dense([
        [1, 2, 3],
        [4, 5, 6],
      ]);

      expect(grid.rowCount, 2);
      expect(grid.columnCount, 3);
      expect(grid.cellAt(0, 0), 1);
      expect(grid.cellAt(1, 2), 6);
    });

    test('returns null outside bounds', () {
      final grid = HeatmapGrid<int>.dense([
        [1, 2],
      ]);

      expect(grid.cellAt(-1, 0), isNull);
      expect(grid.cellAt(0, 2), isNull);
      expect(grid.cellAt(5, 5), isNull);
    });

    test('supports null cells for missing data', () {
      final grid = HeatmapGrid<int>.dense([
        [1, null, 3],
      ]);

      expect(grid.cellAt(0, 1), isNull);
    });

    test('empty input produces a zero-sized grid', () {
      final grid = HeatmapGrid<int>.dense(const []);

      expect(grid.rowCount, 0);
      expect(grid.columnCount, 0);
    });
  });

  group('SparseHeatmapGrid', () {
    test('returns values only for populated coordinates', () {
      final grid = HeatmapGrid<double>.sparse(
        rowCount: 3,
        columnCount: 3,
        cells: {
          (0, 0): 1.5,
          (2, 2): 9.9,
        },
      );

      expect(grid.rowCount, 3);
      expect(grid.columnCount, 3);
      expect(grid.cellAt(0, 0), 1.5);
      expect(grid.cellAt(2, 2), 9.9);
      expect(grid.cellAt(1, 1), isNull);
    });
  });

  group('CalendarHeatmapGrid.fromDateRange', () {
    test('has 7 rows and pads to full weeks, cells carry their date', () {
      // 2024-01-01 is a Monday; 2024-01-07 is a Sunday — exactly one week.
      final grid = CalendarHeatmapGrid.fromDateRange<int>(
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 1, 7),
        valueForDay: (day) => day.day,
      );

      expect(grid.rowCount, 7);
      expect(grid.columnCount, 1);
      expect(grid.cellAt(0, 0)?.value, 1); // Monday Jan 1
      expect(grid.cellAt(0, 0)?.date, DateTime(2024, 1, 1));
      expect(grid.cellAt(6, 0)?.value, 7); // Sunday Jan 7
    });

    test('leading padding days before start are empty, not just dateless', () {
      // 2024-01-03 is a Wednesday, so the week starts on Monday Jan 1 —
      // Jan 1 and Jan 2 are structural padding outside the requested range.
      final grid = CalendarHeatmapGrid.fromDateRange<int>(
        start: DateTime(2024, 1, 3),
        end: DateTime(2024, 1, 3),
        valueForDay: (day) => day.day,
      );

      expect(grid.columnCount, 1);
      expect(grid.cellAt(0, 0), isNull); // Jan 1, padding
      expect(grid.cellAt(1, 0), isNull); // Jan 2, padding
      expect(grid.cellAt(2, 0)?.date, DateTime(2024, 1, 3));
      expect(grid.cellAt(2, 0)?.value, 3);
    });

    test('a day valueForDay returns null for is empty like any other grid', () {
      final grid = CalendarHeatmapGrid.fromDateRange<int>(
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 1, 1),
        valueForDay: (day) => null,
      );

      expect(grid.cellAt(0, 0), isNull);
    });

    test('respects a custom firstDayOfWeek', () {
      // With Sunday as the first day, Jan 1 2024 (Monday) is column 0 row 1.
      final grid = CalendarHeatmapGrid.fromDateRange<int>(
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 1, 1),
        valueForDay: (day) => day.day,
        firstDayOfWeek: DateTime.sunday,
      );

      expect(grid.cellAt(0, 0), isNull); // Dec 31, padding Sunday
      expect(grid.cellAt(1, 0)?.date, DateTime(2024, 1, 1));
      expect(grid.cellAt(1, 0)?.value, 1);
    });
  });

  group('monthBoundaryColumns', () {
    test('reports one entry per month, at the column its first week falls in', () {
      // Jan 1 2024 is a Monday, so week columns align exactly with weeks.
      final boundaries = monthBoundaryColumns(
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 3, 31),
      );

      expect(boundaries.map((b) => b.monthStart), [
        DateTime(2024, 1),
        DateTime(2024, 2),
        DateTime(2024, 3),
      ]);
      // Column indices must match where CalendarHeatmapGrid actually puts
      // that date, or a label built from this would misalign with the grid.
      final grid = CalendarHeatmapGrid.fromDateRange<int>(
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 3, 31),
        valueForDay: (day) => day.day,
      );
      for (final boundary in boundaries) {
        final matchingColumn = List.generate(grid.columnCount, (col) => col).firstWhere(
          (col) => List.generate(7, (row) => grid.cellAt(row, col)?.date)
              .contains(boundary.monthStart),
        );
        expect(boundary.column, matchingColumn, reason: '${boundary.monthStart} misaligned');
      }
    });

    test('a range within a single month reports just that one boundary', () {
      final boundaries = monthBoundaryColumns(start: DateTime(2024, 6, 5), end: DateTime(2024, 6, 20));
      expect(boundaries, [(column: 0, monthStart: DateTime(2024, 6))]);
    });
  });
}
