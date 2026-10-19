import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/feature/statistics/widget/statistics_composition_list.dart';

void main() {
  testWidgets('shows five items before folding a longer composition list', (
    tester,
  ) async {
    await tester.pumpWidget(_host(List.generate(5, (index) => index)));
    expect(find.byKey(const ValueKey('item-4')), findsOneWidget);
    expect(find.textContaining('查看全部'), findsNothing);

    await tester.pumpWidget(_host(List.generate(6, (index) => index)));
    expect(find.byKey(const ValueKey('item-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('item-5')), findsNothing);
    expect(find.text('查看全部 6 项'), findsOneWidget);

    await tester.tap(find.text('查看全部 6 项'));
    await tester.pump();
    expect(find.byKey(const ValueKey('item-5')), findsOneWidget);
    expect(find.text('收起'), findsOneWidget);

    await tester.tap(find.text('收起'));
    await tester.pump();
    expect(find.byKey(const ValueKey('item-5')), findsNothing);
  });

  testWidgets('collapses again when the composition reset token changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(List.generate(6, (index) => index), resetToken: 'expense'),
    );
    await tester.tap(find.text('查看全部 6 项'));
    await tester.pump();
    expect(find.byKey(const ValueKey('item-5')), findsOneWidget);

    await tester.pumpWidget(
      _host(List.generate(6, (index) => index), resetToken: 'income'),
    );
    expect(find.byKey(const ValueKey('item-5')), findsNothing);
    expect(find.text('查看全部 6 项'), findsOneWidget);
  });
}

Widget _host(List<int> items, {Object? resetToken}) {
  return MaterialApp(
    home: Scaffold(
      body: StatisticsCompositionList<int>(
        key: const ValueKey('composition'),
        items: items,
        resetToken: resetToken,
        itemBuilder: (context, item, index) =>
            Text('item $item', key: ValueKey('item-$item')),
      ),
    ),
  );
}
