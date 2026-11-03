import 'account_lookup.dart';

class TransactionCategoryIdentity {
  const TransactionCategoryIdentity({
    required this.accountIds,
    this.name,
    this.iconKey,
  });

  final List<String> accountIds;
  final String? name;
  final String? iconKey;

  bool get isEmpty => accountIds.isEmpty;
  bool get hasMultiple => accountIds.length > 1;
}

TransactionCategoryIdentity resolveTransactionCategoryIdentity({
  required Iterable<String> transactionAccountIds,
  required AccountLookup accountLookup,
  Iterable<String> supplementalAccountIds = const [],
}) {
  final accountIds = <String>{
    ...transactionAccountIds,
    ...supplementalAccountIds,
  }.toList(growable: false);
  final account = accountIds.length == 1
      ? accountLookup.find(accountIds.single)
      : null;
  return TransactionCategoryIdentity(
    accountIds: accountIds,
    name: account?.name,
    iconKey: account?.iconKey,
  );
}
