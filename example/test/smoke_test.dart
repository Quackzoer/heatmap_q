import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('scrolling the animated example does not throw', (tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('6. Scroll-driven zoom'));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(ListView), const Offset(0, -400), 800);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
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
