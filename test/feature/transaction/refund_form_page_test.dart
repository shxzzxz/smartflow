import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/data/app_database.dart';
import 'package:smartflow/data/database_provider.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/application/ledger/ledger_api.dart';
import 'package:smartflow/feature/transaction/page/refund_form_page.dart';

import '../../helper/test_app_database.dart';

void main() {
  testWidgets('prefills refund account from parent settlement account', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final categoryId = await _insertAccount(
      database,
      name: '餐饮',
      type: AccountType.expense,
    );
    final walletId = await _insertAccount(
      database,
      name: '钱包',
      type: AccountType.asset,
      subtype: AccountSubtype.cash,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          transactionQueryServiceProvider.overrideWithValue(
            _FakeTransactionQueryService(
              TransactionDetail(
                transaction: Transaction(
                  id: '1',
                  rootTransactionId: '1',
                  businessPurpose: BusinessPurpose.dailyExpense,
                  occurredAt: DateTime(2026, 5, 16),
                  primaryAmount: const Money(minorUnits: 1200),
                  mutationKind: MutationKind.original,
                  businessState: BusinessState.current,
                  isExcludedFromStats: false,
                  isExcludedFromBudget: false,
                  sourceKind: SourceKind.manual,
                  createdAt: DateTime(2026, 5, 16),
                ),
                details: const [],
                entries: [
                  Entry(
                    id: '1',
                    transactionId: '1',
                    accountId: categoryId,
                    direction: EntryDirection.debit,
                    amount: const Money(minorUnits: 1200),
                  ),
                  Entry(
                    id: '2',
                    transactionId: '1',
                    accountId: walletId,
                    direction: EntryDirection.credit,
                    amount: const Money(minorUnits: 1200),
                  ),
                ],
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RefundFormPage(parentTransactionId: '1'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('退款账户'), findsOneWidget);
    expect(find.text('钱包'), findsOneWidget);
  });
}

Future<String> _insertAccount(
  AppDatabase database, {
  required String name,
  required AccountType type,
  AccountSubtype? subtype,
}) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          name: name,
          accountType: type,
          accountSubtype: Value(subtype),
        ),
      );
}

class _FakeTransactionQueryService implements TransactionQueryService {
  const _FakeTransactionQueryService(this.detail);

  final TransactionDetail detail;

  @override
  Stream<TransactionDetail?> watchTransactionDetail(String transactionId) {
    return Stream.value(detail);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
