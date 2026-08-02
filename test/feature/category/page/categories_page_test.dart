// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/category/page/categories_page.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';

void main() {
  Widget buildPage({
    required List<CategoryNode> expenseTree,
    List<Account> archivedExpense = const [],
    Map<String, Account> accountsById = const {},
  }) {
    return ProviderScope(
      overrides: [
        categoryTreeProvider(
          AccountType.expense,
        ).overrideWith((ref) => Stream.value(expenseTree)),
        categoryTreeProvider(
          AccountType.income,
        ).overrideWith((ref) => Stream.value(const <CategoryNode>[])),
        archivedCategoriesProvider(
          AccountType.expense,
        ).overrideWith((ref) => Stream.value(archivedExpense)),
        archivedCategoriesProvider(
          AccountType.income,
        ).overrideWith((ref) => Stream.value(const <Account>[])),
        accountsByIdProvider.overrideWith((ref) => Stream.value(accountsById)),
      ],
      child: const MaterialApp(home: CategoriesPage()),
    );
  }

  testWidgets('expands root rows and shows archived merge destinations', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final food = _category('food', name: '餐饮');
    final breakfast = _category('breakfast', name: '早餐', parentId: 'food');
    final legacy = _category(
      'legacy',
      name: '旧分类',
      parentId: 'breakfast',
      archived: true,
    );

    await tester.pumpWidget(
      buildPage(
        expenseTree: [
          CategoryNode(account: food, children: [breakfast]),
        ],
        archivedExpense: [legacy],
        accountsById: {
          food.id: food,
          breakfast.id: breakfast,
          legacy.id: legacy,
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('1 个子分类'), findsOneWidget);
    expect(find.text('早餐'), findsNothing);

    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    expect(find.text('早餐'), findsOneWidget);
    expect(find.text('新增子分类'), findsOneWidget);

    expect(find.text('已归档'), findsOneWidget);
    expect(find.text('旧分类'), findsOneWidget);
    expect(find.text('并入 早餐'), findsOneWidget);
  });

  testWidgets(
    'opens action sheet without move option for roots with children',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final food = _category('food', name: '餐饮');
      final breakfast = _category('breakfast', name: '早餐', parentId: 'food');

      await tester.pumpWidget(
        buildPage(
          expenseTree: [
            CategoryNode(account: food, children: [breakfast]),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('更多操作').first);
      await tester.pumpAndSettle();

      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('新增子分类'), findsOneWidget);
      expect(find.text('移动到…'), findsNothing);
      expect(find.text('删除'), findsOneWidget);
    },
  );

  testWidgets('offers move option for child categories', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final food = _category('food', name: '餐饮');
    final breakfast = _category('breakfast', name: '早餐', parentId: 'food');

    await tester.pumpWidget(
      buildPage(
        expenseTree: [
          CategoryNode(account: food, children: [breakfast]),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作').last);
    await tester.pumpAndSettle();

    expect(find.text('编辑'), findsOneWidget);
    // 页面展开区固定有一行"新增子分类"；子分类的操作菜单里不应再出现。
    expect(find.text('新增子分类'), findsOneWidget);
    expect(find.text('移动到…'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });
}

Account _category(
  String id, {
  required String name,
  String? parentId,
  bool archived = false,
}) {
  return Account(
    id: id,
    name: name,
    type: AccountType.expense,
    parentId: parentId,
    balance: const Money(minorUnits: 0),
    archivedAt: archived ? DateTime(2026) : null,
  );
}
