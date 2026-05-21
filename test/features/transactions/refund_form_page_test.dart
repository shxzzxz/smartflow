import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/providers.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/data/app_database.dart';
import 'package:smartflow/data/database_provider.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/domain/accounting/accounting_api.dart';
import 'package:smartflow/features/transactions/pages/refund_form_page.dart';

import '../../helpers/test_app_database.dart';

void main() {
  testWidgets('prefills refund account from parent settlement account', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);
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
              TransactionDetailView(
                transaction: Transaction(
                  id: 1,
                  rootTransactionId: 1,
                  businessPurpose: BusinessPurpose.dailyExpense,
                  occurredAt: DateTime(2026, 5, 16),
                  currencyCode: 'CNY',
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
                  const EntryLineView(
                    accountId: 99,
                    accountName: '餐饮',
                    accountType: AccountType.expense,
                    direction: EntryDirection.debit,
                    amount: Money(minorUnits: 1200),
                  ),
                  EntryLineView(
                    accountId: walletId,
                    accountName: '钱包',
                    accountType: AccountType.asset,
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
          home: const RefundFormPage(parentTransactionId: 1),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('退款账户'), findsOneWidget);
    expect(find.text('钱包'), findsOneWidget);
  });
}

Future<int> _insertAccount(
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
          currencyCode: 'CNY',
        ),
      );
}

class _FakeTransactionQueryService implements TransactionQueryService {
  const _FakeTransactionQueryService(this.detail);

  final TransactionDetailView detail;

  @override
  Stream<TransactionDetailView?> watchTransactionDetail(int transactionId) {
    return Stream.value(detail);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
