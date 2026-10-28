import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_account_options.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  test('derives every transaction account option from one account list', () {
    final options = TransactionAccountOptions.fromAccounts([
      _account('fund', AccountProfileKind.fund),
      _account('reimbursement', AccountProfileKind.reimbursement),
      _account('receivable', AccountProfileKind.receivable),
      _account('payable', AccountProfileKind.payable),
      _account('credit', AccountProfileKind.credit),
      _account('loan', AccountProfileKind.loan),
    ]);

    expect(_ids(options.settlementAccounts), ['fund', 'payable', 'credit']);
    expect(_ids(options.fundAccounts), ['fund']);
    expect(_ids(options.liabilityAccounts), ['payable', 'credit', 'loan']);
    expect(_ids(options.advanceReceivableAccounts), [
      'reimbursement',
      'receivable',
    ]);
    expect(_ids(options.ordinaryReceivableAccounts), [
      'reimbursement',
      'receivable',
    ]);
    expect(_ids(options.expenseSettlementAccounts), [
      'fund',
      'receivable',
      'payable',
      'credit',
    ]);
  });

  test('derives options reactively from the shared account list', () async {
    final accounts = StreamController<List<Account>>();
    addTearDown(accounts.close);
    final container = ProviderContainer(
      overrides: [accountListProvider.overrideWith((ref) => accounts.stream)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      transactionAccountOptionsProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);

    expect(
      container.read(transactionAccountOptionsProvider),
      isA<AsyncLoading<TransactionAccountOptions>>(),
    );

    accounts.add([_account('fund', AccountProfileKind.fund)]);
    await pumpEventQueue();
    expect(
      _ids(
        container
            .read(transactionAccountOptionsProvider)
            .requireValue
            .fundAccounts,
      ),
      ['fund'],
    );

    accounts.add([
      _account('fund', AccountProfileKind.fund),
      _account('receivable', AccountProfileKind.receivable),
    ]);
    await pumpEventQueue();
    expect(
      _ids(
        container
            .read(transactionAccountOptionsProvider)
            .requireValue
            .expenseSettlementAccounts,
      ),
      ['fund', 'receivable'],
    );
  });
}

Account _account(String id, AccountProfileKind profile) {
  return Account(
    id: id,
    name: id,
    type: profile.accountType,
    subtype: profile.accountSubtype,
    profileKey: profile.key,
    balance: Money.zero(),
  );
}

List<String> _ids(Iterable<Account> accounts) {
  return [for (final account in accounts) account.id];
}
