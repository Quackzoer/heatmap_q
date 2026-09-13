import 'dart:ui';

/// Shared cell-geometry math: the painter uses it to know where to draw,
/// hit-testing uses the exact same formula to know what was tapped. Keeping
/// this in one place means those two can never drift apart.
///
/// Two sizing modes, chosen per axis:
///  - Pass [size] alone: cells shrink/grow to fill it exactly (the default —
///    good for a compact, responsive heatmap).
///  - Pass [cellWidth]/[cellHeight]: that axis gets a fixed cell size and
///    [contentSize] reports the grid's real (possibly larger-than-viewport)
///    size, so wrapping it in an ordinary `SingleChildScrollView` scrolls it
///    — no special scrolling support needed in the widget itself.
/// Mixing is fine (e.g. a fixed cell width for horizontal scrolling with a
/// height that fills whatever space is available).
class HeatmapLayout {
  const HeatmapLayout({
    required this.rowCount,
    required this.columnCount,
    required this.spacing,
    Size? size,
    double? cellWidth,
    double? cellHeight,
  })  : // Kept distinct from the private field names so the public API
        // reads as size/cellWidth/cellHeight rather than leaking underscores.
        // ignore: prefer_initializing_formals
        _size = size,
        _explicitCellWidth = cellWidth,
        _explicitCellHeight = cellHeight;

  final int rowCount;
  final int columnCount;
  final double spacing;
  final Size? _size;
  final double? _explicitCellWidth;
  final double? _explicitCellHeight;

  double get cellWidth =>
      _explicitCellWidth ??
      (columnCount == 0 || _size == null
          ? 0
          : (_size.width - spacing * (columnCount - 1)) / columnCount);

  double get cellHeight =>
      _explicitCellHeight ??
      (rowCount == 0 || _size == null ? 0 : (_size.height - spacing * (rowCount - 1)) / rowCount);

  /// The grid's actual size — equal to the given [size] when cell size is
  /// derived, or larger than it when a fixed [cellWidth]/[cellHeight]
  /// doesn't fit the available space. Use this as the widget's real size so
  /// an ancestor scroll view knows there's more content than fits.
  Size get contentSize => Size(
        columnCount == 0 ? 0 : columnCount * cellWidth + (columnCount - 1) * spacing,
        rowCount == 0 ? 0 : rowCount * cellHeight + (rowCount - 1) * spacing,
      );

  Rect rectAt(int row, int col) => Rect.fromLTWH(
        col * (cellWidth + spacing),
        row * (cellHeight + spacing),
        cellWidth,
        cellHeight,
      );

  /// The (row, col) at [position], or null if it falls outside the grid or
  /// in the gap between cells.
  (int row, int col)? cellAt(Offset position) {
    if (rowCount == 0 || columnCount == 0) return null;
    final col = (position.dx / (cellWidth + spacing)).floor();
    final row = (position.dy / (cellHeight + spacing)).floor();
    if (row < 0 || row >= rowCount || col < 0 || col >= columnCount) return null;
    if (!rectAt(row, col).contains(position)) return null;
    return (row, col);
  }
}
