import 'package:flutter/widgets.dart';

import 'heatmap_layout.dart';

/// A row-label sidebar that lines up exactly with a fixed-cell-size
/// `Heatmap`'s rows. Meant to sit *outside* the `SingleChildScrollView`
/// wrapping that `Heatmap` when it scrolls horizontally, so the labels stay
/// fixed on screen while the grid scrolls past them underneath — the
/// frozen-weekday-column look GitHub's own heatmap uses. Pair it with
/// [scrollHeatmapCellIntoView] to jump the grid to a specific cell.
///
/// Requires a fixed [cellHeight] (the same value given to the paired
/// `Heatmap`) — there's nothing to freeze against when cells shrink to fit
/// the viewport, since then there's no overflow to scroll in the first
/// place.
class HeatmapRowLabels extends StatelessWidget {
  const HeatmapRowLabels({
    required this.rowCount,
    required this.cellHeight,
    required this.labelBuilder,
    this.spacing = 2,
    this.columnLabelHeight = 0,
    super.key,
  });

  final int rowCount;
  final double cellHeight;
  final Widget? Function(int row) labelBuilder;
  final double spacing;

  /// Matches the paired `Heatmap`'s `columnLabelHeight`, so these labels
  /// start below the same top strip column labels occupy there, instead of
  /// overlapping them.
  final double columnLabelHeight;

  @override
  Widget build(BuildContext context) {
    final layout = HeatmapLayout(
      rowCount: rowCount,
      columnCount: 1,
      spacing: spacing,
      cellHeight: cellHeight,
    );
    return SizedBox(
      height: columnLabelHeight + layout.contentSize.height,
      child: Stack(
        children: [
          for (var row = 0; row < rowCount; row++)
            if (labelBuilder(row) case final label?)
              Positioned(left: 0, top: columnLabelHeight + layout.rectAt(row, 0).top, child: label),
        ],
      ),
    );
  }
}

/// The column-axis counterpart of [HeatmapRowLabels] — for a `Heatmap`
/// scrolled vertically with a fixed [cellWidth], sits outside that scroll
/// view as a frozen header row.
class HeatmapColumnLabels extends StatelessWidget {
  const HeatmapColumnLabels({
    required this.columnCount,
    required this.cellWidth,
    required this.labelBuilder,
    this.spacing = 2,
    this.rowLabelWidth = 0,
    super.key,
  });

  final int columnCount;
  final double cellWidth;
  final Widget? Function(int col) labelBuilder;
  final double spacing;

  /// Matches the paired `Heatmap`'s `rowLabelWidth`.
  final double rowLabelWidth;

  @override
  Widget build(BuildContext context) {
    final layout = HeatmapLayout(
      rowCount: 1,
      columnCount: columnCount,
      spacing: spacing,
      cellWidth: cellWidth,
    );
    return SizedBox(
      width: rowLabelWidth + layout.contentSize.width,
      child: Stack(
        children: [
          for (var col = 0; col < columnCount; col++)
            if (labelBuilder(col) case final label?)
              Positioned(left: rowLabelWidth + layout.rectAt(0, col).left, top: 0, child: label),
        ],
      ),
    );
  }
}
