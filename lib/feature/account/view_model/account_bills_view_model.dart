import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../credit/provider/bill_query_providers.dart';
import '../../credit/provider/credit_account_query_providers.dart';
import '../../credit/view_model/bill_browsing_refresh.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import 'account_detail_view_model.dart';
import 'account_views_provider.dart';

part 'account_bills_view_model.g.dart';

final _logger = Logger('feature.account.bills');

@riverpod
class AccountBillsViewModel extends _$AccountBillsViewModel {
  final _browsingRefresh = BillBrowsingRefresh();

  @override
  AccountBillsPageState build(String accountId) {
    final account = ref.watch(accountViewProvider(accountId));
    final bills = ref.watch(billSummariesByAccountProvider(accountId));

    if (account case AsyncError()) {
      return const AccountBillsPageState.error(message: '账户加载失败，请稍后重试');
    }
    if (bills case AsyncError()) {
      return const AccountBillsPageState.error(message: '账单加载失败，请稍后重试');
    }
    if (account case AsyncData(value: null)) {
      return const AccountBillsPageState.notFound();
    }

    final accountValue = account.value;
    final billValues = bills.value;
    if (accountValue == null || billValues == null) {
      return const AccountBillsPageState.loading();
    }

    if (billValues.isNotEmpty) {
      _browsingRefresh.schedule(
        ref,
        refresh: () => ref
            .read(creditBillGenerationAppServiceProvider)
            .refreshCurrentAndFutureBillsForAccount(
              accountId: accountId,
              now: DateTime.now(),
            ),
        onRefreshed: () {
          ref
            ..invalidate(billSummariesByAccountProvider(accountId))
            ..invalidate(accountBillPreviewProvider(accountId))
            ..invalidate(creditAccountOverviewProvider(accountId))
            ..invalidate(creditAccountQueryServiceProvider);
        },
      );
    }

    return AccountBillsPageState.loaded(
      bills: billValues,
      canGenerateBill:
          accountValue.isCreditLiability && !accountValue.isArchived,
    );
  }

  Future<UiActionOutcome<void>> generateBill(DateTime month) async {
    final keepAlive = ref.keepAlive();
    try {
      return await guardUiAction(_logger, 'Bill generation', () async {
        await ref
            .read(creditBillGenerationAppServiceProvider)
            .generateBillForPeriod(
              accountId: accountId,
              period: BillPeriod(year: month.year, month: month.month),
              now: DateTime.now(),
            );
        if (ref.mounted) {
          _invalidateAccount();
        }
      });
    } finally {
      keepAlive.close();
    }
  }

  void _invalidateAccount() {
    ref
      ..invalidate(accountDetailViewModelProvider(accountId))
      ..invalidate(creditAccountOverviewProvider(accountId))
      ..invalidate(accountBillPreviewProvider(accountId))
      ..invalidate(billSummariesByAccountProvider(accountId));
  }
}

sealed class AccountBillsPageState {
  const AccountBillsPageState();

  const factory AccountBillsPageState.loading() = AccountBillsPageLoading;

  const factory AccountBillsPageState.error({required String message}) =
      AccountBillsPageError;

  const factory AccountBillsPageState.notFound() = AccountBillsPageNotFound;

  const factory AccountBillsPageState.loaded({
    required List<BillSummaryReadModel> bills,
    required bool canGenerateBill,
  }) = AccountBillsPageLoaded;
}

final class AccountBillsPageLoading extends AccountBillsPageState {
  const AccountBillsPageLoading();
}

final class AccountBillsPageError extends AccountBillsPageState {
  const AccountBillsPageError({required this.message});

  final String message;
}

final class AccountBillsPageNotFound extends AccountBillsPageState {
  const AccountBillsPageNotFound();
}

final class AccountBillsPageLoaded extends AccountBillsPageState {
  const AccountBillsPageLoaded({
    required this.bills,
    required this.canGenerateBill,
  });

  final List<BillSummaryReadModel> bills;
  final bool canGenerateBill;
}
