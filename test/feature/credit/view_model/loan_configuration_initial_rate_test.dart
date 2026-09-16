import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/reference_rate/reference_rate_app_service.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/feature/credit/view_model/installment_terms_draft.dart';
import 'package:smartflow/feature/credit/view_model/loan_configuration_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  for (final contract in [true, false]) {
    test(
      '${contract ? "contract" : "calculator"} preserves entered initial rates without quotes',
      () async {
        final rates = _Rates();
        final container = ProviderContainer(
          overrides: [referenceRateAppServiceProvider.overrideWithValue(rates)],
        );
        addTearDown(container.dispose);
        final terms = InstallmentTermsDraft(
          stages: [
            _stage('first', DateTime(2025, 2, 10), '4.35'),
            _stage('second', DateTime(2025, 3, 10), '3.8'),
          ],
        );
        final provider = loanConfigurationViewModelProvider(
          installment: contract
              ? InstallmentConfigurationDraft(
                  borrowingDate: DateTime(2025, 1, 10),
                  terms: terms,
                )
              : null,
        );
        container.listen(provider, (_, _) {});
        final vm = container.read(provider.notifier);
        vm.setBorrowingDate(DateTime(2024, 12, 10));
        vm.setTerms(terms);
        await Future<void>.delayed(Duration.zero);
        expect(rates.requests, isEmpty);
        expect(
          container
              .read(provider)
              .terms
              .stages
              .map((s) => s.text(StageInput.rate)),
          ['4.35', '3.8'],
        );

        final InstallmentTermsDraft saved;
        if (contract) {
          final outcome = await vm.submitInstallment('1000');
          expect(
            outcome,
            isA<UiActionSuccess<InstallmentConfigurationDraft>>(),
          );
          saved = (outcome as UiActionSuccess<InstallmentConfigurationDraft>)
              .value
              .terms;
        } else {
          final outcome = await vm.submit('1000');
          expect(outcome, isA<UiActionSuccess<LoanConfiguration>>());
          saved = (outcome as UiActionSuccess<LoanConfiguration>).value.terms;
        }
        expect(saved.contractTerms().repayments.map((s) => s.rate!.ppm), [
          43500,
          38000,
        ]);
        expect(
          saved.contractTerms().repayments.every((s) => s.floatingRate == null),
          isTrue,
        );
        expect(rates.requests, isEmpty);
      },
    );
  }

  test(
    'manual initial rate accepts zero and rejects invalid or negative text',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final provider = loanConfigurationViewModelProvider();
      container.listen(provider, (_, _) {});
      final vm = container.read(provider.notifier);
      vm.setBorrowingDate(DateTime(2025, 1, 10));
      for (final text in ['-1', 'invalid', '', '0']) {
        vm.setTerms(
          InstallmentTermsDraft(
            stages: [_stage('stage', DateTime(2025, 2, 10), text)],
          ),
        );
        final outcome = await vm.submit('1000');
        if (text == '' || text == '0') {
          expect(outcome, isA<UiActionSuccess<LoanConfiguration>>());
          expect(
            (outcome as UiActionSuccess<LoanConfiguration>)
                .value
                .calculation
                .totalInterest
                .minorUnits,
            0,
          );
        } else {
          expect(outcome, isA<UiActionFailure<LoanConfiguration>>());
        }
      }
    },
  );
}

InstallmentStageDraft _stage(String id, DateTime firstDate, String rate) =>
    InstallmentStageDraft(
      id: id,
      firstDate: firstDate,
      method: InstallmentRepaymentMethod.interestFirst,
      // 产品中的动态利率规则不再决定本笔合同的初始利率填写方式。
      rateType: InterestRateType.lprOneYear,
      inputs: {
        StageInput.interval: '1',
        StageInput.periods: '1',
        StageInput.rate: rate,
      },
    );

class _Rates implements ReferenceRateAppService {
  final requests = <(InterestRateType, DateTime)>[];

  @override
  Future<ReferenceRateResolution> resolveOne(
    InterestRateType type,
    DateTime date,
  ) async {
    requests.add((type, date));
    return ReferenceRateResolution(
      date: date,
      reason: ReferenceRateMissingReason.noHistory,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
