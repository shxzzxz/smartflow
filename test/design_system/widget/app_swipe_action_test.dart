import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_swipe_action.dart';

void main() {
  testWidgets('action background is hidden until the row is dragged', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: AppSwipeAction(
              dismissibleKey: const ValueKey('row'),
              label: '编辑',
              icon: Icons.edit,
              onTriggered: () {},
              child: const SizedBox(height: 60, child: Text('交易记录')),
            ),
          ),
        ),
      ),
    );

    const backgroundKey = ValueKey('app-swipe-action-background');
    expect(tester.getSize(find.byKey(backgroundKey)).width, 0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('交易记录')),
    );
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();

    expect(tester.getSize(find.byKey(backgroundKey)).width, 120);
    await gesture.up();
  });

  testWidgets('action content fits while the background is being revealed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: AppSwipeAction(
              dismissibleKey: const ValueKey('row'),
              label: '编辑',
              icon: Icons.edit,
              onTriggered: () {},
              child: const SizedBox(height: 60, child: Text('交易记录')),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('交易记录')),
    );
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();

    expect(tester.takeException(), isNull);
    await gesture.up();
  });

  testWidgets('right swipe selects primary then secondary action by distance', (
    tester,
  ) async {
    var editCount = 0;
    var deleteCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: AppSwipeAction(
              dismissibleKey: const ValueKey('row'),
              label: '编辑',
              icon: Icons.edit,
              onTriggered: () => editCount++,
              secondaryAction: AppSwipeActionItem(
                label: '删除',
                icon: Icons.delete,
                onTriggered: () => deleteCount++,
                tone: AppSwipeActionTone.danger,
              ),
              child: const SizedBox(height: 60, child: Text('还款记录')),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.text('还款记录'), const Offset(140, 0));
    await tester.pumpAndSettle();
    expect(editCount, 1);
    expect(deleteCount, 0);

    await tester.drag(find.text('还款记录'), const Offset(220, 0));
    await tester.pumpAndSettle();
    expect(editCount, 1);
    expect(deleteCount, 1);
  });

  testWidgets('left swipe does not trigger either action', (tester) async {
    var triggered = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: AppSwipeAction(
              dismissibleKey: const ValueKey('row'),
              label: '编辑',
              icon: Icons.edit,
              onTriggered: () => triggered = true,
              secondaryAction: AppSwipeActionItem(
                label: '删除',
                icon: Icons.delete,
                onTriggered: () => triggered = true,
              ),
              child: const SizedBox(height: 60, child: Text('还款记录')),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.text('还款记录'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(triggered, isFalse);
  });

  testWidgets('single action keeps the original forty percent threshold', (
    tester,
  ) async {
    var editCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: AppSwipeAction(
              dismissibleKey: const ValueKey('row'),
              label: '编辑',
              icon: Icons.edit,
              onTriggered: () => editCount++,
              child: const SizedBox(height: 60, child: Text('交易记录')),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.text('交易记录'), const Offset(140, 0));
    await tester.pumpAndSettle();
    expect(editCount, 0);

    await tester.drag(find.text('交易记录'), const Offset(180, 0));
    await tester.pumpAndSettle();
    expect(editCount, 1);
  });
}
