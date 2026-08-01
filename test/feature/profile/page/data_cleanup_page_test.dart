import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/profile/page/data_cleanup_page.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionQueryServiceProvider.overrideWith(
            (ref) => _FakeTransactionQueryService(),
          ),
          categoryQueryServiceProvider.overrideWith(
            (ref) => _FakeCategoryQueryService(),
          ),
          accountQueryServiceProvider.overrideWith(
            (ref) => _FakeAccountQueryService(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const DataCleanupPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('打开分类多选面板并回填已选数量', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('选择分类'), findsOneWidget);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('午餐'), findsOneWidget);

    await tester.tap(find.text('餐饮'));
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('选择分类'), findsNothing);
    expect(find.text('已选 2 项'), findsOneWidget);
  });

  testWidgets('打开账户多选面板并回填已选数量', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('账户'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('选择账户'), findsOneWidget);
    expect(find.text('现金'), findsOneWidget);

    await tester.tap(find.text('现金'));
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('选择账户'), findsNothing);
    expect(find.text('已选 1 项'), findsOneWidget);
  });
}

Account _category(String id, String name) {
  return Account(
    id: id,
    name: name,
    type: AccountType.expense,
    balance: const Money(minorUnits: 0),
  );
}

Account _account(String id, String name) {
  return Account(
    id: id,
    name: name,
    type: AccountType.asset,
    balance: const Money(minorUnits: 0),
  );
}

class _FakeTransactionQueryService implements TransactionQueryService {
  @override
  Stream<TransactionCleanupPreview> watchCleanupPreview(
    TransactionCleanupQuery query,
  ) {
    return Stream.value(TransactionCleanupPreview.empty);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

// find* 延迟返回，模拟真机上选项来自异步数据库查询的时序。
class _FakeCategoryQueryService implements CategoryQueryService {
  @override
  Future<List<CategoryNode>> findCategoryTree(AccountType type) {
    return Future.delayed(const Duration(milliseconds: 50), () {
      if (type != AccountType.expense) return const <CategoryNode>[];
      return [
        CategoryNode(
          account: _category('cat-food', '餐饮'),
          children: [_category('cat-lunch', '午餐')],
        ),
      ];
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeAccountQueryService implements AccountQueryService {
  @override
  Future<List<Account>> findAccounts(Set<AccountType> types) {
    return Future.delayed(
      const Duration(milliseconds: 50),
      () => [_account('acc-cash', '现金')],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
