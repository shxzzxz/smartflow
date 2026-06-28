import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/provider/ledger_query_providers.dart';
import 'account_view.dart';

part 'account_views_provider.g.dart';

@riverpod
AsyncValue<List<AccountView>> accountViews(Ref ref) {
  final accounts = ref.watch(accountListProvider);
  final creditByAccountId = ref.watch(
    creditLiabilityAccountsByAccountIdProvider,
  );

  if (accounts case AsyncError(:final error, :final stackTrace)) {
    return AsyncValue.error(error, stackTrace);
  }
  if (creditByAccountId case AsyncError(:final error, :final stackTrace)) {
    return AsyncValue.error(error, stackTrace);
  }

  final accountValues = accounts.value;
  final creditValues = creditByAccountId.value;
  if (accountValues == null || creditValues == null) {
    return const AsyncValue.loading();
  }

  try {
    return AsyncValue.data(buildAccountViews(accountValues, creditValues));
  } on Object catch (error, stackTrace) {
    return AsyncValue.error(error, stackTrace);
  }
}

@riverpod
AsyncValue<AccountView?> accountView(Ref ref, String accountId) {
  final accounts = ref.watch(accountViewsProvider);
  return accounts.whenData((items) {
    for (final item in items) {
      if (item.id == accountId) return item;
    }
    return null;
  });
}
