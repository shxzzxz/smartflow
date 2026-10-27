class TransactionOwnership {
  const TransactionOwnership({required this.ownerType, required this.ownerId});

  final String ownerType;
  final String ownerId;

  @override
  bool operator ==(Object other) {
    return other is TransactionOwnership &&
        other.ownerType == ownerType &&
        other.ownerId == ownerId;
  }

  @override
  int get hashCode => Object.hash(ownerType, ownerId);
}
