import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/feature/shared/provider/tag_providers.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/home/view_model/home_view_model.dart';
import 'package:smartflow/feature/home/widget/home_transaction_filter_sheet.dart';

import '../../../helper/fake_transaction_tag_repository.dart';

void main() {
  testWidgets('all normalizes both filter dimensions to null', (tester) async {
    HomeTransactionFilter? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagListProvider.overrideWithValue(const AsyncData(<TagView>[])),
        ],
        child: _TestHost(
          initialFilter: HomeTransactionFilter(
            categoryAccountIds: const {},
            settlementAccountIds: const {},
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

    expect(result?.categoryAccountIds, isNull);
    expect(result?.settlementAccountIds, isNull);
  });

  testWidgets('clear keeps both filter dimensions empty', (tester) async {
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
    await tester.tap(find.text('清除'));
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    expect(result?.categoryAccountIds, isEmpty);
    expect(result?.settlementAccountIds, isEmpty);
  });

  testWidgets('waits for tags before opening the tag selector', (tester) async {
    final repository = _DelayedTagRepository();
    await repository.insertTag(id: 'tag-travel', name: '旅行');
    final service = TagApplicationService(
      repository: repository,
      idGenerator: _NoopIdGenerator(),
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
                    accounts: [_account('acc-cash', '现金', AccountType.asset)],
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
