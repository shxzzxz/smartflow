import 'package:test/test.dart';
import 'package:smartflow/domain/orchestration/entity/advance_case.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';

void main() {
  test('account AA requires and preserves participant count', () {
    const advanceCase = AdvanceCase(
      id: 'case',
      scenario: AdvanceScenario.aa,
      trackingMode: AdvanceTrackingMode.account,
      receivableAccountId: 'receivable',
      aaPeopleCount: 3,
    );

    expect(advanceCase.validate, returnsNormally);
    expect(
      () => const AdvanceCase(
        id: 'case',
        scenario: AdvanceScenario.aa,
        trackingMode: AdvanceTrackingMode.account,
        receivableAccountId: 'receivable',
      ).validate(),
      throwsArgumentError,
    );
  });

  test('on-behalf supports account tracking without participant count', () {
    const advanceCase = AdvanceCase(
      id: 'case',
      scenario: AdvanceScenario.onBehalf,
      trackingMode: AdvanceTrackingMode.account,
      receivableAccountId: 'receivable',
    );

    expect(advanceCase.validate, returnsNormally);
  });
}
