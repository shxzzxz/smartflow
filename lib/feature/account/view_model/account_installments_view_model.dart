import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../shared/account_profile/account_profile_kind.dart';
import '../../credit/provider/installment_query_providers.dart';
import 'account_views_provider.dart';

part 'account_installments_view_model.g.dart';

class AccountInstallmentsState {
  const AccountInstallmentsState({
    required this.accountKind,
    required this.contracts,
  });

  final AccountProfileKind accountKind;
  final List<InstallmentContractReadModel> contracts;
}

@riverpod
AsyncValue<AccountInstallmentsState?> accountInstallmentsViewModel(
  Ref ref,
  String accountId,
) {
  final account = ref.watch(accountViewProvider(accountId));
  final contracts = ref.watch(installmentContractsByAccountProvider(accountId));
  if (account case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (account case AsyncData(value: null)) return const AsyncData(null);
  if (contracts case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (account.value case final value?) {
    if (contracts.value case final items?) {
      return AsyncData(
        AccountInstallmentsState(accountKind: value.kind, contracts: items),
      );
    }
  }
  return const AsyncLoading();
}
