import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/transaction/page/transaction_detail_page.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  testWidgets('renders detail state and forwards note edits', (tester) async {
    final update = _FakeTransactionUpdateAppService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionDetailProvider(
            'tx-1',
          ).overrideWith((ref) => Stream.value(_detail())),
          accountLookupProvider.overrideWith(
            (ref) => Stream.value(AccountLookup(_accounts)),
          ),
          accountsForSelectionPurposeProvider(
            AccountSelectionPurpose.settlement,
          ).overrideWith((ref) => Stream.value([_accounts['cash']!])),
          accountsForSelectionPurposeProvider(
            AccountSelectionPurpose.reimbursementReceivable,
          ).overrideWith((ref) => Stream.value(const <Account>[])),
          transactionUpdateAppServiceProvider.overrideWithValue(update),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const TransactionDetailPage(transactionId: 'tx-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('交易详情'), findsOneWidget);
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('退款'), findsOneWidget);
    expect(find.text('交易时间'), findsOneWidget);
    expect(find.text('入账时间'), findsOneWidget);

    await tester.tap(find.text('点击添加备注'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新的备注');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(update.basicInfoCommands, hasLength(1));
    expect(update.basicInfoCommands.single.transactionId, 'tx-1');
    expect(find.text('备注已更新'), findsOneWidget);
  });
}

final _accounts = <String, Account>{
  'cash': _account('cash', '现金', iconKey: 'cash'),
  'food': _account('food', '午餐', type: AccountType.expense, iconKey: 'meal'),
};

TransactionDetail _detail() {
  return TransactionDetail(
    transaction: Transaction(
      id: 'tx-1',
      rootTransactionId: 'tx-1',
      businessPurpose: BusinessPurpose.dailyExpense,
      occurredAt: DateTime(2026, 1, 1, 8),
      primaryAmount: const Money(minorUnits: 10000),
      mutationKind: MutationKind.original,
      businessState: BusinessState.current,
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
    ),
    createdAt: DateTime(2026, 1, 1, 8, 1),
    details: const [],
    entries: const [
      Entry(
        id: 'entry-cash',
        transactionId: 'tx-1',
        accountId: 'cash',
        direction: EntryDirection.credit,
        amount: Money(minorUnits: 10000),
      ),
      Entry(
        id: 'entry-food',
        transactionId: 'tx-1',
        accountId: 'food',
        direction: EntryDirection.debit,
        amount: Money(minorUnits: 10000),
      ),
    ],
  );
}

Account _account(
  String id,
  String name, {
  AccountType type = AccountType.asset,
  String? iconKey,
}) {
  return Account(
    id: id,
    name: name,
    type: type,
    iconKey: iconKey,
    balance: const Money(minorUnits: 0),
  );
}

class _FakeTransactionUpdateAppService implements TransactionUpdateAppService {
  final basicInfoCommands = <UpdateTransactionBasicInfoCommand>[];

  @override
  Future<PostedTransactionResult> updateBasicInfo(
    UpdateTransactionBasicInfoCommand command,
  ) async {
    basicInfoCommands.add(command);
    return const PostedTransactionResult(
      transactionId: 'tx-1',
      rootTransactionId: 'tx-1',
    );
  }

  @override
  Future<PostedTransactionResult> updateReportingFlag(
    UpdateTransactionReportingFlagCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> updateOwnership(
    UpdateTransactionOwnershipCommand command,
  ) {
    throw UnimplementedError();
  }
}
