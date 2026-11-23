import '../../../../domain/intake/recognition/port/recorded_payment_query.dart';
import '../../../../domain/intake/recognition/recognized_payment.dart';

class PaymentDuplicateQueryService {
  const PaymentDuplicateQueryService({
    required RecordedPaymentQuery recordedPayments,
  }) : _recordedPayments = recordedPayments;

  final RecordedPaymentQuery _recordedPayments;

  Future<bool> hasPossibleDuplicate(RecognizedPayment payment) async {
    final time = payment.occurredAt;
    if (!payment.isOrdinary ||
        !payment.canPrefill ||
        payment.amount == null ||
        payment.amount!.minorUnits <= 0 ||
        time == null) {
      return false;
    }
    final recorded = await _recordedPayments.findOrdinaryPayments(
      occurredFrom: time,
      occurredUntil: time.add(const Duration(seconds: 1)),
    );
    return recorded.any(
      (candidate) =>
          candidate.direction == payment.direction &&
          candidate.amount == payment.amount,
    );
  }
}
