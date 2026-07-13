import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../core/error/app_exception.dart';
import '../../credit/provider/bill_query_providers.dart';
import '../../credit/provider/credit_account_query_providers.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import 'account_detail_view_model.dart';

part 'account_credit_actions.g.dart';

@riverpod
class AccountCreditActions extends _$AccountCreditActions {
  @override
  void build(String accountId) {}

  Future<UiActionOutcome<void>> generateHistoricalBill(DateTime month) async {
    try {
      await ref
          .read(creditBillGenerationAppServiceProvider)
          .generateBillForPeriod(
            accountId: accountId,
            period: BillPeriod(year: month.year, month: month.month),
            now: DateTime.now(),
          );
      _invalidateAccount();
      return const UiActionOutcome.success(null);
    } on AppException catch (exception) {
      return UiActionOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const UiActionOutcome.failure(
        UiError(
          code: 'credit.bill.generate_failed',
          message: '账单生成失败，请稍后重试',
        ),
      );
    }
  }

  Future<UiActionOutcome<void>> deleteUnattributedRepayment(
    String repaymentId,
  ) async {
    try {
      await ref
          .read(repaymentAppServiceProvider)
          .deleteRepayment(
            DeleteCreditRepaymentCommand(repaymentId: repaymentId),
          );
      _invalidateAccount();
      ref
        ..invalidate(transactionListProvider(accountId: accountId))
        ..invalidate(accountsByIdProvider);
      return const UiActionOutcome.success(null);
    } on AppException catch (exception) {
      return UiActionOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const UiActionOutcome.failure(
        UiError(
          code: 'credit.repayment.delete_failed',
          message: '还款记录删除失败，请稍后重试',
        ),
      );
    }
  }

  void _invalidateAccount() {
    ref
      ..invalidate(accountDetailViewModelProvider(accountId))
      ..invalidate(creditAccountOverviewProvider(accountId))
      ..invalidate(billSummariesByAccountProvider(accountId));
  }
}
