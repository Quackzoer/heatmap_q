# heatmap_q — Architecture Plan

Status: draft for review. Nothing in `lib/` is built against this yet — this is
the shape to argue with before we write code.

## Goals

- Render a grid of cells with a `CustomPainter`, nothing else. No background,
  no chrome — the host app supplies that.
- Work for the GitHub-contributions calendar case *and* the arbitrary
  rows/columns case (à la `fl_heatmap`) through the same engine.
- Full type safety for user data — no downcasting a base class.
- Cheap to animate: driving a cell property (size, opacity, color mix) from
  scroll or a controller must never force a widget rebuild.
- Exactly one way to pick a cell's color: a fixed palette *or* a callback,
  enforced by the type system, not a runtime assert.

## Non-goals (v1)

- Built-in tooltips/legends as full widgets (we can expose the data needed to
  build them, but won't ship opinionated UI for them yet).
- Scroll/zoom/pan behavior itself. **Not a widget feature at all, by design:**
  once a `Heatmap` can report its own real (fixed-cell-size) size instead of
  always shrinking to fit — see "Cell sizing" below — dropping it in an
  ordinary `SingleChildScrollView` just works, the same as any other
  oversized child. No `HeatmapScrollView` wrapper, no scroll controller
  owned by the package.
- Cell virtualization (only painting on-screen cells). Deliberately skipped:
  even a multi-year calendar is on the order of ~1000-2000 simple
  `canvas.drawPath` calls per frame, trivial for Skia/Impeller. Virtualizing
  would require the painter to know the current scroll offset, which
  conflicts with it being a plain, self-contained `CustomPainter`. Revisit
  only if profiling an actual pathological case (tens of thousands of
  cells) shows a real cost — don't preempt it.
- RTL-aware layout beyond what `Directionality` gives us for free — flag as a
  follow-up if it turns out to need explicit handling.

## Core concepts

### 1. `HeatmapGrid<T>` — the data source

Everything downstream only ever asks a grid for its dimensions and what's at
`(row, col)`. It has no idea whether it's a calendar or an arbitrary matrix.

```dart
abstract class HeatmapGrid<T> {
  int get rowCount;
  int get columnCount;

  /// Null means "no cell data here" (e.g. padding days before Jan 1).
  T? cellAt(int row, int col);

  factory HeatmapGrid.dense(List<List<T?>> rows) = DenseHeatmapGrid<T>;

  factory HeatmapGrid.sparse({
    required int rowCount,
    required int columnCount,
    required Map<(int row, int col), T> cells,
  }) = SparseHeatmapGrid<T>;
}
```

### 2. Calendar layout — a factory on top, not a separate type

The GitHub-style calendar is just a `HeatmapGrid<T>` produced by a factory
that knows how to turn a date range into rows/columns. It carries the date
per cell so callbacks can use it, without polluting the generic grid with a
`date` field it doesn't need for the non-calendar case.

```dart
typedef HeatmapCalendarCell<T> = ({DateTime date, T value});

class CalendarHeatmapGrid {
  static HeatmapGrid<HeatmapCalendarCell<T>> fromDateRange<T>({
    required DateTime start,
    required DateTime end,
    required T? Function(DateTime day) valueForDay,
    int firstDayOfWeek = DateTime.monday,
  }) { /* builds a rectangular List<List<HeatmapCalendarCell<T>?>> and
          returns HeatmapGrid.dense(rows) */ }
}
```

**Decided (was open question 2):** the date rides inside `T` as a plain
record field, not as a special field on `HeatmapGrid` or
`HeatmapCellContext`. `fromDateRange` is sugar over `HeatmapGrid.dense` —
there is no distinct "calendar grid" type, no `dateAt` method, and no
`is CalendarHeatmapGrid` check anywhere in the painter or widget. A
non-calendar consumer (arbitrary rows/columns, e.g. a
electricity-usage-by-hour grid) never sees a `date` field of any kind — the
concept doesn't exist outside this factory. Calendar consumers read
`cell.data.date` exactly like they'd read any other field of their own data.
A day outside `[start, end]`, or where `valueForDay` returns null, is empty
via the ordinary `cellAt` returning null — identical to every other grid,
no separate "padding" concept to special-case.

### 3. What a callback receives

```dart
typedef HeatmapCellContext<T> = ({T data, int row, int col});
```

Color resolver, tap handler, semantics-label builder — all of them take this
record. No subclassing, no casting.

### 4. Color resolution — palette or builder, not both

```dart
sealed class HeatmapColorResolver<T> {
  /// Linear gradient across `colors`. `value` extracts the number used to
  /// place a cell on the gradient. The resolver scans the grid once for the
  /// min/max value (or uses `range` if you pass one) and does the
  /// normalization itself — no clamping/division math on the caller's side.
  const factory HeatmapColorResolver.palette({
    required List<Color> colors,
    required num Function(T data) value,
    bool reversed, // true: highest value -> colors.first instead of .last
    (num min, num max)? range, // skip the auto min/max scan, use this instead
  }) = _PaletteColorResolver<T>;

  const factory HeatmapColorResolver.builder(
    Color Function(HeatmapCellContext<T> cell) resolve,
  ) = _BuilderColorResolver<T>;

  // Planned, not v1: HeatmapColorResolver.thresholds — a step-function
  // variant taking ordered (num floor, Color) pairs, matching GitHub's real
  // bucketing (0 / 1-3 / 4-6 / 7-9 / 10+) instead of a continuous gradient.
  // Revisit once `.palette` above is settled.
}
```

Being `sealed` with only factory constructors means there's no "what if
someone sets both" state to guard against at runtime — the widget just takes
one `HeatmapColorResolver<T>` and switches on it internally.

Edge case to decide: what does `.palette` do when the scanned min equals the
max (every cell the same value, or only one cell)? Proposal: fall back to
`colors.first` — no variation to show, no divide-by-zero. Flag if you want
different behavior (e.g. the midpoint color instead).

The min/max scan happens once, when the resolver/grid is built — not per
frame — so it's cheap regardless of grid size.

### 5. Cell geometry — shape is a callback too

For "most customizable," cell shape shouldn't be a fixed enum ceiling
(square/circle/rounded-rect). Default to an enum for the common cases, escape
hatch to a path builder for anything else:

```dart
sealed class HeatmapCellShape {
  const factory HeatmapCellShape.rect({double cornerRadius}) = _RectShape;
  const factory HeatmapCellShape.circle() = _CircleShape;
  const factory HeatmapCellShape.custom(Path Function(Rect bounds) build) = _CustomShape;
}
```

### 6. The painter

```dart
class HeatmapPainter<T> extends CustomPainter {
  HeatmapPainter({
    required this.grid,
    required this.colorResolver,
    required this.cellShape,
    required this.spacing,
    this.emptyCellColor,
    Listenable? repaint,
  }) : super(repaint: repaint);

  final HeatmapGrid<T> grid;
  final HeatmapColorResolver<T> colorResolver;
  final HeatmapCellShape cellShape;
  final double spacing;
  final Color? emptyCellColor;

  // Paint objects are created once in the constructor / lazily cached on
  // first use, never inside paint(). paint() only computes rects and draws.

  @override
  bool shouldRepaint(covariant HeatmapPainter<T> old) => ...; // shallow field compare
}
```

`repaint` is the whole animation story: pass an `Animation<double>`, a
`ValueNotifier`, or anything `Listenable` that you update from a scroll
listener, and the painter repaints on every tick *without the widget above it
ever rebuilding*. This is the fix for the jank from your earlier attempt —
no `setState` in the loop, and the `CustomPaint`'s box size stays constant so
there's no relayout, only redraws.

### 7. The widget

```dart
class Heatmap<T> extends StatelessWidget {
  const Heatmap({
    required this.grid,
    required this.colorResolver,
    this.cellShape = const HeatmapCellShape.rect(),
    this.spacing = 2,
    this.repaint,
    this.onCellTap,
    super.key,
  });

  final HeatmapGrid<T> grid;
  final HeatmapColorResolver<T> colorResolver;
  final HeatmapCellShape cellShape;
  final double spacing;
  final Listenable? repaint;
  final void Function(HeatmapCellContext<T> cell)? onCellTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: HeatmapPainter<T>(
        grid: grid,
        colorResolver: colorResolver,
        cellShape: cellShape,
        spacing: spacing,
        repaint: repaint,
      ),
      // hit-testing for onCellTap layered via a GestureDetector +
      // coordinate math shared with the painter's layout helper.
    );
  }
}
```

Thin on purpose — `HeatmapPainter` is exported too, for anyone who wants to
compose it into their own `RenderObject`/`CustomPaint` setup directly.

### 8. Cell sizing — derived vs fixed, and how scrolling falls out of it

The sketch above always divides whatever box `Heatmap` is given by
`rowCount`/`columnCount` — cells shrink/grow to fit exactly. That's fine for
a compact heatmap, but it's *impossible* to drop into a horizontal scroll
view: a `SingleChildScrollView(scrollDirection: horizontal)` gives its child
unbounded width, and dividing "unbounded" by a column count doesn't work.

Real, shipped fix: `HeatmapLayout` (the shared geometry helper used by both
the painter and hit-testing) takes optional `cellWidth`/`cellHeight`. When
given, that axis gets a fixed cell size instead of a derived one, and
`HeatmapLayout.contentSize` reports the grid's *real* size — which can be
bigger than the viewport. `Heatmap` uses `contentSize` as the size it hands
to `CustomPaint`, so with a fixed cell size the widget has genuine intrinsic
size, the same way a fixed-size `Image` does. That's the entire scrolling
story: `SingleChildScrollView(scrollDirection: Axis.horizontal, child:
Heatmap(cellWidth: 12, cellHeight: 12, ...))` just works, because Flutter's
ordinary "child bigger than viewport" handling applies. No wrapper widget,
no virtualization (see "Non-goals") — see example 7 for the full pattern,
including a frozen (non-scrolling) row-label sidebar next to it.

A distinct case fixed cell size doesn't cover: *animating* the cell size
itself (a shrinking "sticky" heatmap header above a growing list on scroll —
example 6). That's not a paint-only change like color or corner radius:
`contentSize` changes every frame, so `CustomPaint`'s allocated size has to
change too, which `repaint: Listenable` fundamentally can't do (it only ever
triggers a repaint of an *already-allocated* canvas). A rebuild is
unavoidable here. The fix isn't to avoid the rebuild, it's to scope it: wrap
just the `Heatmap` (inside its own `SingleChildScrollView`, inside an
animated-height box) in a `ValueListenableBuilder`, so only that narrow
subtree re-lays-out on every scroll tick — the enclosing page, list, and
scroll listener are never rebuilt. This is the actual resolution to the
original "cell resizing was dropping FPS" problem from the top of this
plan: the mistake wasn't using a rebuild for a layout-affecting property,
it was not scoping that rebuild narrowly enough.

**Sizing invariant, learned the hard way:** the first version of example 6
animated *both* `cellWidth` and `cellHeight` together inside an
independently fixed-height box. At the larger end of that animation, the 7
rows' actual content height exceeded the box, and the scroll view's
non-scrolling cross axis silently clipped whatever didn't fit — rows
appeared to pop in and out of existence as the user scrolled, since the
box's height and the grid's content height could independently disagree.
Fixed by never fixing both ends of the same relationship: cell **width**
stays explicit (so ~3 years of columns overflow and need horizontal
scrolling, independent of anything vertical), cell **height** is left
derived (`cellHeight` omitted, so `HeatmapLayout` computes it as `box
height / rowCount`) — whatever height the animation gives the box, all 7
rows fit it exactly, by construction, never fewer. The general rule this
generalizes to: unless a host deliberately caps `Heatmap`'s height with
something like a `SizedBox` shorter than its content (which is a legitimate
choice — that's what fixed cell size *is for*, to allow deliberate
scrollable overflow), `Heatmap` should never end up silently hiding rows.
`HeatmapLayout.cellWidth`/`cellHeight` now assert with a clear message
(instead of silently computing infinity, which previously surfaced as a
much more confusing low-level Flutter rendering crash) if derivation is
attempted against an unbounded size with no explicit cell size given — that
combination has no sensible answer, so it fails loudly in debug builds
instead of misbehaving.

### 9. Row/column labels

Originally scoped out of v1 (see the now-superseded open question 1 below) —
reversed after dogfooding: hand-rolling a `Stack` of `Positioned` labels
against `HeatmapLayout` for every calendar example was real, repeated
busywork, and calendar month labels are *sparse* (a label only where a new
month starts, not every column), which makes the manual version worse, not
better, as data grows.

Shipped shape: `Heatmap` takes `rowLabelBuilder`/`columnLabelBuilder`
(`Widget? Function(int index)` — null skips that index) plus
`rowLabelWidth`/`columnLabelHeight` to reserve space (both default to 0, so
this is fully opt-in). The widget positions each non-null label itself,
against the same `HeatmapLayout` it already computes for hit-testing — no
new geometry concept, just reusing the existing one.

The painter still draws cells only; labels are ordinary widgets layered in
a `Stack` by `Heatmap.build()`, not canvas-drawn text. That keeps arbitrary
label styling (fonts, rich text, theming) free, and keeps `HeatmapPainter`
free of a `BuildContext`/`TextPainter` dependency it doesn't otherwise need.

For the calendar case specifically, a plain `int` column index is useless to
the caller — they don't have the grid to look up a date from it (`Heatmap.
calendar` builds it internally). So `Heatmap.calendar` exposes calendar-aware
builders instead: `monthLabelBuilder(DateTime monthStart)`, invoked only at
columns where a new month actually starts (via `monthBoundaryColumns`, which
shares its week-alignment math with `CalendarHeatmapGrid.fromDateRange` so
the two can never disagree on which column a date lands in), and
`weekdayLabelBuilder(int weekday)` (`0` = `firstDayOfWeek`), which is just
the base widget's row builder forwarded through unchanged since weekdays
don't need date-awareness.

### 10. Frozen labels and jumping to a cell

`Heatmap`'s own label builders (above) position labels *inside* the same
widget as the grid — fine normally, but wrong for a frozen weekday sidebar
next to a horizontally-scrolling calendar (the look GitHub itself uses):
wrapping the whole `Heatmap` in a scroll view would scroll the labels away
with it. Shipped two small standalone widgets instead of baking "frozen"
into `Heatmap` itself: `HeatmapRowLabels` and `HeatmapColumnLabels`, each
taking the same `cellHeight`/`cellWidth` + `spacing` a paired `Heatmap`
uses, computing the same `HeatmapLayout` internally so the two can't drift
apart. The host places one outside their own `SingleChildScrollView`, the
`Heatmap` (with a matching fixed cell size) inside it — ordinary
composition again, not a new concept in `Heatmap` itself.

Also shipped `scrollHeatmapCellIntoView({controller, layout, row, col,
alignment, duration, curve})` — a plain function, not a `Heatmap` method,
since `Heatmap` doesn't own a `ScrollController` (see "Cell sizing" above).
It reads whichever axis the given `ScrollController` is actually scrolling
and animates to the target cell, clamped to the scrollable range. See
example 7's "jump to start/latest" buttons.

## Package layout

```text
lib/
  heatmap_q.dart                 // exports only
  src/
    grid/
      heatmap_grid.dart          // HeatmapGrid<T>, DenseHeatmapGrid, SparseHeatmapGrid
      calendar_heatmap_grid.dart // fromDateRange factory, monthBoundaryColumns
    color/
      heatmap_color_resolver.dart
    geometry/
      heatmap_cell_shape.dart
    heatmap_cell_context.dart
    heatmap_layout.dart           // shared geometry: derived or fixed cell size
    heatmap_axis_labels.dart      // HeatmapRowLabels, HeatmapColumnLabels
    heatmap_scroll.dart           // scrollHeatmapCellIntoView
    heatmap_painter.dart
    heatmap.dart                  // the widget, + Heatmap.calendar
```

## Examples

### Example 1 — GitHub-style calendar (the original ask)

```dart
Heatmap.calendar<int>(
  start: DateTime(2025, 1, 1),
  end: DateTime(2025, 12, 31),
  valueForDay: (day) => commitCounts[day], // int? — null = no data
  colorResolver: HeatmapColorResolver.palette(
    colors: [Colors.grey.shade200, Colors.green.shade200, Colors.green.shade500, Colors.green.shade900],
    value: (cell) => cell.value, // cell.date is there too, if a callback needs it
  ),
);
```

`Heatmap.calendar` is a static method, not a constructor (a named constructor of `Heatmap<T>` must return `Heatmap<T>`, but this needs to return `Heatmap<HeatmapCalendarCell<T>>`) — it builds the `CalendarHeatmapGrid` and wires it up in one call so the caller doesn't have to spell out `Heatmap<HeatmapCalendarCell<int>>` themselves. Dropping to `Heatmap(grid: CalendarHeatmapGrid.fromDateRange(...), ...)` directly still works if you want the grid as a separate value (e.g. to reuse across widgets).

No clamping or dividing by an assumed max — the resolver scans the grid's
actual commit counts once and maps the lowest to `colors.first`, highest to
`colors.last`.

### Example 2 — Custom rows & columns (fl_heatmap-style)

```dart
final grid = HeatmapGrid.dense<double>([
  [12.4, 9.1, null, 3.2],   // 2022
  [8.0, 11.5, 6.6, 4.1],    // 2021
  [5.5, 7.7, 9.9, 2.0],     // 2020
]);

Heatmap<double>(
  grid: grid,
  colorResolver: HeatmapColorResolver.builder(
    (cell) => Color.lerp(Colors.blue.shade100, Colors.blue.shade900, cell.data / 15)!,
  ),
);
// row/column *labels* ('2022', 'Jan', ...) are a separate concern — see
// open question about a LabeledHeatmapGrid wrapper below.
```

### Example 3 — Custom color callback + custom cell shape

```dart
Heatmap<Task>(
  grid: taskGrid,
  colorResolver: HeatmapColorResolver.builder(
    (cell) => cell.data.isBlocked ? Colors.red : Colors.grey.shade300,
  ),
  cellShape: HeatmapCellShape.custom(
    (bounds) => Path()..addOval(bounds.deflate(bounds.width * 0.1)),
  ),
);
```

### Example 4 — Animating cell size from scroll, without jank

**Correction:** this snippet, as originally sketched here, doesn't actually
work — `repaint` only triggers a repaint of an *already-allocated* canvas,
it can't resize it, and cell size is a layout property (`contentSize`
changes with it). Driving `cellSize` through `repaint` alone would just
repaint at the old size forever. See "Cell sizing" (section 8) and the
sizing invariant below it for what actually ships: a `ValueListenableBuilder`
scoped tightly around the `Heatmap`, so the *rebuild* this genuinely
requires stays cheap, plus deriving one axis (`cellHeight`) from the box
instead of animating both axes independently — which is also what avoids
the row-clipping bug that motivated writing that invariant down. Example 6
is the real, working version of this idea.

```dart
final heatmapHeight = ValueNotifier<double>(150);

NotificationListener<ScrollNotification>(
  onNotification: (n) {
    final t = (n.metrics.pixels / n.metrics.maxScrollExtent).clamp(0.0, 1.0);
    heatmapHeight.value = 150 - t * (150 - 70);
    return false; // no setState anywhere in this path
  },
  child: ValueListenableBuilder<double>(
    valueListenable: heatmapHeight,
    builder: (context, height, _) => SizedBox(
      height: height,
      child: Heatmap<int>(grid: grid, colorResolver: resolver, cellWidth: 12),
      // cellHeight omitted on purpose — derived as height / rowCount, so
      // rows can never be clipped regardless of what height animates to.
    ),
  ),
);
```

## Open questions / decisions needed

1. ~~Row/column labels for the custom-grid case.~~ **Reversed, then
   resolved:** originally left out of v1 as a host-app concern. That held up
   fine for dense labels (every row/column has one — a plain `Row`/`Column`
   of `Expanded` labels works, see examples 3 and 5), but broke down for
   *sparse* ones — calendar month labels appear only where a new month
   starts, and hand-rolling that position math (a `Stack` of `Positioned`
   widgets against `HeatmapLayout`) for every consumer was real, repeated
   busywork. Shipped `rowLabelBuilder`/`columnLabelBuilder` on `Heatmap`
   instead (see "Row/column labels" above) — not a `LabeledHeatmapGrid<T>`
   wrapper, since the labels are still just widgets the host builds, only
   the *positioning* moved into the package.
2. ~~Date threading in the calendar grid.~~ **Resolved:** record-in-`T`
   (`HeatmapCalendarCell<T> = ({DateTime date, T value})`), not a `dateAt`
   method + a nullable `date` field on the shared `HeatmapCellContext`. The
   first build actually shipped the `dateAt`/nullable-field version and it
   was the wrong call — every non-calendar consumer was carrying a
   permanently-null `date` field, and the painter/widget both needed a
   runtime `is CalendarHeatmapGrid` check to populate it. Switched so the
   engine has zero calendar-specific code anywhere outside
   `calendar_heatmap_grid.dart`.
3. **Empty/null cells.** Skip drawing entirely, or draw with
   `emptyCellColor`/a distinct shape? Matters for hit-testing too — should
   `onCellTap` fire for empty cells?
4. ~~Value normalization for the palette resolver.~~ **Resolved:** `.palette`
   now takes `value: num Function(T)` and auto-scans the grid for min/max
   instead of asking the caller for a 0..1 `normalize`. Still open: is
   `colors.first` the right fallback when min == max (see the edge case note
   in section 4), and should `HeatmapColorResolver.thresholds` (the
   GitHub-style step-function variant) land in v1 or after?
5. **Interaction beyond tap.** Hover (desktop/web) and long-press for
   tooltips — in scope for v1 or a later phase?
6. **Accessibility.** Do we want a `semanticsLabel` callback per cell for
   screen readers now, or defer until there's a concrete consumer need?

## Suggested v1 milestones

1. ~~`HeatmapGrid<T>` + `Dense`/`Sparse` implementations, unit-tested.~~ Done.
2. ~~`HeatmapColorResolver<T>` (palette + builder) + `HeatmapCellShape`.~~ Done.
3. ~~`HeatmapPainter<T>` — static grid, no animation yet.~~ Done (unit-tested
   via the pure resolver/layout functions rather than a golden test).
4. ~~`Heatmap<T>` widget wrapping the painter, `repaint` wired through.~~ Done.
5. ~~`CalendarHeatmapGrid`/`fromDateRange` factory.~~ Done.
6. ~~Tap hit-testing (`onCellTap`).~~ Done.
7. ~~Fixed `cellWidth`/`cellHeight` sizing, so a `Heatmap` can report a real
   (scrollable) size instead of always shrinking to fit.~~ Done.
8. ~~`rowLabelBuilder`/`columnLabelBuilder` + `Heatmap.calendar`'s
   `monthLabelBuilder`/`weekdayLabelBuilder`.~~ Done.
9. ~~Example app: calendar heatmap (plain, labeled, and horizontally
   scrollable with frozen labels), custom-grid heatmap, custom color/shape,
   a domain-data (non-calendar) grid, and a scroll-driven animation demo, in
   `example/`.~~ Done — 7 examples, simplest to most complex.
10. ~~`HeatmapRowLabels`/`HeatmapColumnLabels` for a frozen sidebar/header
    next to a fixed-cell-size, scrolled `Heatmap`.~~ Done.
11. ~~`scrollHeatmapCellIntoView` — jump a host's `ScrollController` to a
    specific cell.~~ Done.

Remaining before this is a real v1: resolve the still-open questions above
(thresholds resolver, hover/tooltip interaction, accessibility), and decide
whether `HeatmapColorResolver.thresholds` ships before or after publishing.
