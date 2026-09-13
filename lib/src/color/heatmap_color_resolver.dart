import 'dart:ui';

import '../grid/heatmap_grid.dart';
import '../heatmap_cell_context.dart';

/// Picks a color for a cell — exactly one of a fixed [palette] or a
/// [builder] callback, enforced by this being sealed with only factory
/// constructors (no way to construct one that sets both, or neither).
sealed class HeatmapColorResolver<T> {
  const HeatmapColorResolver();

  /// A linear gradient across [colors]. [value] extracts the number used to
  /// place a cell on the gradient.
  ///
  /// If [range] isn't given, it's scanned once from the grid's actual
  /// min/max (via [scanValueRange]) — no manual clamping or dividing by an
  /// assumed max is needed. The lowest value maps to `colors.first` and the
  /// highest to `colors.last`, unless [reversed] is true.
  const factory HeatmapColorResolver.palette({
    required List<Color> colors,
    required num Function(T data) value,
    bool reversed,
    (num min, num max)? range,
  }) = PaletteHeatmapColorResolver<T>;

  /// Full control: compute the color for a cell yourself.
  const factory HeatmapColorResolver.builder(
    Color Function(HeatmapCellContext<T> cell) resolve,
  ) = BuilderHeatmapColorResolver<T>;

  /// Resolves the color for [cell]. [scannedRange] is the grid's min/max as
  /// computed by [scanValueRange] — ignored by [BuilderHeatmapColorResolver],
  /// used as a fallback by [PaletteHeatmapColorResolver] when it wasn't
  /// constructed with an explicit `range`.
  Color colorFor(HeatmapCellContext<T> cell, (num min, num max)? scannedRange);
}

final class PaletteHeatmapColorResolver<T> extends HeatmapColorResolver<T> {
  const PaletteHeatmapColorResolver({
    required this.colors,
    required this.value,
    this.reversed = false,
    this.range,
  });

  final List<Color> colors;
  final num Function(T data) value;
  final bool reversed;
  final (num min, num max)? range;

  @override
  Color colorFor(HeatmapCellContext<T> cell, (num min, num max)? scannedRange) {
    final effectiveRange = range ?? scannedRange;
    final raw = value(cell.data);

    double t;
    if (effectiveRange == null) {
      // No data anywhere in the grid to scan a range from.
      t = 0;
    } else {
      final span = effectiveRange.$2 - effectiveRange.$1;
      t = span == 0 ? 0 : (raw - effectiveRange.$1) / span;
    }
    if (reversed) t = 1 - t;

    return interpolatePalette(colors, t.clamp(0, 1).toDouble());
  }
}

final class BuilderHeatmapColorResolver<T> extends HeatmapColorResolver<T> {
  const BuilderHeatmapColorResolver(this.resolve);

  final Color Function(HeatmapCellContext<T> cell) resolve;

  @override
  Color colorFor(HeatmapCellContext<T> cell, (num min, num max)? scannedRange) =>
      resolve(cell);
}

/// Linearly interpolates across an ordered [colors] list at position [t]
/// (0..1). Exposed standalone so it's testable without a canvas, and reusable
/// by anyone composing their own resolver.
Color interpolatePalette(List<Color> colors, double t) {
  if (colors.length == 1) return colors.first;
  final scaled = t.clamp(0.0, 1.0) * (colors.length - 1);
  final lowerIndex = scaled.floor();
  final upperIndex = (lowerIndex + 1).clamp(0, colors.length - 1);
  final localT = scaled - lowerIndex;
  return Color.lerp(colors[lowerIndex], colors[upperIndex], localT)!;
}

/// Scans [grid] once for the min/max of `value(cell)` across all non-null
/// cells. Returns null if the grid has no data at all.
(num min, num max)? scanValueRange<T>(
  HeatmapGrid<T> grid,
  num Function(T data) value,
) {
  num? min;
  num? max;
  for (var row = 0; row < grid.rowCount; row++) {
    for (var col = 0; col < grid.columnCount; col++) {
      final data = grid.cellAt(row, col);
      if (data == null) continue;
      final v = value(data);
      if (min == null || v < min) min = v;
      if (max == null || v > max) max = v;
    }
  }
  if (min == null || max == null) return null;
  return (min, max);
}
