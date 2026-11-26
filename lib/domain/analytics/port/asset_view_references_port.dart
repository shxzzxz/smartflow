import '../../../shared/account_profile/account_profile_kind.dart';

class AssetViewAccountReference {
  const AssetViewAccountReference({
    required this.profile,
    required this.isArchived,
  });
  final AccountProfileKind profile;
  final bool isArchived;
}

class AssetViewReferences {
  AssetViewReferences(Map<String, AssetViewAccountReference> accounts)
    : accounts = Map.unmodifiable(accounts);
  final Map<String, AssetViewAccountReference> accounts;
}

abstract interface class AssetViewReferencesPort {
  Future<AssetViewReferences> readReferences();
}
