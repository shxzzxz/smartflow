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
import 'bill_browsing_refresh.dart';

part 'bill_detail_view_model.g.dart';

final _logger = Logger('feature.credit.bill_detail');

@riverpod
class BillDetailViewModel extends _$BillDetailViewModel {
  final _browsingRefresh = BillBrowsingRefresh();

  @override
  Future<BillDetailReadModel?> build(String billId) async {
    final query = ref.watch(billQueryServiceProvider);
    final detail = await query.findBillDetail(billId);
    if (ref.mounted && detail != null) {
      _browsingRefresh.schedule(
        ref,
        refresh: () => ref
            .read(creditBillGenerationAppServiceProvider)
            .refreshBill(billId),
        onRefreshed: () async {
          final updated = await query.findBillDetail(billId);
          if (!ref.mounted) return;
          state = AsyncData(updated);
          _invalidateBillQueries(detail.summary.accountId);
        },
      );
    }
    return detail;
  }

  void reload() {
    _browsingRefresh.reset();
    ref.invalidateSelf();
  }

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
          .read(billRepaymentAppServiceProvider)
          .deleteRepayment(
            DeleteCreditRepaymentCommand(repaymentId: repaymentId),
          );
      _invalidateBillDependencies(detail.summary.accountId);
      ref
        ..invalidate(
          transactionFeedProvider(
            settlementAccountId: detail.summary.accountId,
          ),
        )
        ..invalidate(accountsByIdProvider);
    });
  }

  void _invalidateBillDependencies(String accountId) {
    _invalidateBillQueries(accountId);
    ref.invalidateSelf();
  }

  void _invalidateBillQueries(String accountId) {
    ref
      ..invalidate(billDetailProvider(billId))
      ..invalidate(billSummariesByAccountProvider(accountId))
      ..invalidate(accountBillPreviewProvider(accountId))
      ..invalidate(creditAccountOverviewProvider(accountId))
      ..invalidate(installmentsByAccountProvider(accountId))
      ..invalidate(creditAccountQueryServiceProvider);
  }

  UiActionOutcome<void> _notLoaded() {
    return const UiActionOutcome.failure(
      UiError(code: 'credit.bill.not_loaded', message: '账单尚未加载'),
    );
  }
}
