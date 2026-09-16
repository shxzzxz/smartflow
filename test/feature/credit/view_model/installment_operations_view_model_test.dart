import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/reference_rate.dart';
import 'package:smartflow/feature/credit/provider/installment_query_providers.dart';
import 'package:smartflow/feature/credit/view_model/installment_operations_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import '../fixture/installment_operations_fixture.dart';

void main() {
  late RecordingRepricingService repricing;
  late RecordingInterestAdjustments adjustments;
  late ProviderContainer container;
  late InstallmentOperationsViewModel vm;
  final provider = installmentOperationsViewModelProvider('loan');
  setUp(() async {
    repricing = RecordingRepricingService();
    adjustments = RecordingInterestAdjustments();
    container = ProviderContainer(
      overrides: [
        installmentContractProvider(
          'loan',
        ).overrideWith((ref) async => operationsContract()),
        installmentRepricingAppServiceProvider.overrideWithValue(repricing),
        installmentInterestAdjustmentAppServiceProvider.overrideWithValue(
          adjustments,
        ),
      ],
    );
    container.listen(provider, (_, _) {});
    await container.read(provider.future);
    vm = container.read(provider.notifier);
  });
  tearDown(() => container.dispose());

  RepricingRecordInput manual({String bp = '-25'}) => RepricingRecordInput(
    stageId: 'stage',
    resetDate: DateTime(2026, 8, 20),
    effectiveDate: DateTime(2026, 8, 25),
    referenceRateType: InterestRateType.loanBenchmarkLongTerm,
    spreadBp: bp,
  );

  test(
    'manual records use user supplied type and signed basis points without a configuration',
    () async {
      expect(
        await vm.submit(manual(bp: ' -25 ')),
        isA<UiActionSuccess<void>>(),
      );
      expect(repricing.created.single, (
        contractId: 'loan',
        stageId: 'stage',
        reset: DateTime(2026, 8, 20),
        effective: DateTime(2026, 8, 25),
        type: InterestRateType.loanBenchmarkLongTerm,
        bp: -25,
      ));
      expect(repricing.configurations, isEmpty);
    },
  );

  test(
    'configuration fields and precise percentages reach their use cases',
    () async {
      await vm.submit(
        RepricingConfigurationInput(
          stageId: 'stage',
          effectiveFrom: DateTime(2026, 8, 8),
          firstResetDate: DateTime(2026, 8, 20),
          firstEffectiveDate: DateTime(2026, 8, 25),
          referenceRateType: InterestRateType.lprOneYear,
          cycleMonths: 6,
          spreadBp: '-30',
        ),
      );
      expect(repricing.configurations.single.rule.spreadBp, -30);
      expect(repricing.configurations.single.stageId, 'stage');
      expect(repricing.configurations.single.rule.cycleMonths, 6);
      await container.read(provider.future);
      await vm.submit(
        InterestAdjustmentInput(
          id: 'existing',
          start: DateTime(2026, 8, 15),
          end: DateTime(2026, 8, 25),
          percent: '12.3456',
        ),
      );
      expect(adjustments.saved.single.id, 'existing');
      expect(adjustments.saved.single.adjustment.ratioPpm, 123456);
      expect(adjustments.saved.single.contractId, 'loan');
    },
  );

  test(
    'invalid numeric inputs are rejected and leave the page ready for correction',
    () async {
      expect(await vm.submit(manual(bp: '1.5')), isA<UiActionFailure<void>>());
      for (final percent in ['-1', '1.00001', 'not a percentage']) {
        expect(
          await vm.submit(
            InterestAdjustmentInput(
              start: DateTime(2026, 8, 8),
              end: DateTime(2026, 9, 8),
              percent: percent,
            ),
          ),
          isA<UiActionFailure<void>>(),
        );
        expect(container.read(provider).requireValue.busy, isFalse);
      }
      expect(repricing.created, isEmpty);
      expect(adjustments.saved, isEmpty);
    },
  );

  test(
    'pending submissions block duplicate writes and a failure permits retry',
    () async {
      final pending = Completer<void>();
      repricing.onWrite = () => pending.future;
      final first = vm.submit(manual());
      expect(container.read(provider).requireValue.busy, isTrue);
      expect(await vm.submit(manual()), isA<UiActionFailure<void>>());
      expect(repricing.created, hasLength(1));
      pending.completeError(
        BusinessException(
          CreditErrorCode.contractPersistenceConflict,
          message: '同日已有记录',
        ),
      );
      final result = await first;
      expect((result as UiActionFailure<void>).error.message, '同日已有记录');
      expect(container.read(provider).requireValue.busy, isFalse);
      repricing.onWrite = null;
      expect(await vm.submit(manual()), isA<UiActionSuccess<void>>());
      expect(repricing.created, hasLength(2));
    },
  );

  test('delete intents retain their contract and record identities', () async {
    expect(await vm.deleteRepricing('rate'), isA<UiActionSuccess<void>>());
    await container.read(provider.future);
    expect(
      await vm.deleteAdjustment('adjustment'),
      isA<UiActionSuccess<void>>(),
    );
    expect(repricing.deleted, [('loan', 'rate')]);
    expect(adjustments.deleted, [('loan', 'adjustment')]);
  });
}
