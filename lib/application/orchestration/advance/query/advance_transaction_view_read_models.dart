import '../../../../core/money/money.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';

final class AdvanceTransactionViewQuery {
  AdvanceTransactionViewQuery({
    required this.occurredFrom,
    required this.occurredUntil,
    this.before,
    this.limit = 20,
    Set<String>? categoryAccountIds,
    Set<String>? settlementAccountIds,
    Set<String>? tagIds,
    this.untaggedOnly = false,
    this.counterpartyId,
  }) : categoryAccountIds = _immutableStrings(categoryAccountIds),
       settlementAccountIds = _immutableStrings(settlementAccountIds),
       tagIds = _immutableStrings(tagIds),
       assert(occurredUntil.isAfter(occurredFrom)),
       assert(limit > 0),
       assert(!untaggedOnly || tagIds == null);

  final DateTime occurredFrom;
  final DateTime occurredUntil;
  final AdvanceTransactionViewCursor? before;
  final int limit;
  final Set<String>? categoryAccountIds;
  final Set<String>? settlementAccountIds;
  final Set<String>? tagIds;
  final bool untaggedOnly;
  final String? counterpartyId;
}

final class AdvanceTransactionViewCursor {
  const AdvanceTransactionViewCursor({
    required this.anchorAt,
    required this.itemType,
    required this.ownerId,
  });

  final DateTime anchorAt;
  final String itemType;
  final String ownerId;
}

final class AdvanceTransactionViewAnchorCandidate {
  const AdvanceTransactionViewAnchorCandidate({
    required this.ownerId,
    required this.anchorTransactionId,
    required this.anchorAt,
  });

  final String ownerId;
  final String anchorTransactionId;
  final DateTime anchorAt;
}

final class AdvanceTransactionViewAnchorPage {
  AdvanceTransactionViewAnchorPage({
    required Iterable<AdvanceTransactionViewAnchorCandidate> anchors,
    required this.hasMore,
  }) : anchors = List.unmodifiable(anchors);

  final List<AdvanceTransactionViewAnchorCandidate> anchors;
  final bool hasMore;
}

final class AdvanceTransactionViewSummary {
  const AdvanceTransactionViewSummary({
    required this.scenario,
    required this.trackingMode,
    required this.advanceAmount,
    required this.receivedAmount,
    required this.outstanding,
    required this.isClosed,
    this.aaPeopleCount,
  });

  final AdvanceScenario scenario;
  final AdvanceTrackingMode trackingMode;
  final Money advanceAmount;
  final Money receivedAmount;
  final Money outstanding;
  final bool isClosed;
  final int? aaPeopleCount;
}

final class AdvanceTransactionViewSummarySource {
  const AdvanceTransactionViewSummarySource({
    required this.ownerId,
    required this.scenario,
    required this.trackingMode,
    required this.advanceAmount,
    required this.refundedAdvanceAmount,
    required this.receivedAmount,
    required this.isClosed,
    this.aaPeopleCount,
  });

  final String ownerId;
  final AdvanceScenario scenario;
  final AdvanceTrackingMode trackingMode;
  final Money advanceAmount;
  final Money refundedAdvanceAmount;
  final Money receivedAmount;
  final bool isClosed;
  final int? aaPeopleCount;
}

Set<String>? _immutableStrings(Set<String>? values) =>
    values == null ? null : Set.unmodifiable(values);
