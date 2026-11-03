import '../../../../domain/credit/valobj/repayment_enums.dart';

/// Credit-owned business activity kinds exposed to the transaction view.
enum CreditTransactionViewActivityType {
  installment('credit.installment_contract'),
  repayment('credit.repayment');

  const CreditTransactionViewActivityType(this.code);

  final String code;
}

final class CreditTransactionViewQuery {
  CreditTransactionViewQuery({
    required this.occurredFrom,
    required this.occurredUntil,
    this.before,
    this.limit = 20,
    Set<CreditTransactionViewActivityType>? activityTypes,
    Set<String>? categoryAccountIds,
    Set<String>? settlementAccountIds,
    Set<String>? tagIds,
    this.untaggedOnly = false,
    this.counterpartyId,
  }) : activityTypes = _immutableTypes(activityTypes),
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
  final Set<CreditTransactionViewActivityType>? activityTypes;
  final Set<String>? categoryAccountIds;
  final Set<String>? settlementAccountIds;
  final Set<String>? tagIds;
  final bool untaggedOnly;
  final String? counterpartyId;
}

final class CreditTransactionViewCursor {
  const CreditTransactionViewCursor({
    required this.anchorAt,
    required this.activityType,
    required this.activityId,
  });

  final DateTime anchorAt;

  /// Stable global item type code, which may belong to another source.
  final String activityType;
  final String activityId;
}

final class CreditTransactionViewAnchorCandidate {
  const CreditTransactionViewAnchorCandidate({
    required this.activityType,
    required this.activityId,
    required this.anchorTransactionId,
    required this.anchorAt,
  });

  final CreditTransactionViewActivityType activityType;
  final String activityId;
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

Set<CreditTransactionViewActivityType>? _immutableTypes(
  Set<CreditTransactionViewActivityType>? values,
) => values == null ? null : Set.unmodifiable(values);
