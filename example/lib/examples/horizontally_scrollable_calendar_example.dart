import 'package:flutter/material.dart';
import 'package:heatmap_q/heatmap_q.dart';

import '../common/dummy_data.dart';
import '../common/example_page.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _labelStyle = TextStyle(fontSize: 11, color: Colors.black54);

/// The pattern most real commit-style heatmaps actually use: a fixed cell
/// size (not shrink-to-fit) over a range wide enough to overflow the
/// screen, scrolled horizontally. This is plain Flutter composition — a
/// SingleChildScrollView around a Heatmap with cellWidth/cellHeight set —
/// not a feature the package had to add.
///
/// Weekday labels use HeatmapRowLabels, placed outside that scroll view so
/// they stay frozen; month labels are drawn by Heatmap.calendar itself,
/// inside the scrolling area, so they travel with the grid. The two buttons
/// use scrollHeatmapCellIntoView on the same ScrollController to jump the
/// grid to a specific week without touching the frozen sidebar at all.
class HorizontallyScrollableCalendarExample extends StatefulWidget {
  const HorizontallyScrollableCalendarExample({super.key});

  @override
  State<HorizontallyScrollableCalendarExample> createState() =>
      _HorizontallyScrollableCalendarExampleState();
}

class _HorizontallyScrollableCalendarExampleState extends State<HorizontallyScrollableCalendarExample> {
  static const _cellSize = 12.0;
  static const _spacing = 3.0;
  static const _columnLabelHeight = 18.0;
  static const _rowLabelWidth = 30.0;

  final _scrollController = ScrollController();
  late final HeatmapGrid<HeatmapCalendarCell<int>> _grid;
  late final Map<int, DateTime> _monthStartByColumn;

  @override
  void initState() {
    super.initState();
    final start = DateTime(2024, 1, 1);
    final end = DateTime(2025, 12, 31); // two years — wider than any phone screen
    final commits = generateCommitData(start: start, end: end, seed: 5);
    _grid = CalendarHeatmapGrid.fromDateRange<int>(start: start, end: end, valueForDay: (day) => commits[day]);
    // Computed once — the same lookup Heatmap.calendar's monthLabelBuilder
    // builds internally, needed here only because HeatmapRowLabels means
    // this example uses the base Heatmap widget instead of Heatmap.calendar.
    _monthStartByColumn = {
      for (final boundary in monthBoundaryColumns(start: start, end: end)) boundary.column: boundary.monthStart,
    };
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToColumn(int col) {
    final layout = HeatmapLayout(
      rowCount: _grid.rowCount,
      columnCount: _grid.columnCount,
      spacing: _spacing,
      cellWidth: _cellSize,
      cellHeight: _cellSize,
    );
    scrollHeatmapCellIntoView(controller: _scrollController, layout: layout, row: 0, col: col);
  }

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: '7. Horizontally scrollable, frozen row labels',
      description: 'Two years of data with a fixed 12px cell size overflows the '
          'screen, so a plain SingleChildScrollView scrolls it. HeatmapRowLabels '
          'sits outside that scroll view and never moves; month labels are part of '
          'the scrolling Heatmap itself. The buttons use scrollHeatmapCellIntoView '
          'on the same ScrollController to jump to a week.',
      scrollableBody: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(onPressed: () => _jumpToColumn(0), child: const Text('Jump to start')),
              OutlinedButton(
                onPressed: () => _jumpToColumn(_grid.columnCount - 1),
                child: const Text('Jump to latest'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _rowLabelWidth,
                child: HeatmapRowLabels(
                  rowCount: 7,
                  cellHeight: _cellSize,
                  spacing: _spacing,
                  columnLabelHeight: _columnLabelHeight,
                  labelBuilder: (row) =>
                      const {0, 2, 4}.contains(row) ? Text(_weekdayNames[row], style: _labelStyle) : null,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Heatmap<HeatmapCalendarCell<int>>(
                    grid: _grid,
                    colorResolver: HeatmapColorResolver.palette(
                      colors: const [
                        Color(0xFFEBEDF0),
                        Color(0xFF9BE9A8),
                        Color(0xFF40C463),
                        Color(0xFF30A14E),
                        Color(0xFF216E39),
                      ],
                      value: (cell) => cell.value,
                    ),
                    cellWidth: _cellSize,
                    cellHeight: _cellSize,
                    spacing: _spacing,
                    columnLabelHeight: _columnLabelHeight,
                    columnLabelBuilder: (col) {
                      final monthStart = _monthStartByColumn[col];
                      return monthStart == null ? null : Text(_monthNames[monthStart.month - 1], style: _labelStyle);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
