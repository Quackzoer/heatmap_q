import 'package:flutter/material.dart';
import 'package:heatmap_q/heatmap_q.dart';

import '../common/dummy_data.dart';
import '../common/example_page.dart';

/// The simplest possible use of the package: a calendar grid plus a fixed
/// palette. No labels, no background, no interaction — `Heatmap` draws
/// cells only, which is the whole point of the "no chrome" design.
class MinimalCalendarExample extends StatelessWidget {
  const MinimalCalendarExample({super.key});

  @override
  Widget build(BuildContext context) {
    final start = DateTime(2025, 1, 1);
    final end = DateTime(2025, 12, 31);
    final commits = generateCommitData(start: start, end: end);

    return ExamplePage(
      title: '1. Minimal calendar',
      description: 'The smallest possible setup: Heatmap.calendar + a fixed color '
          'palette. Nothing else — no labels, no background, no taps.',
      child: SizedBox(
        height: 120,
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
        ),
      ),
    );
  }
}
