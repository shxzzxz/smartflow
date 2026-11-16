import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/intake/recognition/recognized_payment.dart';
import 'package:smartflow/infrastructure/intake/recognition/ledger_recorded_payment_query.dart';

void main() {
  test(
    'loads all ordinary payment facts for the requested time range',
    () async {
      final from = DateTime(2026, 4, 5, 13, 20, 11);
      final until = DateTime(2026, 4, 5, 13, 20, 12);
      final transactions = _Transactions([
        _transaction(
          BusinessPurpose.dailyExpense,
          from,
          '12.35',
          excluded: true,
        ),
        _transaction(BusinessPurpose.dailyIncome, from, '20.00'),
        _transaction(BusinessPurpose.transfer, from, '12.35'),
        _transaction(BusinessPurpose.refund, from, '12.35'),
        _transaction(BusinessPurpose.debtRepayment, from, '12.35'),
      ]);
      final query = LedgerRecordedPaymentQuery(transactions: transactions);
      final payments = await query.findOrdinaryPayments(
        occurredFrom: from,
        occurredUntil: until,
      );
      expect(payments.map((payment) => (payment.direction, payment.amount)), [
        (RecognizedPaymentDirection.expense, Money.parse('12.35')),
        (RecognizedPaymentDirection.income, Money.parse('20.00')),
      ]);
      final request = transactions.requests.single;
      expect(request.occurredFrom, from);
      expect(request.occurredUntil, until);
      expect(request.scope, TransactionScopeFilter.all);
      expect(request.topLevelOnly, isTrue);
      expect(request.limit, isNull);
    },
  );
}

TransactionReadModel _transaction(
  BusinessPurpose purpose,
  DateTime time,
  String amount, {
  bool excluded = false,
}) => TransactionReadModel(
  id: purpose.name,
  businessPurpose: purpose,
  occurredAt: time,
  primaryAmount: Money.parse(amount),
  isExcludedFromStats: excluded,
  isExcludedFromBudget: excluded,
);

class _Transactions implements TransactionQueryService {
  _Transactions(this.transactions);

  final List<TransactionReadModel> transactions;
  final requests = <TransactionListQuery>[];

  @override
  Future<List<TransactionReadModel>> findTransactions(
    TransactionListQuery query,
  ) async {
    requests.add(query);
    return transactions;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
