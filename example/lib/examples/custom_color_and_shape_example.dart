import 'dart:math';

import 'package:flutter/material.dart';
import 'package:heatmap_q/heatmap_q.dart';

import '../common/example_page.dart';

enum TaskStatus { done, inProgress, blocked, todo }

const _statusColors = {
  TaskStatus.done: Color(0xFF2E7D32),
  TaskStatus.inProgress: Color(0xFFF9A825),
  TaskStatus.blocked: Color(0xFFC62828),
  TaskStatus.todo: Color(0xFFBDBDBD),
};

const _people = ['Ann', 'Ben', 'Cleo', 'Dev', 'Eli'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

List<List<TaskStatus?>> _generateStatuses() {
  final random = Random(4);
  final statuses = TaskStatus.values;
  return List.generate(
    _people.length,
    (_) => List.generate(_days.length, (_) => statuses[random.nextInt(statuses.length)]),
  );
}

/// A diamond inscribed in [bounds] — anything `Path`-shaped is fair game for
/// `HeatmapCellShape.custom`, not just the built-in rect/circle.
Path _diamondPath(Rect bounds) {
  final center = bounds.center;
  return Path()
    ..moveTo(center.dx, bounds.top)
    ..lineTo(bounds.right, center.dy)
    ..lineTo(center.dx, bounds.bottom)
    ..lineTo(bounds.left, center.dy)
    ..close();
}

/// Full callback-driven customization: a color builder keyed off an enum
/// (not a numeric palette at all) and a custom cell shape, plus onCellTap
/// wired to plain app state.
class CustomColorAndShapeExample extends StatefulWidget {
  const CustomColorAndShapeExample({super.key});

  @override
  State<CustomColorAndShapeExample> createState() => _CustomColorAndShapeExampleState();
}

class _CustomColorAndShapeExampleState extends State<CustomColorAndShapeExample> {
  HeatmapCellContext<TaskStatus>? _tapped;

  @override
  Widget build(BuildContext context) {
    final grid = HeatmapGrid<TaskStatus>.dense(_generateStatuses());

    return ExamplePage(
      title: '4. Custom color + custom cell shape',
      description: 'HeatmapColorResolver.builder maps an enum straight to a color — no '
          'numeric palette involved — and HeatmapCellShape.custom swaps the default '
          'rounded rect for a diamond. Tap a cell to see onCellTap fire.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            child: Heatmap<TaskStatus>(
              grid: grid,
              spacing: 4,
              cellShape: HeatmapCellShape.custom(_diamondPath),
              colorResolver: HeatmapColorResolver.builder((cell) => _statusColors[cell.data]!),
              onCellTap: (cell) => setState(() => _tapped = cell),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _tapped == null
                ? 'Tap a cell to see its data.'
                : '${_people[_tapped!.row]} · ${_days[_tapped!.col]} · ${_tapped!.data.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
