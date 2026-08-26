import '../../../application/ledger/ledger_query_api.dart';
import '../../shared/presentation/account_lookup.dart';
import '../../shared/presentation/transaction_list_presentation.dart';

List<TransactionDayGroup> budgetTransactionGroups({
  required List<TransactionReadModel> transactions,
  required AccountLookup accountLookup,
  required String categoryId,
}) {
  final categoryIds = resolveCategoryAccountIds([
    CategorySelection.withDescendants(categoryId),
  ], accountLookup.byId);
  return groupTransactionsByDay(
    items: transactions,
    accountLookup: accountLookup,
    amountSource: TransactionCategoryImpactAmountSource(categoryIds),
  );
}
