import 'package:flutter/material.dart';
import 'package:heatmap_q/heatmap_q.dart';

import '../common/dummy_data.dart';
import '../common/example_page.dart';

const _rooms = ['Living room', 'Kitchen', 'Bedroom', 'Bathroom']; // 4 rows
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _labelStyle = TextStyle(fontSize: 11, color: Colors.black54);
const _maxKwh = 420.0;

/// A realistic "domain data, not dates" heatmap: 4 rooms x 12 months of
/// dummy electricity usage (kWh). Same building blocks as example 3 —
/// HeatmapGrid.dense + HeatmapColorResolver.builder — applied to a use case
/// that has nothing to do with a calendar, which is exactly why
/// HeatmapCellContext carries no date field.
class HouseElectricityUsageExample extends StatefulWidget {
  const HouseElectricityUsageExample({super.key});

  @override
  State<HouseElectricityUsageExample> createState() => _HouseElectricityUsageExampleState();
}

class _HouseElectricityUsageExampleState extends State<HouseElectricityUsageExample> {
  HeatmapCellContext<double>? _tapped;

  @override
  Widget build(BuildContext context) {
    final usage = generateUsageGrid(rows: _rooms.length, columns: _months.length, seed: 7, min: 30, max: _maxKwh);
    final grid = HeatmapGrid<double>.dense(usage.map((row) => row.cast<double?>()).toList());

    return ExamplePage(
      title: '5. House electricity usage',
      description: '4 rooms x 12 months of dummy kWh readings — a grid with nothing '
          'to do with dates, sized and colored the same way as any other data.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 72),
              for (final label in _months) Expanded(child: Center(child: Text(label, style: _labelStyle))),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 160,
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      for (final label in _rooms)
                        Expanded(child: Center(child: Text(label, style: _labelStyle, textAlign: TextAlign.center))),
                    ],
                  ),
                ),
                Expanded(
                  child: Heatmap<double>(
                    grid: grid,
                    spacing: 2,
                    colorResolver: HeatmapColorResolver.palette(
                      colors: const [
                        Color(0xFFFFF9C4),
                        Color(0xFFFFCC80),
                        Color(0xFFEF6C00),
                        Color(0xFFB71C1C),
                      ],
                      value: (kwh) => kwh,
                    ),
                    onCellTap: (cell) => setState(() => _tapped = cell),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _tapped == null
                ? 'Tap a cell to see its reading.'
                : '${_rooms[_tapped!.row]} · ${_months[_tapped!.col]}: '
                    '${_tapped!.data.toStringAsFixed(0)} kWh',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
