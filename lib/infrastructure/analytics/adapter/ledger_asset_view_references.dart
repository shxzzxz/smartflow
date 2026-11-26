import '../../../application/ledger/ledger_query_api.dart';
import '../../../domain/analytics/port/asset_view_references_port.dart';
import '../../../shared/account_profile/account_profile_kind.dart';

class LedgerAssetViewReferences implements AssetViewReferencesPort {
  const LedgerAssetViewReferences({required AccountQueryService accounts})
    : _accounts = accounts;
  final AccountQueryService _accounts;

  @override
  Future<AssetViewReferences> readReferences() async => AssetViewReferences({
    for (final account in (await _accounts.findAccountsById()).values)
      if (account.type == AccountType.asset ||
          account.type == AccountType.liability)
        account.id: AssetViewAccountReference(
          profile: accountProfileKindForAccountType(
            type: account.type,
            subtype: account.subtype,
            profileKey: account.profileKey,
          ),
          isArchived: account.isArchived,
        ),
  });
}
