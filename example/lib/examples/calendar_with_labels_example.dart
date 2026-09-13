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

/// The same calendar as example 1, but with month and weekday labels — this
/// time using Heatmap.calendar's monthLabelBuilder/weekdayLabelBuilder
/// instead of hand-rolling a Stack + HeatmapLayout. The package works out
/// which weeks start a new month and positions the labels itself; this
/// example only supplies what to draw, and only for the weekdays it wants
/// labeled (Mon/Wed/Fri, like GitHub).
class CalendarWithLabelsExample extends StatelessWidget {
  const CalendarWithLabelsExample({super.key});

  @override
  Widget build(BuildContext context) {
    final start = DateTime(2025, 1, 1);
    final end = DateTime(2025, 12, 31);
    final commits = generateCommitData(start: start, end: end);

    return ExamplePage(
      title: '2. Calendar with labels',
      description: 'Same grid as example 1, with month and weekday labels. '
          'monthLabelBuilder only fires where a new month actually starts — '
          'no manual position math needed on this side.',
      child: SizedBox(
        height: 130,
        child: Heatmap.calendar<int>(
          start: start,
          end: end,
          valueForDay: (day) => commits[day],
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
          rowLabelWidth: 30,
          columnLabelHeight: 18,
          monthLabelBuilder: (monthStart) => Text(_monthNames[monthStart.month - 1], style: _labelStyle),
          // Mon (0), Wed (2), Fri (4) — matches GitHub's sparse weekday axis.
          weekdayLabelBuilder: (weekday) =>
              const {0, 2, 4}.contains(weekday) ? Text(_weekdayNames[weekday], style: _labelStyle) : null,
        ),
      ),
    );
  }
}
