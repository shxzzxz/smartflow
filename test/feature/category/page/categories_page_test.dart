// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/category/page/categories_page.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';

void main() {
  Widget buildPage({
    required List<CategoryNode> expenseTree,
    Map<String, Account> accountsById = const {},
    CategoryAppService? categoryAppService,
  }) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const CategoriesPage()),
        GoRoute(
          path: '/category/:id/transactions',
          builder: (context, state) =>
              Scaffold(body: Text('分类流水:${state.pathParameters['id']}')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        if (categoryAppService != null)
          categoryAppServiceProvider.overrideWith((ref) => categoryAppService),
        categoryTreeProvider(
          AccountType.expense,
        ).overrideWith((ref) => Stream.value(expenseTree)),
        categoryTreeProvider(
          AccountType.income,
        ).overrideWith((ref) => Stream.value(const <CategoryNode>[])),
        accountsByIdProvider.overrideWith((ref) => Stream.value(accountsById)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('expands root rows to show child categories', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final food = _category('food', name: '餐饮');
    final breakfast = _category('breakfast', name: '早餐', parentId: 'food');

    await tester.pumpWidget(
      buildPage(
        expenseTree: [
          CategoryNode(account: food, children: [breakfast]),
        ],
        accountsById: {food.id: food, breakfast.id: breakfast},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('1 个子分类'), findsOneWidget);
    expect(find.text('早餐'), findsNothing);

    await tester.tap(find.byTooltip('展开子分类'));
    await tester.pumpAndSettle();

    expect(find.text('早餐'), findsOneWidget);
    expect(find.text('新增子分类'), findsOneWidget);
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
      expect(find.text('迁移交易'), findsOneWidget);
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

    await tester.tap(find.byTooltip('展开子分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作').last);
    await tester.pumpAndSettle();

    expect(find.text('编辑'), findsOneWidget);
    // 页面展开区固定有一行"新增子分类"；子分类的操作菜单里不应再出现。
    expect(find.text('新增子分类'), findsOneWidget);
    expect(find.text('移动到…'), findsOneWidget);
    expect(find.text('迁移交易'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('opens root category transactions when the row is tapped', (
    tester,
  ) async {
    final food = _category('food', name: '餐饮');

    await tester.pumpWidget(
      buildPage(
        expenseTree: [CategoryNode(account: food, children: const [])],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    expect(find.text('分类流水:food'), findsOneWidget);
  });

  testWidgets('opens child category transactions when the row is tapped', (
    tester,
  ) async {
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

    await tester.tap(find.byTooltip('展开子分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('早餐'));
    await tester.pumpAndSettle();

    expect(find.text('分类流水:breakfast'), findsOneWidget);
  });

  testWidgets('hides migration and deletion actions for system categories', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final systemCategory = _category(
      'fee-expense',
      name: '手续费',
      systemKey: SystemKey.feeExpense,
    );

    await tester.pumpWidget(
      buildPage(
        expenseTree: [
          CategoryNode(account: systemCategory, children: const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();

    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('迁移交易'), findsNothing);
    expect(find.text('删除'), findsNothing);
  });

  testWidgets('filters system categories from migration targets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _category('food', name: '餐饮');
    final systemCategory = _category(
      'fee-expense',
      name: '手续费',
      systemKey: SystemKey.feeExpense,
    );

    await tester.pumpWidget(
      buildPage(
        expenseTree: [
          CategoryNode(account: source, children: const []),
          CategoryNode(account: systemCategory, children: const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('迁移交易'));
    await tester.pumpAndSettle();

    expect(find.text('手续费'), findsOneWidget);
    expect(find.text('没有可用的目标分类，请先新建一个同类型分类。'), findsOneWidget);
  });

  testWidgets('deletes a clean category after the user confirms', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final food = _category('food', name: '餐饮');
    final service = _FakeCategoryAppService(
      preview: CategoryDeletionPreview(
        category: food,
        childCount: 0,
        transactionRefCount: 0,
      ),
    );

    await tester.pumpWidget(
      buildPage(
        expenseTree: [CategoryNode(account: food, children: const [])],
        categoryAppService: service,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除"餐饮"？'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    final command = service.deleteCommands.single;
    expect(command.id, 'food');
  });

  testWidgets(
    'blocks deletion of a referenced category without calling delete',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final food = _category('food', name: '餐饮');
      final service = _FakeCategoryAppService(
        preview: CategoryDeletionPreview(
          category: food,
          childCount: 0,
          transactionRefCount: 3,
        ),
      );

      await tester.pumpWidget(
        buildPage(
          expenseTree: [CategoryNode(account: food, children: const [])],
          categoryAppService: service,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('更多操作').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(find.text('无法删除"餐饮"'), findsOneWidget);
      expect(find.textContaining('被 3 处交易引用'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();

      expect(service.deleteCommands, isEmpty);
    },
  );
}

Account _category(
  String id, {
  required String name,
  String? parentId,
  SystemKey? systemKey,
}) {
  return Account(
    id: id,
    name: name,
    type: AccountType.expense,
    parentId: parentId,
    systemKey: systemKey,
    balance: const Money(minorUnits: 0),
  );
}

class _FakeCategoryAppService implements CategoryAppService {
  _FakeCategoryAppService({required this.preview});

  final CategoryDeletionPreview preview;
  final deleteCommands = <DeleteCategoryCommand>[];

  @override
  Future<Account> createCategory(CreateCategoryCommand command) =>
      throw UnimplementedError();

  @override
  Future<void> deleteCategory(DeleteCategoryCommand command) async {
    deleteCommands.add(command);
  }

  @override
  Future<void> editCategory(EditCategoryCommand command) =>
      throw UnimplementedError();

  @override
  Future<CategoryDeletionPreview> previewCategoryDeletion(
    String categoryId,
  ) async => preview;
}
