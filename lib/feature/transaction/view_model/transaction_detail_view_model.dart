import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../application/orchestration/orchestration_command_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../shared/account_profile/account_selection_policy.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../../credit/provider/installment_query_providers.dart';
import 'transaction_detail_action_dispatcher.dart';
import 'transaction_detail_state.dart';
import 'transaction_detail_state_builder.dart';

part 'transaction_detail_view_model.g.dart';

final _logger = Logger('feature.transaction.detail');

@riverpod
class TransactionDetailViewModel extends _$TransactionDetailViewModel {
  @override
  Future<TransactionDetailUiState> build(String transactionId) async {
    final detail = await ref.watch(
      transactionDetailProvider(transactionId).future,
    );
    if (detail == null) {
      return const TransactionDetailUiState.notFound();
    }
    final parentDetail = detail.parentTransactionId == null
        ? null
        : await ref.watch(
            transactionDetailProvider(detail.parentTransactionId!).future,
          );

    final accountLookup = await ref.watch(accountLookupProvider.future);
    final ownership = detail.ownership;
    final advanceCase = ownership?.ownerType == orchestrationAdvanceOwnerType
        ? await ref
              .read(advanceCaseQueryServiceProvider)
              .findById(ownership!.ownerId)
        : null;
    final creditRepaymentType = ownership?.ownerType == creditRepaymentOwnerType
        ? await ref
              .read(repaymentOwnerQueryProvider)
              .findType(ownership!.ownerId)
        : null;
    return buildTransactionDetailLoadedState(
      transactionId: transactionId,
      detail: detail,
      parentDetail: parentDetail,
      accountLookup: accountLookup,
      advanceCase: advanceCase,
      creditRepaymentType: creditRepaymentType,
    );
  }

  Future<List<Account>> accountOptions(AccountSelectionPurpose purpose) async {
    final accounts = await ref.read(accountQueryServiceProvider).findAccounts({
      AccountType.asset,
      AccountType.liability,
    });
    return accounts
        .where((account) => accountMatchesSelectionPurpose(account, purpose))
        .toList();
  }

  Future<UiActionOutcome<void>> delete() {
    return _runAction((loaded) {
      return _actionDispatcherFor(loaded.detail).delete();
    });
  }

  Future<UiActionOutcome<void>> changeNote(String? value) {
    final normalized = value == null ? null : trimToNull(value);
    return _runAction((loaded) {
      return _actionDispatcherFor(loaded.detail).changeNote(normalized);
    });
  }

  Future<UiActionOutcome<void>> changeTags(Set<String> tagIds) {
    return _runAction(
      (loaded) => switch (loaded.behavior.canEditTags) {
        DetailEditDenied(:final reason) => Future.value(
          detailNotEditable(reason),
        ),
        DetailEditAllowed() => detailVoidOutcomeFromAction(
          () => ref
              .read(transactionUpdateAppServiceProvider)
              .updateTags(
                UpdateTransactionTagsCommand(
                  transactionId: loaded.detail.id,
                  tagIds: tagIds,
                ),
              ),
        ),
        _ => Future.value(detailNotEditable('当前交易类型不支持修改标签')),
      },
    );
  }

  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value) {
    return _runAction((loaded) {
      return _actionDispatcherFor(loaded.detail).changeOccurredAt(value);
    });
  }

  Future<UiActionOutcome<void>> changePostedAt(DateTime value) {
    return _runAction((loaded) {
      return _actionDispatcherFor(loaded.detail).changePostedAt(value);
    });
  }

  Future<UiActionOutcome<void>> changeAccount(
    AccountSelectionPurpose purpose,
    String accountId, {
    String? currentAccountId,
  }) {
    return _runAction((loaded) async {
      switch (purpose) {
        case AccountSelectionPurpose.settlement:
        case AccountSelectionPurpose.expenseSettlement:
        case AccountSelectionPurpose.fund:
        case AccountSelectionPurpose.repaymentSource:
          return _actionDispatcherFor(loaded.detail).changeSettlementAccount(
            accountId,
            currentAccountId: currentAccountId,
          );
        case AccountSelectionPurpose.advanceReceivable:
          final ownership = loaded.detail.ownership;
          if (ownership?.ownerType != orchestrationAdvanceOwnerType) {
            return detailInvalidCommand('无法定位垫付编排实例');
          }
          final advanceCase = await ref
              .read(advanceCaseQueryServiceProvider)
              .findById(ownership!.ownerId);
          if (advanceCase == null) {
            return detailInvalidCommand('无法定位垫付编排实例');
          }
          await ref
              .read(advanceOrchestrationAppServiceProvider)
              .editAdvance(
                EditAdvanceWorkflowCommand(
                  transactionId: loaded.detail.id,
                  scenario: advanceCase.scenario,
                  receivableAccountId: accountId,
                ),
              );
          return const UiActionOutcome.success(null);
        case AccountSelectionPurpose.ordinaryReceivable:
        case AccountSelectionPurpose.receivable:
        case AccountSelectionPurpose.prepaidExpense:
        case AccountSelectionPurpose.deferredIncome:
          return detailInvalidCommand('当前账户用途不能在交易详情页编辑');
        case AccountSelectionPurpose.repaymentTarget:
        case AccountSelectionPurpose.borrowingLiability:
          return detailInvalidCommand('当前账户用途不能在交易详情页编辑');
      }
    });
  }

  Future<UiActionOutcome<void>> toggleExcludeStats(bool value) {
    return _runAction((loaded) async {
      if (loaded.detail.parentTransactionId != null) {
        return detailNotEditable('跟随所属交易组设置，请在顶层交易修改');
      }
      final ownership = loaded.detail.ownership;
      if (ownership?.ownerType == orchestrationAmortizationOwnerType) {
        await ref
            .read(amortizationPlanAppServiceProvider)
            .updateTransactionReporting(
              UpdateAmortizationTransactionReportingCommand(
                planId: ownership!.ownerId,
                transactionId: loaded.detail.id,
                isExcludedFromStats: value,
                isExcludedFromBudget: loaded.detail.isExcludedFromBudget,
              ),
            );
        return const UiActionOutcome.success(null);
      }
      await ref
          .read(transactionUpdateAppServiceProvider)
          .updateReportingFlag(
            UpdateTransactionReportingFlagCommand(
              transactionId: loaded.detail.id,
              isExcludedFromStats: value,
            ),
          );
      return const UiActionOutcome.success(null);
    });
  }

  Future<UiActionOutcome<void>> toggleExcludeBudget(bool value) {
    return _runAction((loaded) async {
      if (loaded.detail.parentTransactionId != null) {
        return detailNotEditable('跟随所属交易组设置，请在顶层交易修改');
      }
      final ownership = loaded.detail.ownership;
      if (ownership?.ownerType == orchestrationAmortizationOwnerType) {
        await ref
            .read(amortizationPlanAppServiceProvider)
            .updateTransactionReporting(
              UpdateAmortizationTransactionReportingCommand(
                planId: ownership!.ownerId,
                transactionId: loaded.detail.id,
                isExcludedFromStats: loaded.detail.isExcludedFromStats,
                isExcludedFromBudget: value,
              ),
            );
        return const UiActionOutcome.success(null);
      }
      await ref
          .read(transactionUpdateAppServiceProvider)
          .updateReportingFlag(
            UpdateTransactionReportingFlagCommand(
              transactionId: loaded.detail.id,
              isExcludedFromBudget: value,
            ),
          );
      return const UiActionOutcome.success(null);
    });
  }

  Future<UiActionOutcome<void>> submitAdvance(AdvanceSubmitInput input) {
    return _runAction((loaded) async {
      final accountLookup = AccountLookup(
        await ref.read(accountQueryServiceProvider).findAccountsById(),
      );
      final receivableAccountId = _receivableAccountId(
        loaded.detail,
        accountLookup,
      );
      if (receivableAccountId == null) {
        return detailInvalidCommand('无法定位垫付应收账户');
      }
      final receiveAccountId = input.receiveAccountId ?? receivableAccountId;
      final note = trimToNull(input.noteText);
      final service = ref.read(advanceOrchestrationAppServiceProvider);
      if (input.settleAdvance) {
        final gapExpenseAllocations =
            input.gapExpenseAllocations ??
            _defaultGapExpenseAllocations(loaded.detail, input.amount);
        await service.createSettlement(
          CreateAdvanceSettlementWorkflowCommand(
            actualReceivedAmount: input.amount,
            advanceTransactionId: loaded.detail.id,
            receivableAccountId: receivableAccountId,
            settlementAllocations: singleAllocation(
              accountId: receiveAccountId,
              amount: input.amount,
            ),
            gapExpenseAllocations: gapExpenseAllocations,
            occurredAt: input.occurredAt,
            note: note,
          ),
        );
      } else {
        await service.createCollection(
          CreateAdvanceCollectionWorkflowCommand(
            amount: input.amount,
            advanceTransactionId: loaded.detail.id,
            receivableAccountId: receivableAccountId,
            settlementAllocations: singleAllocation(
              accountId: receiveAccountId,
              amount: input.amount,
            ),
            occurredAt: input.occurredAt,
            note: note,
          ),
        );
      }
      return const UiActionOutcome.success(null);
    });
  }

  TransactionDetailActionDispatcher _actionDispatcherFor(
    TransactionReadModel transaction,
  ) {
    final isAdvance =
        transaction.ownership?.ownerType == orchestrationAdvanceOwnerType;
    return createTransactionDetailActionDispatcher(
      transaction: transaction,
      editService: ref.read(transactionEditAppServiceProvider),
      updateService: ref.read(transactionUpdateAppServiceProvider),
      installmentAppService: ref.read(installmentContractAppServiceProvider),
      disbursementInstallmentAppService: ref.read(
        disbursementInstallmentAppServiceProvider,
      ),
      consumptionInstallmentAppService: ref.read(
        consumptionInstallmentAppServiceProvider,
      ),
      billRepaymentAppService: ref.read(billRepaymentAppServiceProvider),
      installmentPrepaymentAppService: ref.read(
        installmentPrepaymentAppServiceProvider,
      ),
      accountRepaymentAppService: ref.read(accountRepaymentAppServiceProvider),
      repaymentOwnerQuery: ref.read(repaymentOwnerQueryProvider),
      advanceAppService: isAdvance
          ? ref.read(advanceOrchestrationAppServiceProvider)
          : null,
      advanceCaseQuery: isAdvance
          ? ref.read(advanceCaseQueryServiceProvider)
          : null,
    );
  }

  Future<UiActionOutcome<void>> _runAction(
    Future<UiActionOutcome<void>> Function(TransactionDetailLoaded loaded) body,
  ) async {
    final loaded = state.asData?.value;
    if (loaded is! TransactionDetailLoaded) {
      return detailInvalidCommand('交易详情尚未加载');
    }
    _setSubmitting(true);
    try {
      final outcome = await body(loaded);
      if (outcome is UiActionSuccess<void>) {
        _invalidateInstallmentAfterRefundChange(loaded.detail);
      }
      return outcome;
    } on AppException catch (exception, stackTrace) {
      logUiActionException(
        _logger,
        'Transaction detail action',
        exception,
        stackTrace,
      );
      return UiActionOutcome.failure(UiError.fromException(exception));
    } on Exception catch (exception, stackTrace) {
      _logger.severe(
        'Transaction detail action failed unexpectedly.',
        exception,
        stackTrace,
      );
      return const UiActionOutcome.failure(UiError.unknown());
    } finally {
      _setSubmitting(false);
    }
  }

  void _setSubmitting(bool submitting) {
    final loaded = state.asData?.value;
    if (loaded is TransactionDetailLoaded) {
      state = AsyncData(loaded.copyWith(submitting: submitting));
    }
  }

  void _invalidateInstallmentAfterRefundChange(TransactionReadModel detail) {
    final ownerType = detail.ownership?.ownerType;
    final contractId = detail.ownership?.ownerId;
    if (detail.businessPurpose != BusinessPurpose.refund ||
        ownerType != installmentOwnerType ||
        contractId == null) {
      return;
    }
    ref
      ..invalidate(installmentContractProvider(contractId))
      ..invalidate(installmentSchedulesProvider(contractId))
      ..invalidate(installmentActivitiesProvider(contractId))
      ..invalidate(installmentMetricsProvider(contractId));
  }
}

String? _receivableAccountId(
  TransactionReadModel detail,
  AccountLookup accountLookup,
) {
  return detail.accountOf(TransactionRole.receivable);
}

List<AccountAmountAllocation> _defaultGapExpenseAllocations(
  TransactionReadModel detail,
  Money actualReceivedAmount,
) {
  final outstanding = detail.advanceSummary?.outstanding;
  if (outstanding == null) return const [];
  final shortfall = outstanding - actualReceivedAmount;
  final remaining =
      detail.refundSummary?.remainingCategoryAllocations ?? const [];
  if (shortfall.minorUnits <= 0 || remaining.length != 1) return const [];
  return [remaining.single.copyWith(amount: shortfall)];
}
