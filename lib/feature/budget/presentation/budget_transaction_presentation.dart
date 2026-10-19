import '../../../application/ledger/ledger_query_api.dart';
import '../../shared/presentation/account_lookup.dart';
import '../../shared/presentation/transaction_list_presentation.dart';

/// 预算范围命中的物理支出分类账户 ID。
///
/// 总预算覆盖全部活跃支出分类；分类预算覆盖该分类自身及其二级分类。
Set<String> budgetScopeAccountIds(
  AccountLookup accountLookup, {
  String? categoryId,
}) {
  if (categoryId != null) {
    return resolveCategoryAccountIds([
      CategorySelection.withDescendants(categoryId),
    ], accountLookup.byId);
  }
  return {
    for (final account in accountLookup.byId.values)
      if (account.type == AccountType.expense && !account.isArchived)
        account.id,
  };
}

List<TransactionDayGroup> budgetTransactionGroups({
  required List<TransactionReadModel> transactions,
  required AccountLookup accountLookup,
  String? categoryId,
}) {
  final categoryIds = budgetScopeAccountIds(
    accountLookup,
    categoryId: categoryId,
  );
  return groupTransactionsByDay(
    items: transactions,
    accountLookup: accountLookup,
    amountSource: TransactionCashflowImpactAmountSource(categoryIds),
  );
}
