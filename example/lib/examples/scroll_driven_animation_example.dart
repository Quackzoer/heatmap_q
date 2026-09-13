import 'package:flutter/material.dart';
import 'package:heatmap_q/heatmap_q.dart';

import '../common/dummy_data.dart';
import '../common/example_page.dart';

/// Cell size itself changes here — as you scroll down the page, cells
/// shrink and more of ~3 years of data becomes visible at once inside a
/// horizontally-scrollable grid. That's a genuine layout change (the grid's
/// real content size shrinks), which is different from — and can't be done
/// by — the paint-only `repaint:` mechanism used elsewhere in this package:
/// `repaint` only ever triggers a redraw of an *already-allocated* canvas
/// size, it can't change how big that canvas is.
///
/// So this needs an actual rebuild on every scroll tick. The trick to
/// keeping that smooth isn't avoiding the rebuild — it's scoping it to the
/// smallest possible subtree. Only the ValueListenableBuilder immediately
/// around the grid rebuilds; the rebuild counter in the description proves
/// the enclosing page (the ListView, the scroll listener, this whole
/// State) is built exactly once and never again while you scroll.
class ScrollDrivenAnimationExample extends StatefulWidget {
  const ScrollDrivenAnimationExample({super.key});

  @override
  State<ScrollDrivenAnimationExample> createState() => _ScrollDrivenAnimationExampleState();
}

class _ScrollDrivenAnimationExampleState extends State<ScrollDrivenAnimationExample> {
  static const _minCellSize = 6.0;
  static const _maxCellSize = 22.0;

  final _zoom = ValueNotifier<double>(0);
  late final HeatmapGrid<HeatmapCalendarCell<int>> _grid;
  int _buildCount = 0;

  @override
  void initState() {
    super.initState();
    // ~3 years of daily data (~160 week-columns) — enough that shrinking
    // cells meaningfully reveals more of it, and enough to need horizontal
    // scrolling at every zoom level, not just the most zoomed-out one.
    final start = DateTime(2023, 1, 1);
    final end = DateTime(2025, 12, 31);
    final commits = generateCommitData(start: start, end: end, seed: 11, activeChance: 0.55);
    _grid = CalendarHeatmapGrid.fromDateRange<int>(start: start, end: end, valueForDay: (day) => commits[day]);
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _buildCount++;

    return ExamplePage(
      title: '6. Scroll-driven zoom',
      description: 'Scrolling down shrinks the cells so more of ~3 years of data '
          'fits at once — a real layout change, not just a repaint. This page has '
          'rebuilt $_buildCount time(s) so far; scrolling never increases that — '
          'only the small ValueListenableBuilder around the grid below rebuilds.',
      scrollableBody: false,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          final maxScroll = notification.metrics.maxScrollExtent;
          _zoom.value = maxScroll <= 0 ? 0 : (notification.metrics.pixels / maxScroll).clamp(0, 1);
          return false;
        },
        child: ListView(
          children: [
            const SizedBox(
              height: 300,
              child: Center(child: Text('Scroll down ↓', style: TextStyle(color: Colors.black54))),
            ),
            SizedBox(
              height: 130,
              child: ValueListenableBuilder<double>(
                valueListenable: _zoom,
                builder: (context, zoom, _) {
                  final cellSize = _maxCellSize - zoom * (_maxCellSize - _minCellSize);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Heatmap<HeatmapCalendarCell<int>>(
                      grid: _grid,
                      cellWidth: cellSize,
                      cellHeight: cellSize,
                      spacing: cellSize * 0.15,
                      cellShape: HeatmapCellShape.rect(cornerRadius: cellSize * 0.15),
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
                  );
                },
              ),
            ),
            const SizedBox(height: 800),
          ],
        ),
      ),
    );
  }
}
