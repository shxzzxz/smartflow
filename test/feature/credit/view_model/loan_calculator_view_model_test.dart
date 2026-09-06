import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/installment_stage_rule.dart';
import 'package:smartflow/feature/credit/view_model/installment_terms_draft.dart';
import 'package:smartflow/feature/credit/view_model/loan_calculator_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  late ProviderContainer scope;
  late LoanCalculatorViewModel vm;
  setUp(() {
    scope = ProviderContainer();
    scope.listen(loanCalculatorViewModelProvider, (_, _) {});
    vm = scope.read(loanCalculatorViewModelProvider.notifier);
    vm.setBorrowingDate(DateTime(2026, 1, 10));
    vm.setTerms(InstallmentTermsDraft.loan(DateTime(2026, 1, 10)));
  });
  tearDown(() => scope.dispose());
  LoanCalculatorState state() => scope.read(loanCalculatorViewModelProvider);
  void stage(InstallmentStageDraft Function(InstallmentStageDraft) update) {
    final terms = state().terms;
    vm.setTerms(terms.replace(update(terms.stages.single)));
  }

  test('starts with one repayment stage and calculator conventions', () {
    expect(state().terms.stages, hasLength(1));
    expect(state().canSimulatePrepayment, isTrue);
    expect(state().terms.dayCount, DayCountConvention.thirty360);
    expect(
      state().terms.stages.single.algorithm,
      InstallmentAmountAlgorithm.nominalRate,
    );
  });
  test('calculates textbook equal installments through shared terms', () async {
    stage((s) => s.setInput(StageInput.rate, '12'));
    expect(
      await vm.calculate(principalText: '12000'),
      isA<UiActionSuccess<void>>(),
    );
    final result = state().result!;
    expect(result.periods, hasLength(12));
    expect(result.totalPrincipal, const Money(minorUnits: 1200000));
    expect(
      result.stages.single.installmentAmount,
      const Money(minorUnits: 106619),
    );
  });
  test('rejects invalid principal and stage input', () async {
    expect(
      await vm.calculate(principalText: '0'),
      isA<UiActionFailure<void>>(),
    );
    stage((s) => s.setInput(StageInput.periods, 'x'));
    expect(
      await vm.calculate(principalText: '12000'),
      isA<UiActionFailure<void>>(),
    );
    expect(state().result, isNull);
  });
  test('maps invalid timeline to a business failure', () async {
    stage((s) => s.copyWith(firstDate: DateTime(2025, 12, 10)));
    expect(
      await vm.calculate(principalText: '12000'),
      isA<UiActionFailure<void>>(),
    );
  });
  test(
    'one-time fee ignores inapplicable rate, count and fixed amount',
    () async {
      stage(
        (s) => s
            .changeMethod(InstallmentRepaymentMethod.flatFee)
            .setInput(StageInput.rate, 'bad')
            .setInput(StageInput.periods, 'bad')
            .setInput(StageInput.fixedAmount, 'bad')
            .setInput(StageInput.fee, '88'),
      );
      expect(
        await vm.calculate(principalText: '1000'),
        isA<UiActionSuccess<void>>(),
      );
      expect(state().result!.periods, hasLength(1));
      expect(state().result!.totalInterest.minorUnits, 0);
      expect(state().result!.totalRepayment.minorUnits, 108800);
    },
  );
  test('ordinary repayment stages preserve and distribute their fee', () async {
    stage((s) => s.setInput(StageInput.fee, '12'));
    expect(
      await vm.calculate(principalText: '12000'),
      isA<UiActionSuccess<void>>(),
    );
    expect(state().result!.totalFee.minorUnits, 1200);
    expect(
      state().result!.periods.map((p) => p.fee.minorUnits),
      everyElement(100),
    );
  });
  test('negative fees fail for either repayment method', () async {
    for (final method in [
      InstallmentRepaymentMethod.equalPrincipal,
      InstallmentRepaymentMethod.flatFee,
    ]) {
      stage((s) => s.changeMethod(method).setInput(StageInput.fee, '-1'));
      expect(
        await vm.calculate(principalText: '12000'),
        isA<UiActionFailure<void>>(),
      );
    }
  });
  test(
    'presets all generate valid plans and replace stage identities',
    () async {
      final old = state().terms.stages.single.id;
      for (final preset in LoanCalculatorPreset.values) {
        vm.applyPreset(preset, principalText: '12000');
        expect(state().terms.stages.any((s) => s.id == old), isFalse);
        expect(
          await vm.calculate(principalText: '12000'),
          isA<UiActionSuccess<void>>(),
          reason: preset.name,
        );
        expect(state().result!.totalPrincipal.minorUnits, 1200000);
      }
    },
  );
  test('single stage prepayment simulation retains frozen periods', () async {
    stage((s) => s.setInput(StageInput.rate, '12'));
    vm.setSimulatePrepayment(true);
    vm.setPrepaymentDate(DateTime(2026, 5, 11));
    expect(
      await vm.calculate(
        principalText: '12000',
        paidPeriodsText: '3',
        prepaymentPrincipalText: '1000',
      ),
      isA<UiActionSuccess<void>>(),
    );
    expect(state().simulation!.interestSaved.minorUnits, greaterThan(0));
    expect(
      state().simulation!.periods.first.total,
      state().result!.periods.first.total,
    );
    vm.applyPreset(LoanCalculatorPreset.studentLoan, principalText: '12000');
    expect(state().canSimulatePrepayment, isFalse);
    expect(state().simulation, isNull);
  });
  test(
    'changing terms, loan input or prepayment invalidates old results',
    () async {
      await vm.calculate(principalText: '12000');
      expect(state().result, isNotNull);
      stage((s) => s.setInput(StageInput.rate, '5'));
      expect(state().result, isNull);
      await vm.calculate(principalText: '12000');
      vm.invalidateResult();
      expect(state().result, isNull);
    },
  );
}
