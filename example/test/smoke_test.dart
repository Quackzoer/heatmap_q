import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heatmap_q/heatmap_q.dart';

void main() {
  testWidgets('every example screen opens and renders without throwing', (tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();

    final tileCount = find.byType(ListTile).evaluate().length;
    expect(tileCount, greaterThan(0));

    for (var i = 0; i < tileCount; i++) {
      await tester.tap(find.byType(ListTile).at(i));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'example at index $i threw during build/layout');

      // Example 6 owns a live ValueNotifier-driven repaint; give it a beat.
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: 'example at index $i threw after settling');

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('tapping a cell in the interactive examples does not throw', (tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();

    // "4. Custom color + shape" and "5. House electricity usage" both wire
    // up onCellTap and display the tapped cell's data.
    for (final title in ['4. Custom color + shape', '5. House electricity usage']) {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(find.byType(CustomPaint).first));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$title threw on cell tap');

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the sticky heatmap shrinks quickly (not just near the end), and reaching the end does not throw',
      (tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('6. Sticky heatmap, shrinks as you scroll'));
    await tester.pumpAndSettle();

    HeatmapPainter<HeatmapCalendarCell<int>> heatmapPainter() {
      final customPaint = tester.widget<CustomPaint>(
        find.descendant(of: find.byKey(const Key('heatmapBox')), matching: find.byType(CustomPaint)).first,
      );
      return customPaint.painter! as HeatmapPainter<HeatmapCalendarCell<int>>;
    }

    final heightBefore = tester.getSize(find.byKey(const Key('heatmapBox'))).height;
    expect(heatmapPainter().cellWidth, heatmapPainter().cellHeight, reason: 'cells should be square');

    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: find.byKey(const Key('activityLog')), matching: find.byType(Scrollable)),
    );

    // A small scroll — far short of the list's total length, out of
    // thousands of entries — should already noticeably shrink the heatmap.
    // This is the behavior that was broken: progress used to be measured
    // against the list's entire scroll range, so it barely moved until you
    // were nearly at the bottom.
    scrollable.position.jumpTo(50);
    await tester.pumpAndSettle();
    final heightAfterSmallScroll = tester.getSize(find.byKey(const Key('heatmapBox'))).height;
    expect(heightAfterSmallScroll, lessThan(heightBefore), reason: 'heatmap did not shrink after a small scroll');
    expect((heightBefore - heightAfterSmallScroll) / heightBefore, greaterThan(0.1),
        reason: 'shrinking after only 50px of scroll should already be substantial');

    // A regular fling exercises the ordinary scroll-update path and should
    // be more than enough distance to reach full shrink.
    await tester.fling(find.byKey(const Key('activityLog')), const Offset(0, -400), 800);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'threw during an ordinary fling');

    final heightAfterFling = tester.getSize(find.byKey(const Key('heatmapBox'))).height;
    expect(heightAfterFling, lessThan(heightAfterSmallScroll), reason: 'heatmap should keep shrinking');
    expect(heatmapPainter().cellWidth, heatmapPainter().cellHeight, reason: 'cells should stay square while shrinking');

    // Jump straight to the very end — this is what previously triggered
    // "Build scheduled during frame" (the ballistic scroll settling exactly
    // at maxScrollExtent dispatches a notification mid-frame).
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'threw when the list reached its end');

    // Already fully shrunk well before the end, so height shouldn't change
    // further — it should be pinned at the same minimum, not throw, and
    // not shrink past it.
    final heightAtEnd = tester.getSize(find.byKey(const Key('heatmapBox'))).height;
    expect(heightAtEnd, heightAfterFling);
  });

  testWidgets('the jump-to-cell buttons in the scrollable calendar example do not throw', (tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('7. Horizontally scrollable, frozen labels'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jump to latest'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Jump to start'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
