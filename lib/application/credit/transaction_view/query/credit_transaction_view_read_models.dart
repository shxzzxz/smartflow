import '../../../../domain/credit/valobj/repayment_enums.dart';

/// Credit-owned business activity kinds exposed to the transaction view.
enum CreditTransactionViewItemType {
  installment('credit.installment_contract'),
  repayment('credit.repayment');

  const CreditTransactionViewItemType(this.code);

  final String code;
}

final class CreditTransactionViewQuery {
  CreditTransactionViewQuery({
    required this.occurredFrom,
    required this.occurredUntil,
    this.before,
    this.limit = 20,
    Set<CreditTransactionViewItemType>? itemTypes,
    Set<String>? categoryAccountIds,
    Set<String>? settlementAccountIds,
    Set<String>? tagIds,
    this.untaggedOnly = false,
    this.counterpartyId,
  }) : itemTypes = _immutableTypes(itemTypes),
       categoryAccountIds = _immutableStrings(categoryAccountIds),
       settlementAccountIds = _immutableStrings(settlementAccountIds),
       tagIds = _immutableStrings(tagIds),
       assert(occurredUntil.isAfter(occurredFrom)),
       assert(limit > 0),
       assert(!untaggedOnly || tagIds == null);

  final DateTime occurredFrom;
  final DateTime occurredUntil;
  final CreditTransactionViewCursor? before;
  final int limit;
  final Set<CreditTransactionViewItemType>? itemTypes;
  final Set<String>? categoryAccountIds;
  final Set<String>? settlementAccountIds;
  final Set<String>? tagIds;
  final bool untaggedOnly;
  final String? counterpartyId;
}

final class CreditTransactionViewCursor {
  const CreditTransactionViewCursor({
    required this.anchorAt,
    required this.itemType,
    required this.itemId,
  });

  final DateTime anchorAt;

  /// Stable global item type code, which may belong to another source.
  final String itemType;
  final String itemId;
}

final class CreditTransactionViewAnchorCandidate {
  const CreditTransactionViewAnchorCandidate({
    required this.itemType,
    required this.itemId,
    required this.anchorTransactionId,
    required this.anchorAt,
  });

  final CreditTransactionViewItemType itemType;
  final String itemId;
  final String anchorTransactionId;
  final DateTime anchorAt;
}

final class CreditTransactionViewAnchorPage {
  CreditTransactionViewAnchorPage({
    required Iterable<CreditTransactionViewAnchorCandidate> anchors,
    required this.hasMore,
  }) : anchors = List.unmodifiable(anchors);

  final List<CreditTransactionViewAnchorCandidate> anchors;
  final bool hasMore;
}

final class CreditRepaymentBusinessActivitySummary {
  const CreditRepaymentBusinessActivitySummary({
    required this.repaymentType,
    required this.targetType,
    required this.targetId,
  });

  final RepaymentType repaymentType;
  final RepaymentTargetType targetType;
  final String targetId;
}

Set<String>? _immutableStrings(Set<String>? values) =>
    values == null ? null : Set.unmodifiable(values);

Set<CreditTransactionViewItemType>? _immutableTypes(
  Set<CreditTransactionViewItemType>? values,
) => values == null ? null : Set.unmodifiable(values);
