import 'package:flutter/widgets.dart';

import 'heatmap_layout.dart';

/// Scrolls [controller] so the cell at ([row], [col]) — as positioned by
/// [layout] — becomes visible, animating over [duration]. Works out whether
/// [controller] is scrolling horizontally or vertically from its own
/// position and reads the matching axis off [layout].
///
/// [alignment] follows the same convention as `Scrollable.ensureVisible`:
/// `0` aligns the cell to the leading edge of the viewport, `1` to the
/// trailing edge, `0.5` (the default) centers it.
///
/// `Heatmap` doesn't own a `ScrollController` — the host wraps it in their
/// own `SingleChildScrollView`/`ScrollController` (see the "Cell sizing"
/// section of the plan for why), so this is a plain function operating on
/// that controller, not a method on `Heatmap`.
Future<void> scrollHeatmapCellIntoView({
  required ScrollController controller,
  required HeatmapLayout layout,
  required int row,
  required int col,
  double alignment = 0.5,
  Duration duration = const Duration(milliseconds: 300),
  Curve curve = Curves.easeInOut,
}) {
  if (!controller.hasClients) return Future<void>.value();

  final position = controller.position;
  final cellRect = layout.rectAt(row, col);
  final isHorizontal = position.axis == Axis.horizontal;
  final cellStart = isHorizontal ? cellRect.left : cellRect.top;
  final cellExtent = isHorizontal ? cellRect.width : cellRect.height;

  final target = (cellStart - (position.viewportDimension - cellExtent) * alignment)
      .clamp(position.minScrollExtent, position.maxScrollExtent);

  return controller.animateTo(target, duration: duration, curve: curve);
}
