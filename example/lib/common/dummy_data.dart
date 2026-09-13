import 'dart:math';

/// Deterministic fake commit-style activity: some days have none, most have
/// a handful, a few are busy.
Map<DateTime, int> generateCommitData({
  required DateTime start,
  required DateTime end,
  int seed = 1,
  int maxPerDay = 10,
  double activeChance = 0.65,
}) {
  final random = Random(seed);
  final data = <DateTime, int>{};
  for (var day = DateTime(start.year, start.month, start.day);
      !day.isAfter(end);
      day = day.add(const Duration(days: 1))) {
    data[day] = random.nextDouble() > activeChance ? 0 : 1 + random.nextInt(maxPerDay);
  }
  return data;
}

/// A dense `rows x columns` grid of doubles in [min, max], for the
/// custom-grid and usage examples.
List<List<double>> generateUsageGrid({
  required int rows,
  required int columns,
  int seed = 2,
  double min = 20,
  double max = 420,
}) {
  final random = Random(seed);
  return List.generate(
    rows,
    (_) => List.generate(columns, (_) => min + random.nextDouble() * (max - min)),
  );
}
