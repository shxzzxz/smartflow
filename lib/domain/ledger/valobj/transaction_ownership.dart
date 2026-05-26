class TransactionOwnership {
  const TransactionOwnership({
    required this.ownerType,
    this.ownerId,
    this.ownerRole,
  });

  final String ownerType;
  final int? ownerId;
  final String? ownerRole;
}
