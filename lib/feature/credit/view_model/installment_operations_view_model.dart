import 'package:decimal/decimal.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../domain/credit/valobj/credit_error_code.dart';
import '../../../domain/credit/valobj/floating_rate.dart';
import '../../../domain/credit/valobj/installment_plan_operation.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/credit_account_query_providers.dart';
import '../provider/installment_query_providers.dart';

part 'installment_operations_view_model.g.dart';

sealed class InstallmentOperationInput {
  const InstallmentOperationInput();
}

class RepricingConfigurationInput extends InstallmentOperationInput {
  const RepricingConfigurationInput({
    required this.stageId,
    required this.effectiveFrom,
    required this.firstResetDate,
    required this.firstEffectiveDate,
    required this.referenceRateType,
    required this.cycleMonths,
    required this.spreadBp,
  });
  final DateTime effectiveFrom, firstResetDate, firstEffectiveDate;
  final String stageId;
  final InterestRateType referenceRateType;
  final int cycleMonths;
  final String spreadBp;
}

class RepricingRecordInput extends InstallmentOperationInput {
  const RepricingRecordInput({
    required this.stageId,
    required this.resetDate,
    required this.effectiveDate,
    required this.referenceRateType,
    required this.spreadBp,
  });
  final DateTime resetDate, effectiveDate;
  final String stageId;
  final InterestRateType referenceRateType;
  final String spreadBp;
}

class InterestAdjustmentInput extends InstallmentOperationInput {
  const InterestAdjustmentInput({
    required this.start,
    required this.end,
    required this.percent,
    this.id,
  });
  final DateTime start, end;
  final String percent;
  final String? id;
}

class InstallmentOperationsState {
  const InstallmentOperationsState({required this.contract, this.busy = false});
  final InstallmentContractReadModel? contract;
  final bool busy;
}

@riverpod
class InstallmentOperationsViewModel extends _$InstallmentOperationsViewModel {
  static final _logger = Logger('feature.credit.installment_operations');

  @override
  Future<InstallmentOperationsState> build(String contractId) async =>
      InstallmentOperationsState(
        contract: await ref.watch(
          installmentContractProvider(contractId).future,
        ),
      );

  Future<UiActionOutcome<void>> submit(InstallmentOperationInput input) async {
    switch (input) {
      case RepricingConfigurationInput():
        final bp = int.tryParse(input.spreadBp.trim());
        if (bp == null) return _invalid('请输入整数基点，可为负数');
        return _run(
          () => ref
              .read(installmentRepricingServiceProvider)
              .addConfiguration(
                contractId,
                stageId: input.stageId,
                effectiveFrom: input.effectiveFrom,
                rule: FloatingRateRule(
                  referenceRateType: input.referenceRateType,
                  spreadBp: bp,
                  firstResetDate: input.firstResetDate,
                  firstEffectiveDate: input.firstEffectiveDate,
                  cycleMonths: input.cycleMonths,
                ),
              ),
        );
      case RepricingRecordInput():
        final bp = int.tryParse(input.spreadBp.trim());
        if (bp == null) return _invalid('请输入整数基点，可为负数');
        return _run(
          () => ref
              .read(installmentRepricingServiceProvider)
              .create(
                contractId,
                stageId: input.stageId,
                resetDate: input.resetDate,
                effectiveDate: input.effectiveDate,
                referenceRateType: input.referenceRateType,
                spreadBp: bp,
              ),
        );
      case InterestAdjustmentInput():
        final percent = Decimal.tryParse(input.percent.trim());
        if (percent == null || percent < Decimal.zero) {
          return _invalid('请输入非负利息比例');
        }
        final scaled = percent * Decimal.fromInt(10000);
        if (scaled != scaled.round()) return _invalid('利息比例最多保留四位小数');
        return _run(() async {
          await ref
              .read(installmentInterestAdjustmentServiceProvider)
              .save(
                contractId,
                InterestAdjustment(
                  start: input.start,
                  end: input.end,
                  ratioPpm: scaled.toBigInt().toInt(),
                ),
                id: input.id,
              );
        });
    }
  }

  Future<UiActionOutcome<void>> deleteRepricing(String id) => _run(
    () => ref.read(installmentRepricingServiceProvider).delete(contractId, id),
  );
  Future<UiActionOutcome<void>> deleteAdjustment(String id) => _run(
    () => ref
        .read(installmentInterestAdjustmentServiceProvider)
        .delete(contractId, id),
  );

  Future<UiActionOutcome<void>> _run(Future<void> Function() action) async {
    final loaded = state.asData?.value;
    if (loaded?.contract == null || loaded!.busy) {
      return UiActionOutcome.failure(
        UiError(
          code: CreditErrorCode.contractInvalidCommand.code,
          message: '请等待当前操作完成',
        ),
      );
    }
    state = AsyncData(
      InstallmentOperationsState(contract: loaded.contract, busy: true),
    );
    try {
      return await guardUiAction(
        _logger,
        'Maintain installment operations',
        () async {
          await action();
          if (!ref.mounted) return;
          ref
            ..invalidate(installmentContractProvider(contractId))
            ..invalidate(installmentSchedulesProvider(contractId))
            ..invalidate(installmentMetricsProvider(contractId))
            ..invalidate(
              installmentContractsByAccountProvider(
                loaded.contract!.liabilityAccountId,
              ),
            )
            ..invalidate(
              creditAccountOverviewProvider(
                loaded.contract!.liabilityAccountId,
              ),
            );
        },
      );
    } finally {
      if (ref.mounted) {
        final current = state.asData?.value;
        if (current != null) {
          state = AsyncData(
            InstallmentOperationsState(contract: current.contract),
          );
        }
      }
    }
  }

  UiActionOutcome<void> _invalid(String message) => UiActionOutcome.failure(
    UiError(
      code: CreditErrorCode.contractInvalidCommand.code,
      message: message,
    ),
  );
}
