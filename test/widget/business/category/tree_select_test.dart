import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/widget/business/category/tree_select.dart';

void main() {
  testWidgets('selects a root category from its body and expands separately', (
    tester,
  ) async {
    final root = Account(
      id: 'food',
      name: '餐饮',
      type: AccountType.expense,
      balance: Money.zero(),
      iconKey: 'meal',
    );
    final child = Account(
      id: 'lunch',
      name: '午餐',
      type: AccountType.expense,
      balance: Money.zero(),
      parentId: root.id,
      iconKey: 'bowl-line',
    );
    Account? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => ElevatedButton(
                onPressed: () async {
                  selected = await showModalBottomSheet<Account>(
                    context: context,
                    builder:
                        (_) => TreeSelect(
                          nodes: [
                            CategoryNode(account: root, children: [child]),
                          ],
                        ),
                  );
                },
                child: const Text('open'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('展开子分类'));
    await tester.pumpAndSettle();

    expect(find.text('午餐'), findsOneWidget);
    expect(selected, isNull);

    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    expect(selected?.id, root.id);
  });
}
