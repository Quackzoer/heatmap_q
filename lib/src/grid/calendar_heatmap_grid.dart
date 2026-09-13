import 'heatmap_grid.dart';

/// The data carried by each populated cell of a
/// [CalendarHeatmapGrid.fromDateRange] grid: the calendar date alongside
/// the caller's own value. Ordinary [HeatmapGrid] machinery — nothing about
/// dates is known outside this file.
typedef HeatmapCalendarCell<T> = ({DateTime date, T value});

/// Where a calendar grid's week-column 0 starts, and how many week-columns
/// it has. Shared by [CalendarHeatmapGrid.fromDateRange] and
/// [monthBoundaryColumns] so the two can never disagree on which column a
/// given date falls in.
({DateTime gridStart, int columnCount}) _resolveCalendarBounds({
  required DateTime normalizedStart,
  required DateTime normalizedEnd,
  required int firstDayOfWeek,
}) {
  final leadingOffset = (normalizedStart.weekday - firstDayOfWeek) % 7;
  final gridStart = normalizedStart.subtract(Duration(days: leadingOffset));
  final totalDays = normalizedEnd.difference(gridStart).inDays + 1;
  return (gridStart: gridStart, columnCount: (totalDays / 7).ceil());
}

/// Namespace for building a GitHub-style calendar layout: one column per
/// week, one row per weekday. Produces a plain `HeatmapGrid<HeatmapCalendarCell<T>>`
/// — there's no separate "calendar grid" type the rest of the package has to
/// know about; this is sugar over [HeatmapGrid.dense].
class CalendarHeatmapGrid {
  const CalendarHeatmapGrid._();

  /// Cells outside [start]..[end], or where [valueForDay] returns null, are
  /// empty — same as any other [HeatmapGrid], via `cellAt` returning null.
  /// Cells with data carry their date, accessible in callbacks as
  /// `cell.data.date` alongside `cell.data.value`.
  static HeatmapGrid<HeatmapCalendarCell<T>> fromDateRange<T>({
    required DateTime start,
    required DateTime end,
    required T? Function(DateTime day) valueForDay,
    int firstDayOfWeek = DateTime.monday,
  }) {
    assert(!end.isBefore(start), 'end must not be before start');

    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    final bounds = _resolveCalendarBounds(
      normalizedStart: normalizedStart,
      normalizedEnd: normalizedEnd,
      firstDayOfWeek: firstDayOfWeek,
    );

    const rowCount = 7;
    final rows = List.generate(rowCount, (row) {
      return List.generate(bounds.columnCount, (col) {
        final day = bounds.gridStart.add(Duration(days: col * rowCount + row));
        if (day.isBefore(normalizedStart) || day.isAfter(normalizedEnd)) {
          return null;
        }
        final value = valueForDay(day);
        if (value == null) return null;
        return (date: day, value: value);
      });
    });

    return HeatmapGrid.dense(rows);
  }
}

/// For each calendar month that appears in `[start, end]`, which week-column
/// it starts in — the same week-alignment `CalendarHeatmapGrid.fromDateRange`
/// uses, so a label positioned at that column lines up with the grid exactly.
///
/// Used internally by `Heatmap.calendar`'s `monthLabelBuilder`; exposed
/// directly for building your own calendar label layer without going
/// through `Heatmap.calendar`.
List<({int column, DateTime monthStart})> monthBoundaryColumns({
  required DateTime start,
  required DateTime end,
  int firstDayOfWeek = DateTime.monday,
}) {
  assert(!end.isBefore(start), 'end must not be before start');

  final normalizedStart = DateTime(start.year, start.month, start.day);
  final normalizedEnd = DateTime(end.year, end.month, end.day);
  final bounds = _resolveCalendarBounds(
    normalizedStart: normalizedStart,
    normalizedEnd: normalizedEnd,
    firstDayOfWeek: firstDayOfWeek,
  );

  final boundaries = <({int column, DateTime monthStart})>[];
  var lastMonthKey = -1;
  for (var day = normalizedStart; !day.isAfter(normalizedEnd); day = day.add(const Duration(days: 1))) {
    final monthKey = day.year * 12 + day.month;
    if (monthKey == lastMonthKey) continue;
    lastMonthKey = monthKey;
    boundaries.add((
      column: day.difference(bounds.gridStart).inDays ~/ 7,
      monthStart: DateTime(day.year, day.month),
    ));
  }
  return boundaries;
}
