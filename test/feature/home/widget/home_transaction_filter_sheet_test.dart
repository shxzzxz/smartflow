import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/feature/shared/provider/tag_providers.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/home/view_model/home_view_model.dart';
import 'package:smartflow/feature/home/widget/home_transaction_filter_sheet.dart';

import '../../../helper/fake_transaction_tag_repository.dart';

void main() {
  testWidgets('unrestricted dimensions display no condition', (tester) async {
    HomeTransactionFilter? result;
    await tester.pumpWidget(
      ProviderScope(
        child: _TestHost(
          initialFilter: const HomeTransactionFilter.all(),
          onResult: (value) => result = value,
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('不限'), findsNWidgets(3));

    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isActive, isFalse);
  });

  testWidgets('all normalizes both filter dimensions to null', (tester) async {
    HomeTransactionFilter? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagListProvider.overrideWithValue(const AsyncData(<TagView>[])),
        ],
        child: _TestHost(
          initialFilter: HomeTransactionFilter(
            categoryAccountIds: const {'cat-lunch'},
            settlementAccountIds: const {'acc-cash'},
          ),
          onResult: (value) => result = value,
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部'));
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result?.categoryAccountIds, isNull);
    expect(result?.settlementAccountIds, isNull);
  });

  testWidgets('clear treats both filter dimensions as no condition', (
    tester,
  ) async {
    HomeTransactionFilter? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagListProvider.overrideWithValue(const AsyncData(<TagView>[])),
        ],
        child: _TestHost(
          initialFilter: HomeTransactionFilter(
            categoryAccountIds: const {'cat-lunch'},
            settlementAccountIds: const {'acc-cash'},
            tagIds: const {'tag-travel'},
          ),
          onResult: (value) => result = value,
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除'));
    await tester.pumpAndSettle();
    expect(find.text('不限'), findsNWidgets(3));
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    expect(result?.categoryAccountIds, isNull);
    expect(result?.settlementAccountIds, isNull);
    expect(result, isNotNull);
    expect(result!.isActive, isFalse);
  });

  testWidgets('selects an account directly without clearing first', (
    tester,
  ) async {
    HomeTransactionFilter? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagListProvider.overrideWithValue(const AsyncData(<TagView>[])),
        ],
        child: _TestHost(
          initialFilter: const HomeTransactionFilter.all(),
          onResult: (value) => result = value,
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('账户'));
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)),
      everyElement(
        isA<CheckboxListTile>().having((tile) => tile.value, 'value', isFalse),
      ),
    );
    await tester.tap(find.text('现金'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    expect(result?.categoryAccountIds, isNull);
    expect(result?.settlementAccountIds, {'acc-cash'});
  });

  testWidgets('selects a category directly without clearing first', (
    tester,
  ) async {
    HomeTransactionFilter? result;
    await tester.pumpWidget(
      ProviderScope(
        child: _TestHost(
          initialFilter: const HomeTransactionFilter.all(),
          onResult: (value) => result = value,
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<Checkbox>(find.byType(Checkbox)),
      everyElement(
        isA<Checkbox>().having((checkbox) => checkbox.value, 'value', isFalse),
      ),
    );
    await tester.tap(find.text('支出'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).last);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.categoryAccountIds, {'cat-lunch'});
    expect(result!.settlementAccountIds, isNull);
  });

  testWidgets('preserves existing selections when selectors are cancelled', (
    tester,
  ) async {
    HomeTransactionFilter? result;
    await tester.pumpWidget(
      ProviderScope(
        child: _TestHost(
          initialFilter: HomeTransactionFilter(
            categoryAccountIds: const {'cat-lunch'},
            settlementAccountIds: const {'acc-cash'},
          ),
          onResult: (value) => result = value,
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 项'), findsNWidgets(2));

    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('支出'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, isTrue);
    await tester.tap(find.byType(Checkbox).last);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.text('账户'));
    await tester.pumpAndSettle();
    final accountTiles = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(accountTiles.first.value, isTrue);
    expect(accountTiles.last.value, isFalse);
    await tester.tap(find.text('现金'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('已选 1 项'), findsNWidgets(2));

    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.categoryAccountIds, {'cat-lunch'});
    expect(result!.settlementAccountIds, {'acc-cash'});
  });

  testWidgets('selects multiple tags in the home filter', (tester) async {
    final repository = _DelayedTagRepository();
    await repository.insertTag(id: 'tag-travel', name: '旅行');
    await repository.insertTag(id: 'tag-work', name: '出差');
    final service = TagApplicationService(
      repository: repository,
      idGenerator: _NoopIdGenerator(),
      transactionRunner: const _DirectTransactionRunner(),
    );
    HomeTransactionFilter? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tagApplicationServiceProvider.overrideWithValue(service)],
        child: _TestHost(
          initialFilter: const HomeTransactionFilter.all(),
          onResult: (value) => result = value,
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('旅行'));
    await tester.tap(find.text('出差'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    expect(result?.tagIds, {'tag-travel', 'tag-work'});
  });

  testWidgets('waits for tags before opening the tag selector', (tester) async {
    final repository = _DelayedTagRepository();
    await repository.insertTag(id: 'tag-travel', name: '旅行');
    final service = TagApplicationService(
      repository: repository,
      idGenerator: _NoopIdGenerator(),
      transactionRunner: const _DirectTransactionRunner(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tagApplicationServiceProvider.overrideWithValue(service)],
        child: _TestHost(
          initialFilter: const HomeTransactionFilter.all(),
          onResult: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();

    expect(find.text('未打标签'), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
  });
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.initialFilter, required this.onResult});

  final HomeTransactionFilter initialFilter;
  final ValueChanged<HomeTransactionFilter?> onResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                onResult(
                  await showHomeTransactionFilterSheet(
                    context: context,
                    initialFilter: initialFilter,
                    expenseTree: [
                      CategoryNode(
                        account: _account(
                          'cat-food',
                          '餐饮',
                          AccountType.expense,
                        ),
                        children: [
                          _account('cat-lunch', '午餐', AccountType.expense),
                        ],
                      ),
                    ],
                    incomeTree: const [],
                    accounts: [
                      _account('acc-cash', '现金', AccountType.asset),
                      _account('acc-card', '银行卡', AccountType.asset),
                    ],
                  ),
                );
              },
              child: const Text('打开'),
            );
          },
        ),
      ),
    );
  }
}

Account _account(String id, String name, AccountType type) {
  return Account(id: id, name: name, type: type, balance: Money.zero());
}

class _DelayedTagRepository extends FakeTransactionTagRepository {
  @override
  Future<List<TagView>> listTags() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return super.listTags();
  }
}

class _NoopIdGenerator implements IdGenerator {
  @override
  String newId() => 'unused';
}

class _DirectTransactionRunner implements TransactionRunner {
  const _DirectTransactionRunner();

  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}
