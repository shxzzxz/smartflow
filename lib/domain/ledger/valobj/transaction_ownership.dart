class TransactionOwnership {
  const TransactionOwnership({
    required this.ownerType,
    this.ownerId,
    this.ownerRole,
  });

  final String ownerType;
  final String? ownerId;
  final String? ownerRole;

  @override
  bool operator ==(Object other) {
    return other is TransactionOwnership &&
        other.ownerType == ownerType &&
        other.ownerId == ownerId &&
        other.ownerRole == ownerRole;
  }

  @override
  int get hashCode => Object.hash(ownerType, ownerId, ownerRole);
}
