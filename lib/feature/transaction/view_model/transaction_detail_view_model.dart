import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../shared/account_profile/account_selection_policy.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';
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
    return buildTransactionDetailLoadedState(
      transactionId: transactionId,
      detail: detail,
      parentDetail: parentDetail,
      accountLookup: accountLookup,
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
        DetailEditAllowed() => _actionDispatcherFor(
          loaded.detail,
        ).changeTags(Set.of(tagIds)),
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
    String accountId,
  ) {
    return _runAction((loaded) async {
      switch (purpose) {
        case AccountSelectionPurpose.settlement:
        case AccountSelectionPurpose.fund:
        case AccountSelectionPurpose.repaymentSource:
          return _actionDispatcherFor(
            loaded.detail,
          ).changeSettlementAccount(accountId);
        case AccountSelectionPurpose.reimbursementReceivable:
          await ref
              .read(transactionEditAppServiceProvider)
              .editReimbursementAdvance(
                EditReimbursementAdvanceCommand(
                  transactionId: loaded.detail.id,
                  receivableAccountId: accountId,
                ),
              );
          return const UiActionOutcome.success(null);
        case AccountSelectionPurpose.ordinaryReceivable:
        case AccountSelectionPurpose.receivable:
          return detailInvalidCommand('当前账户用途不能在交易详情页编辑');
        case AccountSelectionPurpose.repaymentTarget:
        case AccountSelectionPurpose.borrowingLiability:
          return detailInvalidCommand('当前账户用途不能在交易详情页编辑');
      }
    });
  }

  Future<UiActionOutcome<void>> toggleExcludeStats(bool value) {
    return _runAction((loaded) async {
      if (!isPlainTransaction(loaded.detail)) {
        return detailNotEditable('该交易当前不可修改统计口径');
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
      if (!isPlainTransaction(loaded.detail)) {
        return detailNotEditable('该交易当前不可修改统计口径');
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

  Future<UiActionOutcome<void>> submitReimbursement(
    ReimbursementSubmitInput input,
  ) {
    return _runAction((loaded) async {
      final accountLookup = AccountLookup(
        await ref.read(accountQueryServiceProvider).findAccountsById(),
      );
      final receivableAccountId = _receivableAccountId(
        loaded.detail,
        accountLookup,
      );
      if (receivableAccountId == null) {
        return detailInvalidCommand('无法定位报销账户');
      }
      final receiveAccountId = input.receiveAccountId ?? receivableAccountId;
      final note = trimToNull(input.noteText);
      final service = ref.read(transactionPostingAppServiceProvider);
      if (input.closeReimbursement) {
        await service.closeReimbursement(
          CloseReimbursementCommand(
            actualReceivedAmount: input.amount,
            advanceTransactionId: loaded.detail.id,
            receivableAccountId: receivableAccountId,
            settlementAllocations: singleAllocation(
              accountId: receiveAccountId,
              amount: input.amount,
            ),
            gapExpenseAllocations: const [],
            occurredAt: input.occurredAt,
            note: note,
          ),
        );
      } else {
        await service.createReimbursementReceipt(
          CreateReimbursementReceiptCommand(
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
    return createTransactionDetailActionDispatcher(
      transaction: transaction,
      editService: ref.read(transactionEditAppServiceProvider),
      updateService: ref.read(transactionUpdateAppServiceProvider),
      installmentAppService: ref.read(installmentAppServiceProvider),
      repaymentAppService: ref.read(repaymentAppServiceProvider),
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
      return await body(loaded);
    } on AppException catch (exception) {
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
}

String? _receivableAccountId(
  TransactionReadModel detail,
  AccountLookup accountLookup,
) {
  return detail.accountOf(TransactionRole.receivable);
}
