import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heatmap_q/heatmap_q.dart';

HeatmapCellContext<int> _context(int data, {int row = 0, int col = 0}) =>
    (data: data, row: row, col: col);

num _identity(int v) => v;

void main() {
  // Plain Color constants, not MaterialColor swatches (Colors.grey etc.) —
  // ColorSwatch overrides == to also compare its swatch map, so it never
  // equals the plain Color instances these functions actually return.
  const low = Color(0xFF000000);
  const mid = Color(0xFF808080);
  const high = Color(0xFFFFFFFF);
  const colors = [low, mid, high];

  group('interpolatePalette', () {
    test('returns the first color at t=0 and last at t=1', () {
      expect(interpolatePalette(colors, 0), low);
      expect(interpolatePalette(colors, 1), high);
    });

    test('single-color palettes always return that color', () {
      expect(interpolatePalette(const [low], 0.5), low);
    });

    test('clamps out-of-range t', () {
      expect(interpolatePalette(colors, -1), low);
      expect(interpolatePalette(colors, 2), high);
    });
  });

  group('scanValueRange', () {
    test('returns the min/max across non-null cells', () {
      final grid = HeatmapGrid<int>.dense([
        [1, 5, null],
        [10, 2, 3],
      ]);

      expect(scanValueRange(grid, (v) => v), (1, 10));
    });

    test('returns null for a grid with no data', () {
      final grid = HeatmapGrid<int>.dense([
        [null, null],
      ]);

      expect(scanValueRange(grid, (v) => v), isNull);
    });
  });

  group('PaletteHeatmapColorResolver', () {
    test('maps the low end of the range to the first color', () {
      const resolver = HeatmapColorResolver<int>.palette(colors: colors, value: _identity);
      expect(resolver.colorFor(_context(0), (0, 10)), low);
    });

    test('maps the high end of the range to the last color', () {
      const resolver = HeatmapColorResolver<int>.palette(colors: colors, value: _identity);
      expect(resolver.colorFor(_context(10), (0, 10)), high);
    });

    test('reversed flips low/high', () {
      const resolver = HeatmapColorResolver<int>.palette(
        colors: colors,
        value: _identity,
        reversed: true,
      );
      expect(resolver.colorFor(_context(0), (0, 10)), high);
      expect(resolver.colorFor(_context(10), (0, 10)), low);
    });

    test('an explicit range overrides the scanned range', () {
      const resolver = HeatmapColorResolver<int>.palette(
        colors: colors,
        value: _identity,
        range: (0, 100),
      );
      // Scanned range says (0, 10), but the explicit range should win.
      expect(resolver.colorFor(_context(10), (0, 10)), isNot(high));
    });

    test('a zero-span range does not divide by zero', () {
      const resolver = HeatmapColorResolver<int>.palette(colors: colors, value: _identity);
      expect(resolver.colorFor(_context(5), (5, 5)), low);
    });
  });

  group('BuilderHeatmapColorResolver', () {
    test('delegates entirely to the callback', () {
      final resolver = HeatmapColorResolver<int>.builder(
        (cell) => cell.data.isEven ? Colors.black : Colors.white,
      );

      expect(resolver.colorFor(_context(4), null), Colors.black);
      expect(resolver.colorFor(_context(3), null), Colors.white);
    });
  });
}
