import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../application/analytics/analytics_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart' show AccountType;
import '../../../core/error/app_exception.dart';
import '../../../domain/analytics/valobj/analytics_error_code.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/account_section_presentation.dart';
import 'account_view.dart';
import 'account_views_provider.dart';
import 'asset_views_provider.dart';

part 'archived_accounts_view_model.g.dart';

@riverpod
ArchivedAccountsPageState scopedArchivedAccountsPage(
  Ref ref,
  Set<String>? accountIds,
  AccountType? accountType, {
  String? viewId,
}) {
  final state = viewId == null
      ? ref.watch(archivedAccountsViewModelProvider)
      : _archivedState(
          ref.watch(archivedAccountViewsProvider),
          ref.watch(assetViewsProvider).whenData((views) {
            final view = views.where((view) => view.id == viewId).firstOrNull;
            if (view == null) {
              throw BusinessException(AnalyticsErrorCode.viewNotFound);
            }
            return view;
          }),
        );
  if (state is! ArchivedAccountsPageLoaded ||
      (accountIds == null && accountType == null)) {
    return state;
  }
  return ArchivedAccountsPageState.loaded([
    for (final section in state.sections)
      if (section.accounts.any(
        (account) =>
            (accountIds == null || accountIds.contains(account.id)) &&
            (accountType == null || account.accountType == accountType),
      ))
        AccountSectionPresentation(
          id: section.id,
          title: section.title,
          accounts: section.accounts
              .where(
                (account) =>
                    (accountIds == null || accountIds.contains(account.id)) &&
                    (accountType == null || account.accountType == accountType),
              )
              .toList(),
        ),
  ]);
}

@riverpod
class ArchivedAccountsViewModel extends _$ArchivedAccountsViewModel {
  @override
  ArchivedAccountsPageState build() => _archivedState(
    ref.watch(archivedAccountViewsProvider),
    ref.watch(selectedAssetViewProvider),
  );
}

ArchivedAccountsPageState _archivedState(
  AsyncValue<List<AccountView>> accounts,
  AsyncValue<AssetView> view,
) {
  if (accounts.hasError || view.hasError) {
    return const ArchivedAccountsPageState.error(
      UiError(code: 'account.archived.load_failed', message: '已归档账户加载失败，请稍后重试'),
    );
  }
  if (!accounts.hasValue || !view.hasValue) {
    return const ArchivedAccountsPageState.loading();
  }
  return ArchivedAccountsPageState.loaded(
    buildArchivedAccountSections(accounts.requireValue, view.requireValue),
  );
}

sealed class ArchivedAccountsPageState {
  const ArchivedAccountsPageState();

  const factory ArchivedAccountsPageState.loading() =
      ArchivedAccountsPageLoading;

  const factory ArchivedAccountsPageState.error(UiError error) =
      ArchivedAccountsPageError;

  factory ArchivedAccountsPageState.loaded(
    List<AccountSectionPresentation> sections,
  ) = ArchivedAccountsPageLoaded;
}

final class ArchivedAccountsPageLoading extends ArchivedAccountsPageState {
  const ArchivedAccountsPageLoading();
}

final class ArchivedAccountsPageError extends ArchivedAccountsPageState {
  const ArchivedAccountsPageError(this.error);

  final UiError error;
}

final class ArchivedAccountsPageLoaded extends ArchivedAccountsPageState {
  ArchivedAccountsPageLoaded(List<AccountSectionPresentation> sections)
    : sections = List.unmodifiable(sections);

  final List<AccountSectionPresentation> sections;
}
