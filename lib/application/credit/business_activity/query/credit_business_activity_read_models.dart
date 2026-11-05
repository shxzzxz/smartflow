import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../../../domain/credit/valobj/repayment_enums.dart';
import '../../../../shared/business_activity/business_activity_item_key.dart';
import '../../../../shared/business_activity/business_activity_item_role.dart';

/// Credit-owned business activity kinds exposed to the transaction view.
enum CreditBusinessActivityType {
  installment('credit.installment_contract'),
  repayment('credit.repayment');

  const CreditBusinessActivityType(this.code);

  final String code;
}

final class CreditBusinessActivityQuery {
  CreditBusinessActivityQuery({
    required this.occurredFrom,
    required this.occurredUntil,
    this.before,
    this.limit = 20,
    Set<CreditBusinessActivityType>? activityTypes,
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
  final CreditBusinessActivityCursor? before;
  final int limit;
  final Set<CreditBusinessActivityType>? activityTypes;
  final Set<String>? categoryAccountIds;
  final Set<String>? settlementAccountIds;
  final Set<String>? tagIds;
  final bool untaggedOnly;
  final String? counterpartyId;
}

final class CreditBusinessActivityCursor {
  const CreditBusinessActivityCursor({
    required this.anchorAt,
    required this.activityType,
    required this.activityId,
  });

  final DateTime anchorAt;

  /// Stable global item type code, which may belong to another source.
  final String activityType;
  final String activityId;
}

final class CreditBusinessActivityAnchorCandidate {
  const CreditBusinessActivityAnchorCandidate({
    required this.activityType,
    required this.activityId,
    required this.anchorTransactionId,
    required this.anchorAt,
  });

  final CreditBusinessActivityType activityType;
  final String activityId;
  final String anchorTransactionId;
  final DateTime anchorAt;
}

final class CreditBusinessActivityAnchorPage {
  CreditBusinessActivityAnchorPage({
    required Iterable<CreditBusinessActivityAnchorCandidate> anchors,
    required this.hasMore,
  }) : anchors = List.unmodifiable(anchors);

  final List<CreditBusinessActivityAnchorCandidate> anchors;
  final bool hasMore;
}

final class CreditRepaymentBusinessActivitySummary {
  const CreditRepaymentBusinessActivitySummary._({
    required this.repaymentId,
    required this.repaymentType,
    required this.targetType,
    required this.targetId,
    required this.itemKey,
    required this.activityType,
    required this.activityId,
    required this.role,
  });

  factory CreditRepaymentBusinessActivitySummary.fromRepayment({
    required String repaymentId,
    required RepaymentType repaymentType,
    required RepaymentTargetType targetType,
    required String targetId,
  }) {
    final isOrigin =
        repaymentType == RepaymentType.bill ||
        repaymentType == RepaymentType.unattributed;
    return CreditRepaymentBusinessActivitySummary._(
      repaymentId: repaymentId,
      repaymentType: repaymentType,
      targetType: targetType,
      targetId: targetId,
      itemKey: BusinessActivityItemKey(
        type: creditRepaymentOwnerType,
        id: repaymentId,
      ),
      activityType: isOrigin ? creditRepaymentOwnerType : installmentOwnerType,
      activityId: isOrigin ? repaymentId : targetId,
      role: isOrigin
          ? BusinessActivityItemRole.origin
          : BusinessActivityItemRole.followUp,
    );
  }

  final String repaymentId;
  final RepaymentType repaymentType;
  final RepaymentTargetType targetType;
  final String targetId;
  final BusinessActivityItemKey itemKey;
  final String activityType;
  final String activityId;
  final BusinessActivityItemRole role;
}

Set<String>? _immutableStrings(Set<String>? values) =>
    values == null ? null : Set.unmodifiable(values);

Set<CreditBusinessActivityType>? _immutableTypes(
  Set<CreditBusinessActivityType>? values,
) => values == null ? null : Set.unmodifiable(values);
