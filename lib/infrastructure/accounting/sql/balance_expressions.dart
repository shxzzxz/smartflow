import 'package:drift/drift.dart';

import '../../../domain/accounting/enums/accounting_enums.dart';
import '../../../application/accounting/queries/transaction_scope.dart';
import 'package:smartflow/data/app_database.dart';

/// 余额变化金额累计表达式（按账户类型决定借/贷方向的符号）。
///
/// 等价 Dart 公式见 [balanceDeltaMinor]
/// (`lib/domain/accounting/ledger/ledger_rules.dart`):
/// - 资产 / 费用账户:debit 为正,credit 为负
/// - 负债 / 收入账户:credit 为正,debit 为负
///
/// 用于 5 处 SQL 余额累计场景共享同一公式,避免散漏。
Expression<int> balanceDeltaExpr({
  required $EntriesTable entries,
  required $AccountsTable accounts,
}) {
  final increasesOnDebit = accounts.accountType.isInValues({
    AccountType.asset,
    AccountType.expense,
  });
  final isDebit = entries.direction.equalsValue(EntryDirection.debit);
  final amount = entries.amountMinor;
  final negAmount = -entries.amountMinor;

  // 正向方向(增加余额)的条件:
  //   (increasesOnDebit && isDebit) || (!increasesOnDebit && !isDebit)
  final isPositive =
      (increasesOnDebit & isDebit) | (increasesOnDebit.not() & isDebit.not());

  return CaseWhenExpression<int>(
    cases: [CaseWhen(isPositive, then: amount)],
    orElse: negAmount,
  );
}

/// 把 [TransactionScopeFilter] 翻译成 `transactions` 表上的 where 条件表达式。
///
/// repository 在任何需要 lens 过滤的 typed query 里调用本函数,把过滤条件注入,
/// 避免业务字面量(如 `business_state = 'current'`)散布在 SQL 字符串里。
Expression<bool> applyTransactionScope({
  required $TransactionsTable transactions,
  required TransactionScopeFilter scope,
}) {
  Expression<bool> condition = transactions.businessState.isInValues(
    scope.businessStates,
  );

  final excludedFromStats = scope.excludedFromStats;
  if (excludedFromStats != null) {
    condition =
        condition & transactions.isExcludedFromStats.equals(excludedFromStats);
  }

  final excludedFromBudget = scope.excludedFromBudget;
  if (excludedFromBudget != null) {
    condition =
        condition &
        transactions.isExcludedFromBudget.equals(excludedFromBudget);
  }

  return condition;
}
