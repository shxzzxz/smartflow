import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/feature/credit/presentation/loan_calculator_presentation.dart';
import 'package:smartflow/feature/credit/view_model/loan_calculator_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  ProviderContainer container() {
    final result = ProviderContainer();
    addTearDown(result.dispose);
    // autoDispose provider 需要订阅者才能在 await 之间保持状态。
    final subscription = result.listen(
      loanCalculatorViewModelProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    return result;
  }

  LoanCalculatorFormTexts texts(
    LoanCalculatorState state, {
    String principal = '12000',
    String rate = '12',
    String periods = '12',
    String? intervalMonths,
    String fee = '',
    String paidPeriods = '',
    String prepaymentPrincipal = '',
  }) {
    return LoanCalculatorFormTexts(
      principal: principal,
      stages: {
        for (final stage in state.stages)
          if (stage.kind == LoanCalculatorStageKind.amortizing)
            stage.id: LoanCalculatorStageTexts(
              periods: periods,
              intervalMonths: intervalMonths ?? stage.intervalMonthsText,
              rate: rate,
              endPrincipal: '',
              fee: fee,
              fixedAmount: '',
            ),
      },
      paidPeriods: paidPeriods,
      prepaymentPrincipal: prepaymentPrincipal,
    );
  }

  test('starts with one amortizing stage and allows prepayment simulation', () {
    final state = container().read(loanCalculatorViewModelProvider);

    expect(state.stages, hasLength(1));
    expect(state.stages.single.kind, LoanCalculatorStageKind.amortizing);
    expect(state.canSimulatePrepayment, isTrue);
    expect(state.result, isNull);
    expect(state.dayCount, DayCountConvention.thirty360);
  });

  test('calculates the textbook equal installment plan', () async {
    final scope = container();
    final notifier = scope.read(loanCalculatorViewModelProvider.notifier);
    notifier
      ..setBorrowingDate(DateTime(2026, 1, 10))
      ..setStageFirstRepaymentDate(
        scope.read(loanCalculatorViewModelProvider).stages.single.id,
        DateTime(2026, 2, 10),
      );

    final outcome = await notifier.calculate(
      texts(scope.read(loanCalculatorViewModelProvider)),
    );

    expect(outcome, isA<UiActionSuccess<void>>());
    final result = scope.read(loanCalculatorViewModelProvider).result!;
    expect(result.periods, hasLength(12));
    expect(result.totalPrincipal, const Money(minorUnits: 1200000));
    expect(
      result.stages.single.installmentAmount,
      const Money(minorUnits: 106619),
    );
  });

  test(
    'rejects invalid principal and stage inputs before calculating',
    () async {
      final scope = container();
      final notifier = scope.read(loanCalculatorViewModelProvider.notifier);
      final state = scope.read(loanCalculatorViewModelProvider);

      final noPrincipal = await notifier.calculate(
        texts(state, principal: '0'),
      );
      expect((noPrincipal as UiActionFailure<void>).error.message, '请输入有效本金');

      final badPeriods = await notifier.calculate(texts(state, periods: 'x'));
      expect(
        (badPeriods as UiActionFailure<void>).error.message,
        '阶段 1：请输入有效期数',
      );
      expect(scope.read(loanCalculatorViewModelProvider).result, isNull);
    },
  );

  test('maps engine failures to ui errors', () async {
    final scope = container();
    final notifier = scope.read(loanCalculatorViewModelProvider.notifier);
    final stageId = scope
        .read(loanCalculatorViewModelProvider)
        .stages
        .single
        .id;
    notifier
      ..setBorrowingDate(DateTime(2026, 6, 1))
      ..setStageFirstRepaymentDate(stageId, DateTime(2026, 1, 1));

    final outcome = await notifier.calculate(
      texts(scope.read(loanCalculatorViewModelProvider)),
    );

    expect(outcome, isA<UiActionFailure<void>>());
    expect(
      (outcome as UiActionFailure<void>).error.code,
      CreditErrorCode.contractInvalidCommand.code,
    );
  });

  test('flat fee charges once and ignores hidden recurring fields', () async {
    final scope = container();
    final notifier = scope.read(loanCalculatorViewModelProvider.notifier);
    final stageId = scope
        .read(loanCalculatorViewModelProvider)
        .stages
        .single
        .id;
    notifier
      ..setBorrowingDate(DateTime(2026, 5, 10))
      ..setStageFirstRepaymentDate(stageId, DateTime(2026, 6, 10))
      ..setStageLastRepaymentDate(stageId, DateTime(2026, 6, 1))
      ..setStageMethod(stageId, InstallmentRepaymentMethod.flatFee);

    final outcome = await notifier.calculate(
      texts(
        scope.read(loanCalculatorViewModelProvider),
        principal: '1000',
        fee: '100',
        periods: 'invalid',
        intervalMonths: 'invalid',
        rate: 'invalid',
      ),
    );

    expect(outcome, isA<UiActionSuccess<void>>());
    final result = scope.read(loanCalculatorViewModelProvider).result!;
    final period = result.periods.single;
    expect(period.date, DateTime(2026, 6, 10));
    expect(period.principal, const Money(minorUnits: 100000));
    expect(period.fee, const Money(minorUnits: 10000));
    expect(period.interest, Money.zero());
    expect(period.total, const Money(minorUnits: 110000));
    expect(period.remainingPrincipal, Money.zero());

    notifier.addAmortizingStage();
    expect(
      scope
          .read(loanCalculatorViewModelProvider)
          .stages
          .last
          .firstRepaymentDate,
      DateTime(2026, 7, 10),
    );
  });

  test('flat fee leaves the agreed principal for the next stage', () async {
    final scope = container();
    final notifier = scope.read(loanCalculatorViewModelProvider.notifier);
    final firstId = scope
        .read(loanCalculatorViewModelProvider)
        .stages
        .single
        .id;
    notifier
      ..setBorrowingDate(DateTime(2026, 5, 10))
      ..setStageFirstRepaymentDate(firstId, DateTime(2026, 6, 10))
      ..setStageMethod(firstId, InstallmentRepaymentMethod.flatFee)
      ..addAmortizingStage();
    final secondId = scope.read(loanCalculatorViewModelProvider).stages.last.id;
    final outcome = await notifier.calculate(
      LoanCalculatorFormTexts(
        principal: '1000',
        stages: {
          firstId: const LoanCalculatorStageTexts(
            periods: '12',
            intervalMonths: '1',
            rate: '12',
            endPrincipal: '200',
            fee: '100',
            fixedAmount: '',
          ),
          secondId: const LoanCalculatorStageTexts(
            periods: '2',
            intervalMonths: '1',
            rate: '',
            endPrincipal: '',
            fee: '',
            fixedAmount: '',
          ),
        },
      ),
    );

    expect(outcome, isA<UiActionSuccess<void>>());
    final result = scope.read(loanCalculatorViewModelProvider).result!;
    expect(result.periods, hasLength(3));
    final first = result.periods.first;
    expect(first.date, DateTime(2026, 6, 10));
    expect(first.principal, const Money(minorUnits: 80000));
    expect(first.fee, const Money(minorUnits: 10000));
    expect(first.total, const Money(minorUnits: 90000));
    expect(first.remainingPrincipal, const Money(minorUnits: 20000));
    expect(result.periods.skip(1).map((p) => p.principal.minorUnits), [
      10000,
      10000,
    ]);
    expect(result.totalFee, const Money(minorUnits: 10000));
    expect(result.periods.last.remainingPrincipal, Money.zero());
  });

  test('switching from flat fee stops charging the hidden fee', () async {
    final scope = container();
    final notifier = scope.read(loanCalculatorViewModelProvider.notifier);
    notifier.applyPreset(LoanCalculatorPreset.flatFee, principalText: '1000');
    final stage = scope.read(loanCalculatorViewModelProvider).stages.single;
    expect(stage.method, InstallmentRepaymentMethod.flatFee);
    notifier.setStageMethod(
      stage.id,
      InstallmentRepaymentMethod.equalPrincipal,
    );

    final outcome = await notifier.calculate(
      texts(scope.read(loanCalculatorViewModelProvider), fee: stage.feeText),
    );

    expect(outcome, isA<UiActionSuccess<void>>());
    expect(
      scope.read(loanCalculatorViewModelProvider).result!.totalFee,
      Money.zero(),
    );
  });

  test('flat fee rejects a negative fee', () async {
    final scope = container();
    final notifier = scope.read(loanCalculatorViewModelProvider.notifier);
    notifier.applyPreset(LoanCalculatorPreset.flatFee, principalText: '1000');
    final outcome = await notifier.calculate(
      texts(scope.read(loanCalculatorViewModelProvider), fee: '-100'),
    );
    expect((outcome as UiActionFailure<void>).error.message, '阶段 1：请输入有效手续费');
  });

  test('adds and removes stages and disables simulation for multi stage', () {
    final scope = container();
    final notifier = scope.read(loanCalculatorViewModelProvider.notifier);

    notifier.addDefermentStage();
    notifier.addAmortizingStage();
    var state = scope.read(loanCalculatorViewModelProvider);
    expect(state.stages.map((stage) => stage.kind), [
      LoanCalculatorStageKind.amortizing,
      LoanCalculatorStageKind.deferment,
      LoanCalculatorStageKind.amortizing,
    ]);
    expect(state.canSimulatePrepayment, isFalse);

    notifier.removeStage(state.stages[1].id);
    notifier.removeStage(state.stages[2].id);
    state = scope.read(loanCalculatorViewModelProvider);
    expect(state.stages, hasLength(1));
    notifier.removeStage(state.stages.single.id);
    expect(scope.read(loanCalculatorViewModelProvider).stages, hasLength(1));
  });

  test('presets replace the stage combination', () {
    final scope = container();
    final notifier = scope.read(loanCalculatorViewModelProvider.notifier);

    notifier.applyPreset(
      LoanCalculatorPreset.studentLoan,
      principalText: '12000',
    );
    final state = scope.read(loanCalculatorViewModelProvider);
    expect(state.stages.map((stage) => stage.kind), [
      LoanCalculatorStageKind.deferment,
      LoanCalculatorStageKind.amortizing,
      LoanCalculatorStageKind.amortizing,
    ]);
    expect(state.stages[1].method, InstallmentRepaymentMethod.interestFirst);
    expect(state.stages[1].accrual, InterestAccrualMethod.annual);
    expect(state.stages[2].intervalMonthsText, '12');

    notifier.applyPreset(LoanCalculatorPreset.balloon, principalText: '10000');
    expect(
      scope
          .read(loanCalculatorViewModelProvider)
          .stages
          .single
          .endPrincipalText,
      '5000.00',
    );
  });

  test('runs the prepayment simulation alongside the plan', () async {
    final scope = container();
    final notifier = scope.read(loanCalculatorViewModelProvider.notifier);
    final stageId = scope
        .read(loanCalculatorViewModelProvider)
        .stages
        .single
        .id;
    notifier
      ..setBorrowingDate(DateTime(2026, 1, 10))
      ..setStageFirstRepaymentDate(stageId, DateTime(2026, 2, 10))
      ..setStageInstallmentAmountMode(
        stageId,
        EqualInstallmentAmountMode.actualRate,
      )
      ..setSimulatePrepayment(true)
      ..setPrepaymentDate(DateTime(2026, 6, 15));

    final outcome = await notifier.calculate(
      texts(
        scope.read(loanCalculatorViewModelProvider),
        paidPeriods: '4',
        prepaymentPrincipal: '5000',
      ),
    );

    expect(outcome, isA<UiActionSuccess<void>>());
    final simulation = scope.read(loanCalculatorViewModelProvider).simulation!;
    expect(simulation.firstRecalculatedPeriodNo, 6);
    expect(simulation.interestSaved.minorUnits, greaterThan(0));

    notifier.setSimulatePrepayment(false);
    expect(scope.read(loanCalculatorViewModelProvider).simulation, isNull);
  });
}
