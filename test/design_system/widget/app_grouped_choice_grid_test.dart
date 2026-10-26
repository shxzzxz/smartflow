import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_grouped_choice_grid.dart';

void main() {
  testWidgets('uses a compact three-column grid at phone width', (
    tester,
  ) async {
    await tester.pumpWidget(_app(width: 328));

    final grid = find.byKey(const ValueKey('app-choice-grid-expense'));
    expect(tester.getSize(grid).height, 136);
    expect(_itemHeight(tester, 0), 64);

    final first = tester.getCenter(_item(0));
    final second = tester.getCenter(_item(1));
    final third = tester.getCenter(_item(2));
    final fourth = tester.getCenter(_item(3));
    expect(second.dy, first.dy);
    expect(third.dy, first.dy);
    expect(fourth.dy, greaterThan(first.dy));
    expect(second.dx, greaterThan(first.dx));
    expect(third.dx, greaterThan(second.dx));
  });

  testWidgets('adds columns with width and caps the row at four', (
    tester,
  ) async {
    await tester.pumpWidget(_app(width: 480));

    final first = tester.getCenter(_item(0));
    final fourth = tester.getCenter(_item(3));
    final fifth = tester.getCenter(_item(4));
    expect(fourth.dy, first.dy);
    expect(fifth.dy, greaterThan(first.dy));
  });

  testWidgets('reduces columns on narrow widths', (tester) async {
    await tester.pumpWidget(_app(width: 200));

    final grid = find.byKey(const ValueKey('app-choice-grid-expense'));
    expect(tester.getSize(grid).height, 208);
    final first = tester.getCenter(_item(0));
    final second = tester.getCenter(_item(1));
    final third = tester.getCenter(_item(2));
    expect(second.dy, first.dy);
    expect(third.dy, greaterThan(first.dy));
  });

  testWidgets('keeps items compact with large text while adapting columns', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(width: 328, itemCount: 2, textScaler: const TextScaler.linear(2)),
    );

    final grid = find.byKey(const ValueKey('app-choice-grid-expense'));
    expect(tester.getSize(grid).height, 88);
    expect(_itemHeight(tester, 0), 88);
    final first = tester.getCenter(_item(0));
    final second = tester.getCenter(_item(1));
    expect(second.dy, first.dy);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports the selected item value', (tester) async {
    String? selectedValue;
    await tester.pumpWidget(
      _app(
        width: 328,
        itemCount: 2,
        onSelected: (item) => selectedValue = item.value,
      ),
    );

    await tester.tap(_item(1));

    expect(selectedValue, 'item-1');
  });

  testWidgets('renders grid items without borders', (tester) async {
    await tester.pumpWidget(
      _app(width: 328, itemCount: 2, selectedId: 'item-0'),
    );

    for (var index = 0; index < 2; index++) {
      final material = tester.widget<Material>(
        find.ancestor(of: _item(index), matching: find.byType(Material)).first,
      );
      expect((material.shape! as RoundedRectangleBorder).side, BorderSide.none);
    }
  });
}

Widget _app({
  required double width,
  int itemCount = 6,
  TextScaler textScaler = TextScaler.noScaling,
  String? selectedId,
  ValueChanged<AppChoiceGridItem<String>>? onSelected,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: AppGroupedChoiceGrid<String>(
              groups: [_group(itemCount)],
              selectedId: selectedId,
              onSelected: onSelected ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

AppChoiceGridGroup<String> _group(int itemCount) {
  return AppChoiceGridGroup(
    id: 'expense',
    label: '支出',
    items: [
      for (var index = 0; index < itemCount; index++)
        AppChoiceGridItem(
          id: 'item-$index',
          value: 'item-$index',
          label: '项目 $index',
          iconBuilder: (context, size) => Icon(Icons.circle, size: size),
        ),
    ],
  );
}

Finder _item(int index) {
  return find.byKey(ValueKey('app-choice-grid-item-expense-item-$index'));
}

double _itemHeight(WidgetTester tester, int index) {
  return tester.getSize(_item(index)).height;
}
