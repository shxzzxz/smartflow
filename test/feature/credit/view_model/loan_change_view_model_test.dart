import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/domain/credit/valobj/reference_rate.dart';
import 'package:smartflow/feature/credit/view_model/installment_terms_draft.dart';
import 'package:smartflow/feature/credit/view_model/loan_change_view_model.dart';
import 'package:smartflow/feature/credit/view_model/loan_configuration_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  late ProviderContainer scope;
  late LoanConfigurationViewModel editor;
  setUp(() {
    scope = ProviderContainer();
    scope.listen(loanConfigurationViewModelProvider(), (_, _) {});
    editor = scope.read(loanConfigurationViewModelProvider().notifier);
    editor.setBorrowingDate(DateTime(2026, 1, 10));
    editor.setTerms(InstallmentTermsDraft.loan(DateTime(2026, 1, 10)));
  });
  tearDown(() => scope.dispose());

  Future<LoanConfiguration> configuration() async =>
      (await editor.submit('12000') as UiActionSuccess<LoanConfiguration>)
          .value;

  test(
    'failed operation edits preserve the existing draft and result',
    () async {
      final initial = await configuration();
      final provider = loanChangeViewModelProvider(initial: initial);
      scope.listen(provider, (_, _) {});
      final vm = scope.read(provider.notifier);
      expect(scope.read(provider).configuration, same(initial));
      expect(
        await vm.savePrepayment(
          date: DateTime(2026, 2, 11),
          principalText: '1000',
        ),
        isA<UiActionSuccess<void>>(),
      );
      final original = scope.read(provider).operations.single;
      final result =
          (await vm.simulate() as UiActionSuccess<LoanChangeSimulation>).value;
      expect(
        await vm.savePrepayment(
          id: original.id,
          date: original.date,
          principalText: '20000',
        ),
        isA<UiActionFailure<void>>(),
      );
      expect(scope.read(provider).operations.single, same(original));
      expect(result.prepaymentPrincipal.minorUnits, 100000);
      vm.removeOperation(original.id);
      expect(scope.read(provider).operations, isEmpty);
      expect(
        (await vm.simulate() as UiActionSuccess<LoanChangeSimulation>)
            .value
            .prepaymentPrincipal
            .minorUnits,
        0,
      );
      expect(result.prepaymentPrincipal.minorUnits, 100000);
    },
  );

  test(
    'repricing follows its stable stage when configuration changes and reports deleted stages',
    () async {
      final first = InstallmentStageDraft(
        id: 'first',
        method: InstallmentRepaymentMethod.interestFirst,
        firstDate: DateTime(2026, 2, 10),
        inputs: const {
          StageInput.periods: '2',
          StageInput.interval: '1',
          StageInput.rate: '6',
        },
      );
      final second = InstallmentStageDraft(
        id: 'second',
        method: InstallmentRepaymentMethod.equalPrincipal,
        firstDate: DateTime(2026, 4, 10),
        inputs: const {
          StageInput.periods: '2',
          StageInput.interval: '1',
          StageInput.rate: '6',
        },
      );
      editor.setTerms(InstallmentTermsDraft(stages: [first, second]));
      final initial = await configuration();
      final provider = loanChangeViewModelProvider(initial: initial);
      scope.listen(provider, (_, _) {});
      final vm = scope.read(provider.notifier);
      expect(
        await vm.saveRepricing(
          stageId: 'second',
          resetDate: DateTime(2026, 4, 11),
          effectiveDate: DateTime(2026, 4, 11),
          referenceRateType: InterestRateType.lprFiveYearPlus,
          referenceRateText: '3',
          spreadBpText: '-30',
        ),
        isA<UiActionSuccess<void>>(),
      );
      editor.setTerms(
        InstallmentTermsDraft(
          stages: [
            InstallmentStageDraft(
              id: 'defer',
              deferment: true,
              untilDate: DateTime(2026, 1, 20),
            ),
            first,
            second,
          ],
        ),
      );
      vm.setConfiguration(await configuration());
      final result =
          (await vm.simulate() as UiActionSuccess<LoanChangeSimulation>).value;
      expect(result.operations.rateChangesByStage.keys, [2]);
      expect(result.operations.rateChangesByStage[2]!.single.rate.ppm, 27000);
      editor.setTerms(InstallmentTermsDraft(stages: [first]));
      vm.setConfiguration(await configuration());
      final rejected = await vm.simulate();
      expect(rejected, isA<UiActionFailure<LoanChangeSimulation>>());
      expect(
        (rejected as UiActionFailure<LoanChangeSimulation>).error.message,
        contains('所属阶段已移除'),
      );
      expect(scope.read(provider).operations, hasLength(1));
      vm.removeOperation(scope.read(provider).operations.single.id);
      expect(await vm.simulate(), isA<UiActionSuccess<LoanChangeSimulation>>());
    },
  );
}
