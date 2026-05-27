class TransactionOwnership {
  const TransactionOwnership({
    required this.ownerType,
    this.ownerId,
    this.ownerRole,
  });

  final String ownerType;
  final String? ownerId;
  final String? ownerRole;
}
