import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/ledger/entity/account.dart';
import '../../../shared/account_profile/account_selection_policy.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import '../../shared/provider/ledger_query_providers.dart';

part 'transaction_account_options.g.dart';

class TransactionAccountOptions {
  TransactionAccountOptions({
    Iterable<Account> settlementAccounts = const <Account>[],
    Iterable<Account> fundAccounts = const <Account>[],
    Iterable<Account> liabilityAccounts = const <Account>[],
    Iterable<Account> advanceReceivableAccounts = const <Account>[],
    Iterable<Account> ordinaryReceivableAccounts = const <Account>[],
    Iterable<Account> expenseSettlementAccounts = const <Account>[],
    Iterable<Account> prepaidExpenseAccounts = const <Account>[],
    Iterable<Account> deferredIncomeAccounts = const <Account>[],
  }) : settlementAccounts = List.unmodifiable(settlementAccounts),
       fundAccounts = List.unmodifiable(fundAccounts),
       liabilityAccounts = List.unmodifiable(liabilityAccounts),
       advanceReceivableAccounts = List.unmodifiable(advanceReceivableAccounts),
       ordinaryReceivableAccounts = List.unmodifiable(
         ordinaryReceivableAccounts,
       ),
       expenseSettlementAccounts = List.unmodifiable(expenseSettlementAccounts),
       prepaidExpenseAccounts = List.unmodifiable(prepaidExpenseAccounts),
       deferredIncomeAccounts = List.unmodifiable(deferredIncomeAccounts);

  factory TransactionAccountOptions.fromAccounts(Iterable<Account> accounts) {
    final source = List<Account>.unmodifiable(accounts);
    final receivableAccounts = accountsMatchingSelectionPurpose(
      source,
      AccountSelectionPurpose.ordinaryReceivable,
    );
    return TransactionAccountOptions(
      settlementAccounts: accountsMatchingSelectionPurpose(
        source,
        AccountSelectionPurpose.settlement,
      ),
      fundAccounts: accountsMatchingSelectionPurpose(
        source,
        AccountSelectionPurpose.fund,
      ),
      liabilityAccounts: accountsMatchingSelectionPurpose(
        source,
        AccountSelectionPurpose.borrowingLiability,
      ),
      advanceReceivableAccounts: receivableAccounts,
      ordinaryReceivableAccounts: receivableAccounts,
      expenseSettlementAccounts: accountsMatchingSelectionPurpose(
        source,
        AccountSelectionPurpose.expenseSettlement,
      ),
      prepaidExpenseAccounts: accountsMatchingSelectionPurpose(
        source,
        AccountSelectionPurpose.prepaidExpense,
      ),
      deferredIncomeAccounts: accountsMatchingSelectionPurpose(
        source,
        AccountSelectionPurpose.deferredIncome,
      ),
    );
  }

  factory TransactionAccountOptions.empty() {
    return TransactionAccountOptions();
  }

  final List<Account> settlementAccounts;
  final List<Account> fundAccounts;
  final List<Account> liabilityAccounts;
  final List<Account> advanceReceivableAccounts;
  final List<Account> ordinaryReceivableAccounts;
  final List<Account> expenseSettlementAccounts;
  final List<Account> prepaidExpenseAccounts;
  final List<Account> deferredIncomeAccounts;
}

@riverpod
AsyncValue<TransactionAccountOptions> transactionAccountOptions(Ref ref) {
  final accounts = ref.watch(accountListProvider);
  if (accounts case AsyncError(:final error, :final stackTrace)) {
    return AsyncValue.error(error, stackTrace);
  }
  final values = accounts.value;
  if (values == null) return const AsyncValue.loading();
  return AsyncValue.data(TransactionAccountOptions.fromAccounts(values));
}
