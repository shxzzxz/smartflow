import '../../../../core/money/money.dart';
import '../recognized_payment.dart';

class RecordedPayment {
  const RecordedPayment({required this.direction, required this.amount});

  final RecognizedPaymentDirection direction;
  final Money amount;
}

/// Intake-owned read port for existing ordinary income and expense transactions.
abstract interface class RecordedPaymentQuery {
  /// The lower time bound is inclusive and the upper bound is exclusive.
  Future<List<RecordedPayment>> findOrdinaryPayments({
    required DateTime occurredFrom,
    required DateTime occurredUntil,
  });
}
