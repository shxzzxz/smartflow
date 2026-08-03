import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/account_section_presentation.dart';
import 'account_views_provider.dart';

part 'archived_accounts_view_model.g.dart';

@riverpod
class ArchivedAccountsViewModel extends _$ArchivedAccountsViewModel {
  @override
  ArchivedAccountsPageState build() {
    final accounts = ref.watch(archivedAccountViewsProvider);
    final groups = ref.watch(accountGroupsProvider);

    if (accounts case AsyncError()) {
      return const ArchivedAccountsPageState.error(
        UiError(
          code: 'account.archived.load_failed',
          message: '已归档账户加载失败，请稍后重试',
        ),
      );
    }
    if (groups case AsyncError()) {
      return const ArchivedAccountsPageState.error(
        UiError(
          code: 'account.archived.load_failed',
          message: '已归档账户加载失败，请稍后重试',
        ),
      );
    }

    final accountValues = accounts.value;
    final groupValues = groups.value;
    if (accountValues == null || groupValues == null) {
      return const ArchivedAccountsPageState.loading();
    }

    return ArchivedAccountsPageState.loaded(
      buildArchivedAccountSections(accountValues, groupValues),
    );
  }
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
