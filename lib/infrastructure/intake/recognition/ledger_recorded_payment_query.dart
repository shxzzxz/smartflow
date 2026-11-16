import '../../../application/ledger/ledger_query_api.dart';
import '../../../domain/intake/recognition/port/recorded_payment_query.dart';
import '../../../domain/intake/recognition/recognized_payment.dart';

class LedgerRecordedPaymentQuery implements RecordedPaymentQuery {
  const LedgerRecordedPaymentQuery({
    required TransactionQueryService transactions,
  }) : _transactions = transactions;

  final TransactionQueryService _transactions;

  @override
  Future<List<RecordedPayment>> findOrdinaryPayments({
    required DateTime occurredFrom,
    required DateTime occurredUntil,
  }) async {
    final transactions = await _transactions.findTransactions(
      TransactionListQuery(
        occurredFrom: occurredFrom,
        occurredUntil: occurredUntil,
        limit: null,
        scope: TransactionScopeFilter.all,
      ),
    );
    final payments = <RecordedPayment>[];
    for (final transaction in transactions) {
      final direction = switch (transaction.businessPurpose) {
        BusinessPurpose.dailyExpense => RecognizedPaymentDirection.expense,
        BusinessPurpose.dailyIncome => RecognizedPaymentDirection.income,
        _ => null,
      };
      if (direction == null) continue;
      payments.add(
        RecordedPayment(
          direction: direction,
          amount: transaction.primaryAmount,
        ),
      );
    }
    return payments;
  }
}
