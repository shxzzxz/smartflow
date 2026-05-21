import '../../../core/money/money.dart';
import '../entities/transaction.dart';
import '../enums/accounting_enums.dart';
import '../queries/transaction_queries.dart';
import '../repositories/transaction_query_repository.dart';
import '../views/transaction_views.dart';

abstract interface class TransactionQueryService {
  Stream<List<TransactionListItem>> watchTransactions(
    TransactionListQuery query,
  );

  Stream<CashflowSummary> watchCashflowSummary(CashflowSummaryQuery query);

  Stream<TransactionDetailView?> watchTransactionDetail(int transactionId);

  Future<Transaction?> findTransactionById(int transactionId);

  Future<Money> getRefundedTotal(int rootTransactionId, {String currencyCode});

  Future<ReimbursementSummary?> getReimbursementSummary(int rootTransactionId);

  Future<int> getDetailAmountSum({
    required Iterable<int> transactionIds,
    required TransactionDetailType detailType,
  });
}

class TransactionQueryServiceImpl implements TransactionQueryService {
  const TransactionQueryServiceImpl(this._repository);

  final TransactionQueryRepository _repository;

  @override
  Stream<List<TransactionListItem>> watchTransactions(
    TransactionListQuery query,
  ) {
    return _repository.watchTransactions(query);
  }

  @override
  Stream<CashflowSummary> watchCashflowSummary(CashflowSummaryQuery query) {
    return _repository.watchCashflowSummary(query);
  }

  @override
  Stream<TransactionDetailView?> watchTransactionDetail(int transactionId) {
    return _repository.watchTransactionDetail(transactionId);
  }

  @override
  Future<Transaction?> findTransactionById(int transactionId) {
    return _repository.findTransactionById(transactionId);
  }

  @override
  Future<Money> getRefundedTotal(
    int rootTransactionId, {
    String currencyCode = Money.defaultCurrency,
  }) {
    return _repository.getRefundedTotal(
      rootTransactionId,
      currencyCode: currencyCode,
    );
  }

  @override
  Future<ReimbursementSummary?> getReimbursementSummary(int rootTransactionId) {
    return _repository.getReimbursementSummary(rootTransactionId);
  }

  @override
  Future<int> getDetailAmountSum({
    required Iterable<int> transactionIds,
    required TransactionDetailType detailType,
  }) {
    return _repository.getDetailAmountSum(
      transactionIds: transactionIds,
      detailType: detailType,
    );
  }
}
