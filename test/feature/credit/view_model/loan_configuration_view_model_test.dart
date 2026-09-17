import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/credit/product/installment_product_app_service.dart';
import 'package:smartflow/core/money/rounding_mode.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/installment_stage_rule.dart';
import 'package:smartflow/feature/credit/view_model/installment_terms_draft.dart';
import 'package:smartflow/feature/credit/view_model/loan_configuration_view_model.dart';
import 'package:smartflow/feature/credit/view_model/loan_comparison_view_model.dart';
import 'package:smartflow/feature/credit/view_model/loan_change_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

class _Products extends Mock implements InstallmentProductAppService {}

void main() {
  late ProviderContainer scope;
  late LoanConfigurationViewModel vm;
  final provider = loanConfigurationViewModelProvider();
  setUp(() {
    scope = ProviderContainer();
    scope.listen(provider, (_, _) {});
    vm = scope.read(provider.notifier);
    vm.setBorrowingDate(DateTime(2026, 1, 10));
    vm.setTerms(InstallmentTermsDraft.loan(DateTime(2026, 1, 10)));
  });
  tearDown(() => scope.dispose());

  Future<LoanConfiguration> submit([String principal = '12000']) async =>
      (await vm.submit(principal) as UiActionSuccess<LoanConfiguration>).value;

  test(
    'defaults to regular mode, allows zero rate and preserves draft when toggled',
    () async {
      final initial = scope.read(provider);
      expect(initial.advanced, isFalse);
      vm.setAdvanced(true);
      vm.setAdvanced(false);
      expect(scope.read(provider).terms, same(initial.terms));
      final result = await submit();
      expect(result.calculation.totalPrincipal.minorUnits, 1200000);
      expect(result.calculation.totalInterest.minorUnits, 0);
      expect(result.calculation.periods, hasLength(12));
    },
  );

  test('rejects invalid principal and stage timeline', () async {
    expect(await vm.submit('0'), isA<UiActionFailure<LoanConfiguration>>());
    final terms = scope.read(provider).terms;
    vm.setTerms(
      terms.replace(
        terms.stages.single.copyWith(firstDate: DateTime(2025, 1, 1)),
      ),
    );
    expect(await vm.submit('12000'), isA<UiActionFailure<LoanConfiguration>>());
  });

  test(
    'installment configuration returns product and terms without calculating a plan',
    () async {
      final container = ProviderContainer(
        overrides: [
          loanCalculatorQueryProvider.overrideWith(
            (ref) => throw StateError('configuration must not recalculate'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final date = DateTime(2026, 1, 10);
      final installment = InstallmentConfigurationDraft(
        principal: const Money(minorUnits: 100000),
        borrowingDate: date,
        terms: InstallmentTermsDraft.loan(date),
      );
      final configProvider = loanConfigurationViewModelProvider(
        installment: installment,
      );
      container.listen(configProvider, (_, _) {});
      final editor = container.read(configProvider.notifier);
      editor.selectProduct(_product);
      editor.setTerms(InstallmentTermsDraft.loan(date));
      final result =
          (await editor.submitInstallment('1200')
                  as UiActionSuccess<InstallmentConfigurationDraft>)
              .value;
      expect(result.productId, _product.id);
      expect(result.productName, _product.name);
      expect(result.principal, const Money(minorUnits: 120000));
      expect(result.borrowingDate, date);
      expect(result.terms.stages.single.text(StageInput.periods), '12');
    },
  );

  test(
    'product loads rules without examples and does not write back',
    () async {
      final products = _Products();
      when(() => products.list()).thenAnswer((_) async => [_product]);
      final container = ProviderContainer(
        overrides: [
          installmentProductAppServiceProvider.overrideWithValue(products),
        ],
      );
      addTearDown(container.dispose);
      container.listen(provider, (_, _) {});
      final editor = container.read(provider.notifier);
      expect(
        await editor.loadProducts(),
        isA<UiActionSuccess<List<InstallmentProductReadModel>>>(),
      );
      editor.selectProduct(_product);
      final loaded = container.read(provider);
      expect(loaded.terms.rounding, RoundingMode.halfEven);
      expect(loaded.terms.dayCount, DayCountConvention.thirty365);
      final stage = loaded.terms.stages.single;
      expect(stage.firstDate, isNull);
      expect(stage.lastDate, isNull);
      for (final field in StageInput.values.where(
        (f) => f != StageInput.interval,
      )) {
        expect(stage.text(field), isEmpty);
      }
      editor.setAdvanced(true);
      editor.setTerms(
        loaded.terms.replace(stage.setInput(StageInput.rate, '6')),
      );
      editor.setAdvanced(false);
      expect(
        container.read(provider).terms.stages.single.text(StageInput.rate),
        '6',
      );
      verify(() => products.list()).called(1);
      verifyNoMoreInteractions(products);
    },
  );

  test(
    'copy and edit preserve independent comparison configurations',
    () async {
      final original = await submit();
      scope.listen(loanComparisonViewModelProvider(), (_, _) {});
      final comparison = scope.read(loanComparisonViewModelProvider().notifier);
      comparison.setConfiguration(0, original);
      comparison.copyFirstToSecond();
      final editProvider = loanConfigurationViewModelProvider(
        initial: original,
        selection: true,
      );
      scope.listen(editProvider, (_, _) {});
      final editor = scope.read(editProvider.notifier);
      final terms = original.terms;
      editor.setTerms(
        terms.replace(terms.stages.single.setInput(StageInput.rate, '12')),
      );
      expect(
        scope.read(loanComparisonViewModelProvider()).second,
        same(original),
      );
      final modified =
          (await editor.submit('24000') as UiActionSuccess<LoanConfiguration>)
              .value;
      comparison.setConfiguration(1, modified);
      expect(
        scope
            .read(loanComparisonViewModelProvider())
            .first!
            .principal
            .minorUnits,
        1200000,
      );
      expect(
        scope
            .read(loanComparisonViewModelProvider())
            .first!
            .terms
            .stages
            .single
            .text(StageInput.rate),
        isEmpty,
      );
      expect(
        scope
            .read(loanComparisonViewModelProvider())
            .second!
            .principal
            .minorUnits,
        2400000,
      );
    },
  );

  test('prepayment accepts completed multi-stage configuration', () async {
    vm.setTerms(
      InstallmentTermsDraft(
        stages: [
          InstallmentStageDraft(
            id: 'defer',
            deferment: true,
            untilDate: DateTime(2026, 2, 10),
          ),
          InstallmentStageDraft(
            id: 'repay',
            firstDate: DateTime(2026, 3, 10),
            inputs: const {
              StageInput.periods: '2',
              StageInput.interval: '1',
              StageInput.rate: '12',
            },
          ),
        ],
      ),
    );
    final configuration = await submit();
    final provider = loanChangeViewModelProvider(initial: configuration);
    scope.listen(provider, (_, _) {});
    final changes = scope.read(provider.notifier);
    final saved = await changes.savePrepayment(
      date: DateTime(2026, 2, 11),
      principalText: '3000',
    );
    expect(saved, isA<UiActionSuccess<void>>());
    final result = await changes.simulate();
    expect(result, isA<UiActionSuccess<LoanChangeSimulation>>());
    expect(
      (result as UiActionSuccess<LoanChangeSimulation>)
          .value
          .periods
          .last
          .remainingPrincipal
          .minorUnits,
      0,
    );
  });
}

const _product = InstallmentProductReadModel(
  id: 'product',
  name: '自有产品',
  archived: false,
  stages: [
    InstallmentStageRule.repayment(
      id: 'stage',
      method: InstallmentRepaymentMethod.equalInstallment,
      intervalMonths: 1,
      ratePeriod: InterestRatePeriod.annual,
      accrual: InterestAccrualMethod.daily,
      amountAlgorithm: InstallmentAmountAlgorithm.fixed,
    ),
  ],
  dayCount: DayCountConvention.thirty365,
  rounding: RoundingMode.halfEven,
);
