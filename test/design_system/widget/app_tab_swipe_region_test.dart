import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/widget/app_tab_swipe_region.dart';

void main() {
  testWidgets('switches one adjacent tab per swipe without wrapping', (
    tester,
  ) async {
    var selected = 0;
    final changes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AppTabSwipeRegion<int>(
              values: const [0, 1, 2],
              selected: selected,
              onChanged: (value) {
                changes.add(value);
                setState(() => selected = value);
              },
              child: Center(child: Text('page $selected')),
            ),
          ),
        ),
      ),
    );

    for (final expected in [1, 2, 2]) {
      await tester.dragFrom(const Offset(700, 300), const Offset(-600, 0));
      await tester.pump();
      expect(find.text('page $expected'), findsOneWidget);
    }
    for (final expected in [1, 0, 0]) {
      await tester.dragFrom(const Offset(100, 300), const Offset(600, 0));
      await tester.pump();
      expect(find.text('page $expected'), findsOneWidget);
    }
    expect(changes, [1, 2, 1, 0]);
  });

  testWidgets('ignores short, reversed and cancelled drags', (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(_app(onChanged: changes.add));
    final region = find.byType(AppTabSwipeRegion<int>);

    await tester.drag(region, const Offset(-24, 0));
    final reversed = await tester.startGesture(const Offset(400, 300));
    await reversed.moveBy(const Offset(-120, 0));
    await reversed.moveBy(const Offset(120, 0));
    await reversed.up();
    expect(changes, isEmpty);
    final cancelled = await tester.startGesture(const Offset(400, 300));
    await cancelled.moveBy(const Offset(-120, 0));
    await cancelled.cancel();
    await tester.drag(region, const Offset(-24, 0));
    expect(changes, isEmpty);

    await tester.drag(region, const Offset(-100, 0));
    expect(changes, [2]);
  });

  testWidgets('preserves vertical scrolling and child horizontal gestures', (
    tester,
  ) async {
    final vertical = ScrollController();
    final horizontal = ScrollController();
    addTearDown(vertical.dispose);
    addTearDown(horizontal.dispose);
    final changes = <int>[];
    await tester.pumpWidget(
      _app(
        onChanged: changes.add,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const ValueKey('vertical'),
                controller: vertical,
                children: const [SizedBox(height: 1600)],
              ),
            ),
            SizedBox(
              height: 80,
              child: ListView(
                key: const ValueKey('horizontal'),
                controller: horizontal,
                scrollDirection: Axis.horizontal,
                children: const [SizedBox(width: 1600)],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.drag(
      find.byKey(const ValueKey('vertical')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(vertical.offset, greaterThan(0));
    await tester.drag(
      find.byKey(const ValueKey('horizontal')),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();
    expect(horizontal.offset, greaterThan(0));
    expect(changes, isEmpty);
  });

  testWidgets('follows right-to-left tab order', (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(
      _app(onChanged: changes.add, direction: TextDirection.rtl),
    );
    final region = find.byType(AppTabSwipeRegion<int>);
    await tester.drag(region, const Offset(200, 0));
    await tester.drag(region, const Offset(-200, 0));
    expect(changes, [2, 0]);
  });

  testWidgets('disabling during a drag cancels the pending switch', (
    tester,
  ) async {
    final changes = <int>[];
    await tester.pumpWidget(_app(onChanged: changes.add));
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pumpWidget(_app(onChanged: null));
    await gesture.up();
    await tester.drag(
      find.byType(AppTabSwipeRegion<int>),
      const Offset(-200, 0),
    );
    expect(changes, isEmpty);
  });
}

Widget _app({
  required ValueChanged<int>? onChanged,
  Widget child = const SizedBox.expand(),
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  home: Scaffold(
    body: Directionality(
      textDirection: direction,
      child: AppTabSwipeRegion<int>(
        values: const [0, 1, 2],
        selected: 1,
        onChanged: onChanged,
        child: child,
      ),
    ),
  ),
);
