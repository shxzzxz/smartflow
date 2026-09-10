import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/domain/credit/entity/installment_repricing.dart';
import 'package:smartflow/domain/credit/valobj/floating_rate.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/reference_rate.dart';

void main() {
  InstallmentRepricing record(InstallmentRepricingStatus status) =>
      InstallmentRepricing(
        id: 'reset',
        contractId: 'loan',
        stageId: 'stage',
        status: status,
        change: RateChange(
          resetDate: DateTime.utc(2026, 1, 1),
          effectiveDate: DateTime.utc(2026, 1, 1),
          referenceRate: ReferenceRate(
            type: ReferenceRateType.lprOneYear,
            date: DateTime.utc(2025, 12, 20),
            ratePpm: 30000,
            source: 'test',
          ),
          spreadBp: 0,
        ),
      );

  test('pending repricing rejects confirmation without changing state', () {
    final pending = record(InstallmentRepricingStatus.pending);
    expect(pending.confirm, throwsA(isA<BusinessException>()));
    expect(pending.status, InstallmentRepricingStatus.pending);
    pending.markApplied();
    expect(pending.status, InstallmentRepricingStatus.applied);
    pending.confirm();
    expect(pending.status, InstallmentRepricingStatus.userConfirmed);
  });

  for (final status in InstallmentRepricingStatus.values) {
    test('applying $status is idempotent and never reverses confirmation', () {
      final value = record(status);
      value.markApplied();
      value.markApplied();
      expect(
        value.status,
        status == InstallmentRepricingStatus.pending
            ? InstallmentRepricingStatus.applied
            : status,
      );
      value.confirm();
      value.confirm();
      value.markApplied();
      expect(value.status, InstallmentRepricingStatus.userConfirmed);
    });
  }
}
