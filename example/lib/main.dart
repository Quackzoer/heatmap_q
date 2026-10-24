import 'package:flutter/material.dart';

import 'examples/calendar_with_labels_example.dart';
import 'examples/custom_color_and_shape_example.dart';
import 'examples/custom_grid_with_labels_example.dart';
import 'examples/horizontally_scrollable_calendar_example.dart';
import 'examples/house_electricity_usage_example.dart';
import 'examples/minimal_calendar_example.dart';
import 'examples/scroll_driven_animation_example.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'heatmap_q examples',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF216E39), useMaterial3: true),
      home: const _ExampleMenu(),
    );
  }
}

class _ExampleEntry {
  const _ExampleEntry(this.title, this.subtitle, this.builder);
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
}

final _entries = [
  _ExampleEntry('1. Minimal calendar', 'GitHub-style grid, fixed palette, nothing else',
      (_) => const MinimalCalendarExample()),
  _ExampleEntry('2. Calendar with labels', 'Same grid, with month/weekday labels drawn by the app',
      (_) => const CalendarWithLabelsExample()),
  _ExampleEntry('3. Custom rows & columns', 'Arbitrary grid shape (à la fl_heatmap) with axis labels',
      (_) => const CustomGridWithLabelsExample()),
  _ExampleEntry('4. Custom color + shape', 'Enum-driven color builder and a custom diamond cell shape',
      (_) => const CustomColorAndShapeExample()),
  _ExampleEntry('5. House electricity usage', '4 rooms x 12 months of dummy kWh data — no dates involved',
      (_) => const HouseElectricityUsageExample()),
  _ExampleEntry('6. Sticky heatmap, shrinks as you scroll', 'A shrinking header next to a growing list, never hiding rows',
      (_) => const ScrollDrivenAnimationExample()),
  _ExampleEntry('7. Horizontally scrollable, frozen labels', 'Fixed cell size + ordinary scroll view; row labels stay put',
      (_) => const HorizontallyScrollableCalendarExample()),
];

class _ExampleMenu extends StatelessWidget {
  const _ExampleMenu();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('heatmap_q examples')),
      body: ListView.separated(
        itemCount: _entries.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return ListTile(
            title: Text(entry.title),
            subtitle: Text(entry.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: entry.builder)),
          );
        },
      ),
    );
  }
}
