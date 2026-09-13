import 'package:flutter/widgets.dart';

import 'color/heatmap_color_resolver.dart';
import 'geometry/heatmap_cell_shape.dart';
import 'grid/calendar_heatmap_grid.dart';
import 'grid/heatmap_grid.dart';
import 'heatmap_cell_context.dart';
import 'heatmap_layout.dart';
import 'heatmap_painter.dart';

/// Draws [grid] as a grid of cells, plus optional row/column labels — no
/// other chrome. Wrap it in whatever background/decoration/scroll view the
/// host app needs.
///
/// By default cells shrink/grow to fill whatever bounded box this is given
/// (wrap it in a `SizedBox`, `Expanded`, `AspectRatio`, etc.). Pass
/// [cellWidth]/[cellHeight] instead for a fixed cell size — the widget then
/// reports its own real size (which can be bigger than the viewport), so
/// dropping it in a `SingleChildScrollView` scrolls it like any other
/// oversized child. There's no separate scrolling API here; that's ordinary
/// Flutter composition once cell size is fixed instead of derived.
///
/// [rowLabelBuilder]/[columnLabelBuilder] build a widget for a given row/
/// column index, or return null to leave that one blank — useful since real
/// axes are often sparse (e.g. a month label only where a new month starts,
/// not on every column). Reserve space for them with [rowLabelWidth] and
/// [columnLabelHeight]; each defaults to 0 (no space, no labels drawn),
/// so this is opt-in and doesn't affect a `Heatmap` with no labels at all.
class Heatmap<T> extends StatelessWidget {
  const Heatmap({
    required this.grid,
    required this.colorResolver,
    this.cellShape = const HeatmapCellShape.rect(),
    this.spacing = 2,
    this.emptyCellColor,
    this.cellWidth,
    this.cellHeight,
    this.rowLabelBuilder,
    this.columnLabelBuilder,
    this.rowLabelWidth = 0,
    this.columnLabelHeight = 0,
    this.repaint,
    this.onCellTap,
    super.key,
  });

  final HeatmapGrid<T> grid;
  final HeatmapColorResolver<T> colorResolver;
  final HeatmapCellShape cellShape;
  final double spacing;
  final Color? emptyCellColor;

  /// Fixed cell dimensions instead of shrinking/growing to fill the box —
  /// set one or both to get a real (possibly viewport-exceeding) size back,
  /// suitable for scrolling. See the class doc.
  final double? cellWidth;
  final double? cellHeight;

  /// Builds the label for row/column [index], or null for no label there.
  /// Positioned to line up exactly with that row's/column's cells.
  final Widget? Function(int index)? rowLabelBuilder;
  final Widget? Function(int index)? columnLabelBuilder;

  /// Space reserved to the left / above the grid for labels. Only matters
  /// when the corresponding builder is set.
  final double rowLabelWidth;
  final double columnLabelHeight;

  /// Drives repaints without rebuilding this widget — pass an
  /// `AnimationController`, a `ValueNotifier`, or anything `Listenable` that
  /// you update from outside (e.g. a scroll listener) to animate cheaply.
  final Listenable? repaint;

  final void Function(HeatmapCellContext<T> cell)? onCellTap;

  /// Builds a GitHub-style calendar heatmap in one call: constructs the
  /// [CalendarHeatmapGrid] and wires it up, so callers don't need to spell
  /// out `Heatmap<HeatmapCalendarCell<T>>` themselves.
  ///
  /// This can't be a constructor of [Heatmap] itself — a named constructor
  /// must return the exact type it was invoked with (`Heatmap<T>`), but this
  /// needs to return `Heatmap<HeatmapCalendarCell<T>>` for a plain `T` like
  /// `int`. A static method can remap the type freely, so `Heatmap.calendar`
  /// reads like a constructor at the call site but is one underneath.
  ///
  /// [colorResolver] and [onCellTap] still operate on
  /// `HeatmapCellContext<HeatmapCalendarCell<T>>` — `cell.data.value` for
  /// the caller's value, `cell.data.date` for the calendar date — nothing
  /// about dates is hidden, just the grid construction.
  ///
  /// [monthLabelBuilder] is called once per calendar month that appears in
  /// the range (not once per column) — the package works out which weeks
  /// start a new month via [monthBoundaryColumns] and positions the result
  /// for you, so you don't need to detect month boundaries yourself.
  /// [weekdayLabelBuilder] is the plain row builder (`0` = [firstDayOfWeek])
  /// — return null for weekdays you don't want to label, e.g. to show only
  /// Mon/Wed/Fri like GitHub does.
  static Heatmap<HeatmapCalendarCell<T>> calendar<T>({
    required DateTime start,
    required DateTime end,
    required T? Function(DateTime day) valueForDay,
    required HeatmapColorResolver<HeatmapCalendarCell<T>> colorResolver,
    int firstDayOfWeek = DateTime.monday,
    HeatmapCellShape cellShape = const HeatmapCellShape.rect(),
    double spacing = 2,
    Color? emptyCellColor,
    double? cellWidth,
    double? cellHeight,
    Widget Function(DateTime monthStart)? monthLabelBuilder,
    Widget? Function(int weekday)? weekdayLabelBuilder,
    double rowLabelWidth = 0,
    double columnLabelHeight = 0,
    Listenable? repaint,
    void Function(HeatmapCellContext<HeatmapCalendarCell<T>> cell)? onCellTap,
    Key? key,
  }) {
    Widget? Function(int col)? columnLabelBuilder;
    if (monthLabelBuilder != null) {
      final labelByColumn = {
        for (final boundary in monthBoundaryColumns(start: start, end: end, firstDayOfWeek: firstDayOfWeek))
          boundary.column: boundary.monthStart,
      };
      columnLabelBuilder = (col) {
        final monthStart = labelByColumn[col];
        return monthStart == null ? null : monthLabelBuilder(monthStart);
      };
    }

    return Heatmap<HeatmapCalendarCell<T>>(
      grid: CalendarHeatmapGrid.fromDateRange<T>(
        start: start,
        end: end,
        valueForDay: valueForDay,
        firstDayOfWeek: firstDayOfWeek,
      ),
      colorResolver: colorResolver,
      cellShape: cellShape,
      spacing: spacing,
      emptyCellColor: emptyCellColor,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      rowLabelBuilder: weekdayLabelBuilder,
      columnLabelBuilder: columnLabelBuilder,
      rowLabelWidth: rowLabelWidth,
      columnLabelHeight: columnLabelHeight,
      repaint: repaint,
      onCellTap: onCellTap,
      key: key,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasRowLabels = rowLabelBuilder != null && rowLabelWidth > 0;
        final hasColumnLabels = columnLabelBuilder != null && columnLabelHeight > 0;

        final available = constraints.biggest;
        // `available` may be infinite on an axis this widget doesn't
        // actually need (e.g. inside a horizontally-scrolling parent with a
        // fixed cellWidth) — HeatmapLayout only reads it for an axis
        // without an explicit cell size, so that's never a problem.
        final layout = HeatmapLayout(
          rowCount: grid.rowCount,
          columnCount: grid.columnCount,
          size: Size(
            available.width - (hasRowLabels ? rowLabelWidth : 0),
            available.height - (hasColumnLabels ? columnLabelHeight : 0),
          ),
          spacing: spacing,
          cellWidth: cellWidth,
          cellHeight: cellHeight,
        );
        final gridSize = layout.contentSize;

        final painter = HeatmapPainter<T>(
          grid: grid,
          colorResolver: colorResolver,
          cellShape: cellShape,
          spacing: spacing,
          emptyCellColor: emptyCellColor,
          cellWidth: cellWidth,
          cellHeight: cellHeight,
          repaint: repaint,
        );
        Widget gridChild = CustomPaint(size: gridSize, painter: painter);

        final tapHandler = onCellTap;
        if (tapHandler != null) {
          gridChild = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final indices = layout.cellAt(details.localPosition);
              if (indices == null) return;
              final (row, col) = indices;
              final data = grid.cellAt(row, col);
              if (data == null) return;
              tapHandler((data: data, row: row, col: col));
            },
            child: gridChild,
          );
        }

        if (!hasRowLabels && !hasColumnLabels) return gridChild;

        final columnLabelOffset = hasColumnLabels ? columnLabelHeight : 0.0;
        final rowLabelOffset = hasRowLabels ? rowLabelWidth : 0.0;

        return SizedBox(
          width: rowLabelOffset + gridSize.width,
          height: columnLabelOffset + gridSize.height,
          child: Stack(
            children: [
              if (hasColumnLabels)
                for (var col = 0; col < grid.columnCount; col++)
                  if (columnLabelBuilder!(col) case final label?)
                    Positioned(left: rowLabelOffset + layout.rectAt(0, col).left, top: 0, child: label),
              if (hasRowLabels)
                for (var row = 0; row < grid.rowCount; row++)
                  if (rowLabelBuilder!(row) case final label?)
                    Positioned(left: 0, top: columnLabelOffset + layout.rectAt(row, 0).top, child: label),
              Positioned(left: rowLabelOffset, top: columnLabelOffset, child: gridChild),
            ],
          ),
        );
      },
    );
  }
}
