import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_query_api.dart';
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

/// 已归档的资产/负债账户只用于资产页归档入口及归档账户页；它们不参与
/// 日常账户选择和资产统计。
@riverpod
AsyncValue<List<AccountView>> archivedAccountViews(Ref ref) {
  final accountsById = ref.watch(accountsByIdProvider);
  final creditByAccountId = ref.watch(
    creditLiabilityAccountsByAccountIdProvider,
  );

  if (accountsById case AsyncError(:final error, :final stackTrace)) {
    return AsyncValue.error(error, stackTrace);
  }
  if (creditByAccountId case AsyncError(:final error, :final stackTrace)) {
    return AsyncValue.error(error, stackTrace);
  }

  final accounts = accountsById.value;
  final creditValues = creditByAccountId.value;
  if (accounts == null || creditValues == null) {
    return const AsyncValue.loading();
  }

  try {
    return AsyncValue.data(
      buildAccountViews(
        accounts.values
            .where(
              (account) =>
                  account.isArchived &&
                  (account.type == AccountType.asset ||
                      account.type == AccountType.liability),
            )
            .toList(),
        creditValues,
      ),
    );
  } on Object catch (error, stackTrace) {
    return AsyncValue.error(error, stackTrace);
  }
}

@riverpod
AsyncValue<AccountView?> accountView(Ref ref, String accountId) {
  final accounts = ref.watch(accountViewsProvider);
  final active = accounts.value;
  if (active != null) {
    for (final item in active) {
      if (item.id == accountId) return AsyncValue.data(item);
    }
  }
  final account = ref.watch(accountByIdProvider(accountId));
  final creditByAccountId = ref.watch(
    creditLiabilityAccountsByAccountIdProvider,
  );
  if (account case AsyncError(:final error, :final stackTrace)) {
    return AsyncValue.error(error, stackTrace);
  }
  if (creditByAccountId case AsyncError(:final error, :final stackTrace)) {
    return AsyncValue.error(error, stackTrace);
  }
  final accountValue = account.value;
  final creditValues = creditByAccountId.value;
  if (accountValue == null) {
    return account.hasValue
        ? const AsyncValue.data(null)
        : const AsyncValue.loading();
  }
  if (creditValues == null) {
    return const AsyncValue.loading();
  }
  try {
    return AsyncValue.data(buildAccountView(accountValue, creditValues));
  } on Object catch (error, stackTrace) {
    return AsyncValue.error(error, stackTrace);
  }
}

@riverpod
Future<Account?> accountById(Ref ref, String accountId) {
  return ref.watch(accountQueryServiceProvider).findAccountById(accountId);
}
