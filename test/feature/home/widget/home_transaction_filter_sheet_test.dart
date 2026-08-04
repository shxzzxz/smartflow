import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/home/view_model/home_view_model.dart';
import 'package:smartflow/feature/home/widget/home_transaction_filter_sheet.dart';

void main() {
  testWidgets('all normalizes both filter dimensions to null', (tester) async {
    HomeTransactionFilter? result;
    await tester.pumpWidget(
      _TestHost(
        initialFilter: HomeTransactionFilter(
          categoryAccountIds: const {},
          settlementAccountIds: const {},
        ),
        onResult: (value) => result = value,
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
      _TestHost(
        initialFilter: const HomeTransactionFilter.all(),
        onResult: (value) => result = value,
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
