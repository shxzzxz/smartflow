import '../../../core/money/money.dart';
import '../entities/transaction.dart';
import '../enums/accounting_enums.dart';
import '../queries/transaction_queries.dart';
import '../views/transaction_views.dart';

abstract interface class TransactionQueryRepository {
  Stream<List<TransactionListItem>> watchTransactions(
    TransactionListQuery query,
  );

  Stream<CashflowSummary> watchCashflowSummary(CashflowSummaryQuery query);

  Stream<TransactionDetailView?> watchTransactionDetail(int transactionId);

  Future<Transaction?> findTransactionById(int transactionId);

  Future<Money> getRefundedTotal(
    int rootTransactionId, {
    String currencyCode = Money.defaultCurrency,
  });

  Future<ReimbursementSummary?> getReimbursementSummary(int rootTransactionId);

  Future<int> getDetailAmountSum({
    required Iterable<int> transactionIds,
    required TransactionDetailType detailType,
  });
}
