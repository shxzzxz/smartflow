import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/reference_rate/reference_rate_service.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/feature/credit/view_model/installment_terms_draft.dart';
import 'package:smartflow/feature/credit/view_model/loan_configuration_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  late ProviderContainer container;
  late LoanConfigurationViewModel vm;
  late _Rates rates;
  final provider = loanConfigurationViewModelProvider();

  setUp(() {
    rates = _Rates();
    container = ProviderContainer(
      overrides: [referenceRateServiceProvider.overrideWithValue(rates)],
    );
    container.listen(provider, (_, _) {});
    vm = container.read(provider.notifier);
    vm.setBorrowingDate(DateTime(2025, 1, 10));
  });
  tearDown(() => container.dispose());

  test(
    'each stage uses its historical start date and saves only the initial rate',
    () async {
      vm.setTerms(
        InstallmentTermsDraft(
          stages: [
            _stage('first', DateTime(2025, 2, 10), '-30'),
            _stage('second', DateTime(2025, 3, 10), '20'),
          ],
        ),
      );
      await vm.refreshReferenceRates();
      expect(
        container
            .read(provider)
            .terms
            .stages
            .map((s) => s.text(StageInput.rate)),
        ['3.3', '3.4'],
      );
      expect(
        rates.requests,
        containsAll([
          (InterestRateType.lprOneYear, DateTime.utc(2025, 1, 10)),
          (InterestRateType.lprOneYear, DateTime.utc(2025, 2, 10)),
        ]),
      );

      final terms = container.read(provider).terms;
      vm.setTerms(
        terms.replace(
          terms.stages.first.copyWith(firstDate: DateTime(2025, 2, 20)),
        ),
      );
      await vm.refreshReferenceRates();
      expect(rates.requests.last, (
        InterestRateType.lprOneYear,
        DateTime.utc(2025, 2, 20),
      ));
      final outcome = await vm.submit('1000');
      expect(outcome, isA<UiActionSuccess<LoanConfiguration>>());
      final saved = (outcome as UiActionSuccess<LoanConfiguration>).value.terms
          .contractTerms();
      expect(saved.repayments.map((s) => s.rate!.ppm), [33000, 34000]);
      expect(saved.repayments.every((s) => s.floatingRate == null), isTrue);
    },
  );

  test(
    'late historical responses never overwrite the latest date or BP',
    () async {
      final old = Completer<ReferenceRateResolution>();
      final current = Completer<ReferenceRateResolution>();
      rates.resolver = (type, date) =>
          date.day == 10 ? old.future : current.future;
      vm.setTerms(
        InstallmentTermsDraft(
          stages: [_stage('first', DateTime(2025, 3, 10), '0')],
        ),
      );
      vm.setBorrowingDate(DateTime(2025, 1, 20));
      var terms = container.read(provider).terms;
      vm.setTerms(
        terms.replace(terms.stages.single.setInput(StageInput.spreadBp, '-50')),
      );
      old.complete(
        _quote(InterestRateType.lprOneYear, DateTime.utc(2025, 1, 10), 20000),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(provider).terms.stages.single.text(StageInput.rate),
        isEmpty,
      );
      current.complete(
        _quote(InterestRateType.lprOneYear, DateTime.utc(2025, 1, 20), 40000),
      );
      await vm.refreshReferenceRates();
      terms = container.read(provider).terms;
      expect(terms.stages.single.text(StageInput.rate), '3.5');
      expect(terms.stages.single.text(StageInput.spreadBp), '-50');
    },
  );

  test(
    'missing quotes can be retried and negative derived rates cannot be saved',
    () async {
      rates.resolver = (type, date) async => ReferenceRateResolution(
        date: date,
        reason: ReferenceRateMissingReason.noHistory,
      );
      vm.setTerms(
        InstallmentTermsDraft(
          stages: [_stage('first', DateTime(2025, 2, 10), '0')],
        ),
      );
      await vm.refreshReferenceRates();
      expect(container.read(provider).retryableRateStageIds, {'first'});
      expect(
        await vm.submit('1000'),
        isA<UiActionFailure<LoanConfiguration>>(),
      );
      rates.resolver = null;
      await vm.refreshReferenceRates(retry: true);
      expect(
        container.read(provider).terms.stages.single.text(StageInput.rate),
        '3.6',
      );
      var terms = container.read(provider).terms;
      vm.setTerms(
        terms.replace(
          terms.stages.single.setInput(StageInput.spreadBp, '-500'),
        ),
      );
      expect(
        await vm.submit('1000'),
        isA<UiActionFailure<LoanConfiguration>>(),
      );
      expect(container.read(provider).rateMessages['first'], '执行利率不得为负');
      terms = container.read(provider).terms;
      vm.setTerms(
        terms.replace(terms.stages.single.setInput(StageInput.spreadBp, '0')),
      );
      expect(
        await vm.submit('1000'),
        isA<UiActionSuccess<LoanConfiguration>>(),
      );
    },
  );
}

InstallmentStageDraft _stage(String id, DateTime firstDate, String bp) =>
    InstallmentStageDraft(
      id: id,
      firstDate: firstDate,
      method: InstallmentRepaymentMethod.interestFirst,
      rateType: InterestRateType.lprOneYear,
      inputs: {
        StageInput.interval: '1',
        StageInput.periods: '1',
        StageInput.spreadBp: bp,
      },
    );

ReferenceRateResolution _quote(InterestRateType type, DateTime date, int ppm) =>
    ReferenceRateResolution(
      date: date,
      rate: ReferenceRate(type: type, date: date, ratePpm: ppm, source: 'test'),
    );

class _Rates implements ReferenceRateService {
  final requests = <(InterestRateType, DateTime)>[];
  Future<ReferenceRateResolution> Function(InterestRateType, DateTime)?
  resolver;

  @override
  Future<ReferenceRateResolution> resolveOne(
    InterestRateType type,
    DateTime date,
  ) async {
    requests.add((type, date));
    if (resolver case final callback?) return callback(type, date);
    return _quote(type, date, date.month < 2 ? 36000 : 32000);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
