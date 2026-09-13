/// What every callback (color resolver, tap handler) sees for one cell.
///
/// Deliberately just `data` + position — no grid-specific concept (like a
/// calendar date) leaks in here. A grid whose cells carry a date, like
/// [CalendarHeatmapGrid], expresses that by making `T` a record with a
/// `date` field, not by adding a field to this type.
typedef HeatmapCellContext<T> = ({T data, int row, int col});
