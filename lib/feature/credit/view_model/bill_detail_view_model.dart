import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/bill_query_providers.dart';
import '../provider/credit_account_query_providers.dart';
import '../provider/installment_query_providers.dart';

part 'bill_detail_view_model.g.dart';

final _logger = Logger('feature.credit.bill_detail');

@riverpod
class BillDetailViewModel extends _$BillDetailViewModel {
  @override
  Future<BillDetailReadModel?> build(String billId) {
    return ref.watch(billDetailProvider(billId).future);
  }

  void reload() => ref.invalidateSelf();

  Future<UiActionOutcome<void>> synchronizeProjection() async {
    final detail = state.asData?.value;
    if (detail == null) return _notLoaded();
    return guardUiAction(_logger, 'Bill refresh', () async {
      await ref
          .read(creditBillGenerationAppServiceProvider)
          .refreshBill(billId);
      _invalidateBillDependencies(detail.summary.accountId);
    });
  }

  Future<UiActionOutcome<void>> deleteBill() async {
    final detail = state.asData?.value;
    if (detail == null) return _notLoaded();
    return guardUiAction(_logger, 'Bill delete', () async {
      await ref.read(creditBillGenerationAppServiceProvider).deleteBill(billId);
      _invalidateBillDependencies(detail.summary.accountId);
    });
  }

  Future<UiActionOutcome<void>> deleteRepayment(String repaymentId) async {
    final detail = state.asData?.value;
    if (detail == null) return _notLoaded();
    return guardUiAction(_logger, 'Bill repayment delete', () async {
      await ref
          .read(repaymentAppServiceProvider)
          .deleteRepayment(
            DeleteCreditRepaymentCommand(repaymentId: repaymentId),
          );
      _invalidateBillDependencies(detail.summary.accountId);
      ref
        ..invalidate(
          transactionListProvider(
            settlementAccountId: detail.summary.accountId,
          ),
        )
        ..invalidate(accountsByIdProvider);
    });
  }

  void _invalidateBillDependencies(String accountId) {
    ref
      ..invalidateSelf()
      ..invalidate(billDetailProvider(billId))
      ..invalidate(billSummariesByAccountProvider(accountId))
      ..invalidate(creditAccountOverviewProvider(accountId))
      ..invalidate(installmentContractsByAccountProvider(accountId));
  }

  UiActionOutcome<void> _notLoaded() {
    return const UiActionOutcome.failure(
      UiError(code: 'credit.bill.not_loaded', message: '账单尚未加载'),
    );
  }
}
