import 'package:flutter/widgets.dart';

import 'color/heatmap_color_resolver.dart';
import 'geometry/heatmap_cell_shape.dart';
import 'grid/heatmap_grid.dart';
import 'heatmap_layout.dart';

/// Draws [grid]'s cells only — no background. Layer this over whatever
/// decoration/background the host app wants.
///
/// Pass an external [repaint] (an `Animation`, a `ValueNotifier`, anything
/// `Listenable`) to animate — the painter repaints on every tick of it
/// without the surrounding widget tree ever rebuilding. Never drive
/// animation through `setState` here; that defeats the point.
class HeatmapPainter<T> extends CustomPainter {
  HeatmapPainter({
    required HeatmapGrid<T> grid,
    required HeatmapColorResolver<T> colorResolver,
    this.cellShape = const HeatmapCellShape.rect(),
    this.spacing = 2,
    this.emptyCellColor,
    this.cellWidth,
    this.cellHeight,
    super.repaint,
  })  : grid = grid,
        colorResolver = colorResolver,
        // Scanned once here (painter construction, i.e. once per widget
        // build) — never inside paint(), which can run every animation
        // frame when driven by `repaint`.
        _scannedRange = colorResolver is PaletteHeatmapColorResolver<T> &&
                colorResolver.range == null
            ? scanValueRange(grid, colorResolver.value)
            : null;

  final HeatmapGrid<T> grid;
  final HeatmapColorResolver<T> colorResolver;
  final HeatmapCellShape cellShape;
  final double spacing;
  final Color? emptyCellColor;

  /// Fixed cell dimensions — leave null to shrink/grow cells to fill the
  /// given [Size] instead. See [HeatmapLayout] for how the two modes work.
  final double? cellWidth;
  final double? cellHeight;

  final (num min, num max)? _scannedRange;

  @override
  void paint(Canvas canvas, Size size) {
    final rowCount = grid.rowCount;
    final columnCount = grid.columnCount;
    if (rowCount == 0 || columnCount == 0) return;

    final layout = HeatmapLayout(
      rowCount: rowCount,
      columnCount: columnCount,
      size: size,
      spacing: spacing,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
    );
    final paint = Paint()..style = PaintingStyle.fill;

    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < columnCount; col++) {
        final data = grid.cellAt(row, col);

        final Color? color;
        if (data == null) {
          color = emptyCellColor;
        } else {
          color = colorResolver.colorFor((data: data, row: row, col: col), _scannedRange);
        }
        if (color == null) continue;

        paint.color = color;
        canvas.drawPath(cellShape.pathFor(layout.rectAt(row, col)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant HeatmapPainter<T> oldDelegate) {
    return oldDelegate.grid != grid ||
        oldDelegate.colorResolver != colorResolver ||
        oldDelegate.cellShape != cellShape ||
        oldDelegate.spacing != spacing ||
        oldDelegate.emptyCellColor != emptyCellColor ||
        oldDelegate.cellWidth != cellWidth ||
        oldDelegate.cellHeight != cellHeight;
  }
}
