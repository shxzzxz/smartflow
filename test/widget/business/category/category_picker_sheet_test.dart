import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/widget/business/category/category_picker_sheet.dart';

void main() {
  testWidgets('browses roots and returns a selected child category', (
    tester,
  ) async {
    String? selectedId;
    await tester.pumpWidget(
      _testApp(
        CategoryPickerSheet(
          sections: _sections,
          selectableIds: const {'food', 'lunch', 'salary'},
          selectedId: 'lunch',
          onCategoryTap: (id) => selectedId = id,
        ),
      ),
    );

    expect(find.text('支出'), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('餐饮'), findsWidgets);
    expect(find.text('午餐'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('category-picker-root-salary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('category-picker-option-salary')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('category-picker-option-lunch')),
    );

    expect(selectedId, 'lunch');
  });

  testWidgets('allows selecting a root category from the detail pane', (
    tester,
  ) async {
    String? selectedId;
    await tester.pumpWidget(
      _testApp(
        CategoryPickerSheet(
          sections: _sections,
          selectableIds: const {'food', 'lunch'},
          selectedId: 'food',
          onCategoryTap: (id) => selectedId = id,
        ),
      ),
    );

    expect(find.text('本级分类'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('category-picker-option-food')));

    expect(selectedId, 'food');
  });

  testWidgets(
    'keeps a parent as navigation when only its child is selectable',
    (tester) async {
      await tester.pumpWidget(
        _testApp(
          CategoryPickerSheet(
            sections: _sections,
            selectableIds: const {'lunch'},
            selectedId: null,
            onCategoryTap: (_) {},
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('category-picker-root-food')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('category-picker-option-food')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('category-picker-option-lunch')),
        findsOneWidget,
      );
    },
  );

  testWidgets('does not overflow on a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(
        CategoryPickerSheet(
          sections: const [
            CategoryPickerSection(
              type: AccountType.expense,
              label: '支出',
              nodes: [
                CategoryPickerNode(
                  id: 'long',
                  label: '很长很长的顶层分类名称',
                  children: [
                    CategoryPickerNode(id: 'long-child', label: '很长很长的子分类名称'),
                  ],
                ),
              ],
            ),
          ],
          selectableIds: const {'long', 'long-child'},
          selectedId: 'long-child',
          onCategoryTap: (_) {},
        ),
        textScaler: const TextScaler.linear(1.4),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

const _sections = [
  CategoryPickerSection(
    type: AccountType.expense,
    label: '支出',
    nodes: [
      CategoryPickerNode(
        id: 'food',
        label: '餐饮',
        children: [CategoryPickerNode(id: 'lunch', label: '午餐')],
      ),
    ],
  ),
  CategoryPickerSection(
    type: AccountType.income,
    label: '收入',
    nodes: [CategoryPickerNode(id: 'salary', label: '工资')],
  ),
];

Widget _testApp(Widget child, {TextScaler? textScaler}) {
  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, child) {
      final mediaQuery = MediaQuery.of(context);
      return MediaQuery(
        data: textScaler == null
            ? mediaQuery
            : mediaQuery.copyWith(textScaler: textScaler),
        child: child!,
      );
    },
    home: Scaffold(body: SizedBox(height: 640, child: child)),
  );
}
