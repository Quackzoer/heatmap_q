/// A data source for a heatmap grid: dimensions plus a value at each
/// (row, col). No painting or color logic lives here — [HeatmapGrid] only
/// answers "how big" and "what's here."
///
/// Implement this directly for a custom data source (e.g. lazily backed by
/// a database), or use [HeatmapGrid.dense] / [HeatmapGrid.sparse] for the
/// common cases.
abstract interface class HeatmapGrid<T> {
  int get rowCount;
  int get columnCount;

  /// The value at (row, col), or null if there's no data for that cell.
  T? cellAt(int row, int col);

  /// Builds a grid from a rectangular list of rows. All rows must have the
  /// same length.
  factory HeatmapGrid.dense(List<List<T?>> rows) = DenseHeatmapGrid<T>;

  /// Builds a grid from a sparse map of (row, col) to value. Cells not
  /// present in [cells] are treated as empty.
  factory HeatmapGrid.sparse({
    required int rowCount,
    required int columnCount,
    required Map<(int row, int col), T> cells,
  }) = SparseHeatmapGrid<T>;
}

class DenseHeatmapGrid<T> implements HeatmapGrid<T> {
  DenseHeatmapGrid(List<List<T?>> rows)
      : _rows = rows,
        rowCount = rows.length,
        columnCount = rows.isEmpty ? 0 : rows.first.length {
    assert(
      _rows.every((row) => row.length == columnCount),
      'All rows passed to HeatmapGrid.dense must have the same length',
    );
  }

  final List<List<T?>> _rows;

  @override
  final int rowCount;

  @override
  final int columnCount;

  @override
  T? cellAt(int row, int col) {
    if (row < 0 || row >= rowCount || col < 0 || col >= columnCount) {
      return null;
    }
    return _rows[row][col];
  }
}

class SparseHeatmapGrid<T> implements HeatmapGrid<T> {
  SparseHeatmapGrid({
    required this.rowCount,
    required this.columnCount,
    required this.cells,
  });

  @override
  final int rowCount;

  @override
  final int columnCount;

  final Map<(int row, int col), T> cells;

  @override
  T? cellAt(int row, int col) => cells[(row, col)];
}
