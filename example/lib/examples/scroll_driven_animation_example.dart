import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:heatmap_q/heatmap_q.dart';

import '../common/dummy_data.dart';
import '../common/example_page.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _labelStyle = TextStyle(fontSize: 10, color: Colors.black54);

/// A "sticky" heatmap above a scrollable list — scrolling the list shrinks
/// the heatmap's *height* and the list grows into the freed space, like a
/// collapsing header. The heatmap is a sibling of the list, not inside it,
/// so it never scrolls away; only its size changes.
///
/// Cell size is computed once per frame as a function of the animated box
/// height and passed as *both* `cellWidth` and `cellHeight` — not just
/// `cellHeight` derived while `cellWidth` stays some unrelated fixed
/// constant. That was a bug in an earlier version of this example: it made
/// every cell a rectangle whose aspect ratio had nothing to do with the
/// animated height. Deriving one shared cell size from the box keeps cells
/// square *and* guarantees all 7 rows always fit exactly, by construction —
/// never fewer, just smaller — and since that size also drives column
/// width, more columns become visible as it shrinks, for free.
///
/// `_maxHeatmapHeight`/`_minHeatmapHeight` are themselves *derived* from
/// `_maxCellSize`/`_minCellSize` and `_columnLabelHeight`, rather than
/// separate hand-picked numbers — the same lesson as the cellWidth/
/// cellHeight bug applies to labels too: two independently-fixed numbers
/// that are supposed to agree will eventually drift apart. Here they can't.
///
/// Weekday labels use `HeatmapRowLabels` outside the horizontal scroll view
/// (frozen, like example 7) since they're a row concern, independent of
/// which columns are currently scrolled into view. Month labels are drawn
/// by the `Heatmap` itself via `columnLabelBuilder`/`columnLabelHeight`, so
/// they travel with the grid as it scrolls.
///
/// The height update is scheduled with `addPostFrameCallback` rather than
/// applied directly inside `onNotification`. Scroll notifications aren't
/// always dispatched from a safe, "outside the frame" context — e.g. the
/// final notification when a fling decelerates to a stop can fire during
/// the same frame's layout/animation phase. Updating a `ValueNotifier`
/// synchronously there triggers `ValueListenableBuilder`'s rebuild
/// mid-frame, which is exactly Flutter's "Build scheduled during frame"
/// error. Deferring to a post-frame callback is the fix Flutter's own error
/// message points at.
///
/// Progress toward "fully shrunk" is measured over a fixed
/// `_shrinkDistance` in pixels, not over the list's entire scroll range —
/// with thousands of log entries that range is huge, so dividing by it
/// would mean barely shrinking at all until nearly at the bottom.
class ScrollDrivenAnimationExample extends StatefulWidget {
  const ScrollDrivenAnimationExample({super.key});

  @override
  State<ScrollDrivenAnimationExample> createState() => _ScrollDrivenAnimationExampleState();
}

class _ScrollDrivenAnimationExampleState extends State<ScrollDrivenAnimationExample> {
  static const _rowCount = 7;
  static const _spacing = 2.0;
  static const _maxCellSize = 20.0;
  static const _minCellSize = 8.0;
  static const _columnLabelHeight = 14.0;
  static const _rowLabelWidth = 26.0;
  static const _shrinkDistance = 200.0;

  static const _maxHeatmapHeight =
      _columnLabelHeight + _rowCount * _maxCellSize + (_rowCount - 1) * _spacing;
  static const _minHeatmapHeight =
      _columnLabelHeight + _rowCount * _minCellSize + (_rowCount - 1) * _spacing;

  final _heatmapHeight = ValueNotifier<double>(_maxHeatmapHeight);
  late final HeatmapGrid<HeatmapCalendarCell<int>> _grid;
  late final List<MapEntry<DateTime, int>> _activityLog;
  late final Map<int, DateTime> _monthStartByColumn;

  @override
  void initState() {
    super.initState();
    // 6 years of daily data — a long horizontally-scrollable heatmap, and a
    // long list of log entries below it.
    final start = DateTime(2020, 1, 1);
    final end = DateTime(2025, 12, 31);
    final commits = generateCommitData(start: start, end: end, seed: 11, activeChance: 0.7);
    _grid = CalendarHeatmapGrid.fromDateRange<int>(start: start, end: end, valueForDay: (day) => commits[day]);
    _activityLog = commits.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.key.compareTo(a.key));
    _monthStartByColumn = {
      for (final boundary in monthBoundaryColumns(start: start, end: end)) boundary.column: boundary.monthStart,
    };
  }

  @override
  void dispose() {
    _heatmapHeight.dispose();
    super.dispose();
  }

  void _onScroll(ScrollMetrics metrics) {
    final t = (metrics.pixels / _shrinkDistance).clamp(0.0, 1.0);
    final newHeight = _maxHeatmapHeight - t * (_maxHeatmapHeight - _minHeatmapHeight);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _heatmapHeight.value = newHeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: '6. Sticky heatmap, shrinks as you scroll',
      description: 'The heatmap sits above the list, not inside it — it never scrolls '
          'away. Scrolling the log below shrinks its height; cell size (kept square) is '
          'recomputed each time so all 7 rows always render — never fewer, just smaller '
          '— and the list grows into the space freed up. Fully shrunk after just '
          '${_shrinkDistance.toInt()}px of scroll (_shrinkDistance), not the whole list. '
          'Weekday labels stay frozen; month labels scroll with the grid.',
      scrollableBody: false,
      child: Column(
        children: [
          ValueListenableBuilder<double>(
            valueListenable: _heatmapHeight,
            builder: (context, height, _) {
              final cellSize = (height - _columnLabelHeight - (_rowCount - 1) * _spacing) / _rowCount;
              return SizedBox(
                key: const Key('heatmapBox'),
                height: height,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: _rowLabelWidth,
                      child: HeatmapRowLabels(
                        rowCount: _rowCount,
                        cellHeight: cellSize,
                        spacing: _spacing,
                        columnLabelHeight: _columnLabelHeight,
                        labelBuilder: (row) =>
                            const {0, 2, 4}.contains(row) ? Text(_weekdayNames[row], style: _labelStyle) : null,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Heatmap<HeatmapCalendarCell<int>>(
                          grid: _grid,
                          cellWidth: cellSize,
                          cellHeight: cellSize,
                          spacing: _spacing,
                          columnLabelHeight: _columnLabelHeight,
                          columnLabelBuilder: (col) {
                            final monthStart = _monthStartByColumn[col];
                            return monthStart == null ? null : Text(_monthNames[monthStart.month - 1], style: _labelStyle);
                          },
                          cellShape: const HeatmapCellShape.rect(cornerRadius: 2),
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
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _onScroll(notification.metrics);
                return false;
              },
              child: ListView.builder(
                key: const Key('activityLog'),
                itemCount: _activityLog.length,
                itemBuilder: (context, index) {
                  final entry = _activityLog[index];
                  final date = entry.key;
                  return ListTile(
                    dense: true,
                    title: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-'
                        '${date.day.toString().padLeft(2, '0')}'),
                    trailing: Text('${entry.value} commits'),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
