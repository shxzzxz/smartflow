import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/intake/intake_recognition_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/intake/recognition/port/recorded_payment_query.dart';

void main() {
  final time = DateTime(2026, 4, 5, 13, 20, 11);
  final amount = Money.parse('12.35');

  for (final direction in RecognizedPaymentDirection.values) {
    test(
      'matches $direction and amount within the transaction second',
      () async {
        final payments = _RecordedPayments([
          RecordedPayment(direction: direction, amount: amount),
        ]);
        final service = PaymentDuplicateQueryService(
          recordedPayments: payments,
        );
        expect(
          await service.hasPossibleDuplicate(
            RecognizedPayment(
              direction: direction,
              amount: amount,
              occurredAt: time,
            ),
          ),
          isTrue,
        );
        expect(payments.requests.single.from, time);
        expect(
          payments.requests.single.until,
          DateTime(2026, 4, 5, 13, 20, 12),
        );
      },
    );
  }

  test('a different amount or direction is not a possible duplicate', () async {
    final payments = _RecordedPayments([
      RecordedPayment(
        direction: RecognizedPaymentDirection.income,
        amount: amount,
      ),
      RecordedPayment(
        direction: RecognizedPaymentDirection.expense,
        amount: Money.parse('12.36'),
      ),
    ]);
    final service = PaymentDuplicateQueryService(recordedPayments: payments);
    expect(
      await service.hasPossibleDuplicate(
        RecognizedPayment(
          direction: RecognizedPaymentDirection.expense,
          amount: amount,
          occurredAt: time,
        ),
      ),
      isFalse,
    );
  });

  test(
    'incomplete payments and manual scenes do not query existing transactions',
    () async {
      final payments = _RecordedPayments(const []);
      final service = PaymentDuplicateQueryService(recordedPayments: payments);
      for (final payment in [
        RecognizedPayment(
          direction: RecognizedPaymentDirection.expense,
          amount: amount,
        ),
        RecognizedPayment(
          direction: RecognizedPaymentDirection.expense,
          occurredAt: time,
        ),
        RecognizedPayment(amount: amount, occurredAt: time),
        RecognizedPayment(
          scene: PaymentScreenshotScene.transfer,
          direction: RecognizedPaymentDirection.expense,
          amount: amount,
          occurredAt: time,
        ),
      ]) {
        expect(await service.hasPossibleDuplicate(payment), isFalse);
      }
      expect(payments.requests, isEmpty);
    },
  );

  test('query failures propagate to the calling action boundary', () async {
    final failure = Exception('query unavailable');
    final service = PaymentDuplicateQueryService(
      recordedPayments: _RecordedPayments(const [], failure: failure),
    );
    await expectLater(
      service.hasPossibleDuplicate(
        RecognizedPayment(
          direction: RecognizedPaymentDirection.expense,
          amount: amount,
          occurredAt: time,
        ),
      ),
      throwsA(same(failure)),
    );
  });
}

class _RecordedPayments implements RecordedPaymentQuery {
  _RecordedPayments(this.payments, {this.failure});

  final List<RecordedPayment> payments;
  final Exception? failure;
  final requests = <({DateTime from, DateTime until})>[];

  @override
  Future<List<RecordedPayment>> findOrdinaryPayments({
    required DateTime occurredFrom,
    required DateTime occurredUntil,
  }) async {
    requests.add((from: occurredFrom, until: occurredUntil));
    if (failure != null) throw failure!;
    return payments;
  }
}
