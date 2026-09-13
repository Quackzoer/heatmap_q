import 'package:flutter/material.dart';
import 'package:heatmap_q/heatmap_q.dart';

import '../common/dummy_data.dart';
import '../common/example_page.dart';

const _rowLabels = ['2022', '2021', '2020', '2019'];
const _columnLabels = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _labelStyle = TextStyle(fontSize: 11, color: Colors.black54);

/// Arbitrary rows/columns — the same shape the `fl_heatmap` package
/// supports — built with `HeatmapGrid.dense` instead of a calendar factory.
/// Row/column labels line up exactly because `spacing: 0` makes the grid's
/// even cell distribution match Flutter's own `Expanded` distribution.
class CustomGridWithLabelsExample extends StatelessWidget {
  const CustomGridWithLabelsExample({super.key});

  @override
  Widget build(BuildContext context) {
    final usage = generateUsageGrid(rows: _rowLabels.length, columns: _columnLabels.length, min: 5, max: 60);
    final grid = HeatmapGrid<double>.dense(
      usage.map((row) => row.cast<double?>()).toList(),
    );

    return ExamplePage(
      title: '3. Custom rows & columns, with labels',
      description: 'Arbitrary rows/columns instead of a calendar — the same shape as '
          'fl_heatmap\'s API. HeatmapGrid.dense doesn\'t know or care what the rows '
          'and columns mean; row/column labels are plain widgets from this example.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 40),
              for (final label in _columnLabels)
                Expanded(child: Center(child: Text(label, style: _labelStyle))),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Column(
                    children: [
                      for (final label in _rowLabels)
                        Expanded(child: Center(child: Text(label, style: _labelStyle))),
                    ],
                  ),
                ),
                Expanded(
                  child: Heatmap<double>(
                    grid: grid,
                    spacing: 0,
                    cellShape: const HeatmapCellShape.rect(cornerRadius: 2),
                    colorResolver: HeatmapColorResolver.builder(
                      (cell) => Color.lerp(
                        const Color(0xFFE3F2FD),
                        const Color(0xFF0D47A1),
                        (cell.data / 60).clamp(0, 1),
                      )!,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
