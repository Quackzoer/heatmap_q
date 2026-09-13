import 'dart:ui';

/// The shape drawn for each cell. Default to [HeatmapCellShape.rect] for the
/// common case; drop to [HeatmapCellShape.custom] for anything else.
sealed class HeatmapCellShape {
  const HeatmapCellShape();

  const factory HeatmapCellShape.rect({double cornerRadius}) = RectHeatmapCellShape;

  const factory HeatmapCellShape.circle() = CircleHeatmapCellShape;

  const factory HeatmapCellShape.custom(Path Function(Rect bounds) build) =
      CustomHeatmapCellShape;

  /// Builds the path to fill for a cell occupying [bounds].
  Path pathFor(Rect bounds);
}

final class RectHeatmapCellShape extends HeatmapCellShape {
  const RectHeatmapCellShape({this.cornerRadius = 0});

  final double cornerRadius;

  @override
  Path pathFor(Rect bounds) =>
      Path()..addRRect(RRect.fromRectAndRadius(bounds, Radius.circular(cornerRadius)));
}

final class CircleHeatmapCellShape extends HeatmapCellShape {
  const CircleHeatmapCellShape();

  @override
  Path pathFor(Rect bounds) => Path()..addOval(bounds);
}

final class CustomHeatmapCellShape extends HeatmapCellShape {
  const CustomHeatmapCellShape(this.build);

  final Path Function(Rect bounds) build;

  @override
  Path pathFor(Rect bounds) => build(bounds);
}
