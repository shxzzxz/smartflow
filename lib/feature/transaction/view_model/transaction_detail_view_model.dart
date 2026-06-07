import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../widget/business/account_lookup.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import 'transaction_detail_action_dispatcher.dart';
import 'transaction_detail_state.dart';
import 'transaction_detail_state_builder.dart';

part 'transaction_detail_view_model.g.dart';

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

    final accountLookup = await ref.watch(accountLookupProvider.future);
    return buildTransactionDetailLoadedState(
      transactionId: transactionId,
      detail: detail,
      accountLookup: accountLookup,
    );
  }

  Future<List<Account>> accountOptions(AccountUsage usage) {
    return ref.read(accountsForUsageProvider(usage).future);
  }

  Future<UiActionOutcome<void>> delete() {
    return _runAction((loaded) {
      return _actionDispatcherFor(loaded.detail.transaction).delete();
    });
  }

  Future<UiActionOutcome<void>> changeNote(String? value) {
    final normalized = value == null ? null : trimToNull(value);
    return _runAction((loaded) {
      return _actionDispatcherFor(
        loaded.detail.transaction,
      ).changeNote(normalized);
    });
  }

  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value) {
    return _runAction((loaded) {
      return _actionDispatcherFor(
        loaded.detail.transaction,
      ).changeOccurredAt(value);
    });
  }

  Future<UiActionOutcome<void>> changeAccount(
    AccountUsage usage,
    String accountId,
  ) {
    return _runAction((loaded) async {
      switch (usage) {
        case AccountUsage.settlement:
          return _actionDispatcherFor(
            loaded.detail.transaction,
          ).changeSettlementAccount(accountId);
        case AccountUsage.reimbursement:
          await ref
              .read(transactionCorrectionAppServiceProvider)
              .correctReimbursementAdvance(
                CorrectReimbursementAdvanceCommand(
                  transactionId: loaded.detail.transaction.id,
                  receivableAccountId: accountId,
                ),
              );
          return const UiActionOutcome.success(null);
        case AccountUsage.fund:
        case AccountUsage.credit:
        case AccountUsage.loan:
        case AccountUsage.repaymentTarget:
        case AccountUsage.repaymentSource:
        case AccountUsage.borrowingLiability:
          return detailInvalidCommand('当前账户用途不能在交易详情页编辑');
      }
    });
  }

  Future<UiActionOutcome<void>> toggleExcludeStats(bool value) {
    return _runAction((loaded) async {
      if (!isPlainTransaction(loaded.detail.transaction)) {
        return detailNotEditable('该交易当前不可修改统计口径');
      }
      await ref
          .read(transactionUpdateAppServiceProvider)
          .updateReportingFlag(
            UpdateTransactionReportingFlagCommand(
              transactionId: loaded.detail.transaction.id,
              isExcludedFromStats: value,
            ),
          );
      return const UiActionOutcome.success(null);
    });
  }

  Future<UiActionOutcome<void>> toggleExcludeBudget(bool value) {
    return _runAction((loaded) async {
      if (!isPlainTransaction(loaded.detail.transaction)) {
        return detailNotEditable('该交易当前不可修改统计口径');
      }
      await ref
          .read(transactionUpdateAppServiceProvider)
          .updateReportingFlag(
            UpdateTransactionReportingFlagCommand(
              transactionId: loaded.detail.transaction.id,
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
      final accountLookup = await ref.read(accountLookupProvider.future);
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
            advanceTransactionId: loaded.detail.transaction.id,
            receivableAccountId: receivableAccountId,
            receiveAccountId: receiveAccountId,
            occurredAt: input.occurredAt,
            note: note,
          ),
        );
      } else {
        await service.createReimbursementReceipt(
          CreateReimbursementReceiptCommand(
            amount: input.amount,
            advanceTransactionId: loaded.detail.transaction.id,
            receivableAccountId: receivableAccountId,
            receiveAccountId: receiveAccountId,
            occurredAt: input.occurredAt,
            note: note,
          ),
        );
      }
      return const UiActionOutcome.success(null);
    });
  }

  TransactionDetailActionDispatcher _actionDispatcherFor(
    Transaction transaction,
  ) {
    return createTransactionDetailActionDispatcher(
      transaction: transaction,
      correctionService: ref.read(transactionCorrectionAppServiceProvider),
      updateService: ref.read(transactionUpdateAppServiceProvider),
      installmentService: ref.read(installmentServiceProvider),
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
    } on Exception {
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
  TransactionDetail detail,
  AccountLookup accountLookup,
) {
  for (final entry in detail.entries) {
    if (accountLookup.typeOf(entry.accountId) == AccountType.asset &&
        entry.direction == EntryDirection.debit) {
      return entry.accountId;
    }
  }
  return null;
}
