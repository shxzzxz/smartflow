import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../../../domain/credit/valobj/repayment_enums.dart';
import '../../../../domain/ledger/valobj/account_amount_allocation.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../../shared/business_activity/business_activity_item_key.dart';
import '../../../../shared/business_activity/business_activity_item_role.dart';
import '../../business_activity/query/business_activity_queries.dart';

/// 一笔实际交易在所属业务活动项中的局部业务投影。
///
/// 投影只表达当前交易自己的局部事实，不构成独立的业务操作边界。
class BusinessActivityItemProjection {
  const BusinessActivityItemProjection({required this.transactionId});

  final String transactionId;
}

/// 一个可独立识别的业务活动项。
///
/// 活动项拥有业务域提供的稳定身份和零到多条实际交易投影。至少有一条投影
/// 时，交易身份只能用于定位当前局部事实，不能替代活动项身份。
sealed class BusinessActivityItem {
  BusinessActivityItem({
    required this.activityKey,
    required this.itemKey,
    required this.role,
    required this.occurredAt,
    required Iterable<BusinessActivityItemProjection> projections,
  }) : projections = List.unmodifiable(projections);

  final BusinessActivityKey activityKey;
  final BusinessActivityItemKey itemKey;
  final BusinessActivityItemRole role;
  final DateTime occurredAt;
  final List<BusinessActivityItemProjection> projections;

  String get ownerType => activityKey.type;
  String get ownerId => activityKey.id;

  bool get isOrigin => role == BusinessActivityItemRole.origin;

  BusinessActivityItemProjection? projectionFor(String transactionId) {
    for (final projection in projections) {
      if (projection.transactionId == transactionId) return projection;
    }
    return null;
  }

  /// 单投影迁移期的兼容入口。新代码应通过 [projections] 访问交易身份。
  String get transactionId {
    if (projections.length != 1) {
      throw StateError(
        'BusinessActivityItem.transactionId is only available while the item '
        'has exactly one transaction projection.',
      );
    }
    return projections.single.transactionId;
  }
}

final class AdvanceBusinessActivityItem extends BusinessActivityItem {
  AdvanceBusinessActivityItem({
    required super.activityKey,
    required super.itemKey,
    required super.role,
    required super.occurredAt,
    required super.projections,
    required this.factKind,
    required this.scenario,
    required this.trackingMode,
  });

  final AdvanceTransactionFactKind factKind;
  final AdvanceScenario scenario;
  final AdvanceTrackingMode trackingMode;
}

final class InstallmentBusinessActivityItem extends BusinessActivityItem {
  InstallmentBusinessActivityItem({
    required super.activityKey,
    required super.itemKey,
    required super.role,
    required super.occurredAt,
    required super.projections,
    required this.installmentType,
    required this.factKind,
  });

  final InstallmentType installmentType;
  final InstallmentTransactionFactKind factKind;
}

final class RepaymentBusinessActivityItem extends BusinessActivityItem {
  RepaymentBusinessActivityItem({
    required super.activityKey,
    required super.itemKey,
    required super.role,
    required super.occurredAt,
    required super.projections,
    required this.repaymentId,
    required this.repaymentType,
    required this.targetType,
    required this.targetId,
  });

  final String repaymentId;
  final RepaymentType repaymentType;
  final RepaymentTargetType targetType;
  final String targetId;
}

final class AmortizationTransactionProjection
    extends BusinessActivityItemProjection {
  AmortizationTransactionProjection({
    required super.transactionId,
    required this.factKind,
    required Iterable<AccountAmountAllocation> localCategoryAllocations,
    this.occurrencePeriodSequence,
    this.occurrencePeriodDueAt,
  }) : localCategoryAllocations = List.unmodifiable(localCategoryAllocations);

  final AmortizationTransactionFactKind factKind;
  final List<AccountAmountAllocation> localCategoryAllocations;
  final int? occurrencePeriodSequence;
  final DateTime? occurrencePeriodDueAt;
}

final class AmortizationBusinessActivityItem extends BusinessActivityItem {
  AmortizationBusinessActivityItem({
    required super.activityKey,
    required super.itemKey,
    required super.role,
    required super.occurredAt,
    required super.projections,
    required this.kind,
    this.refundId,
    this.terminationId,
  });

  final AmortizationKind kind;
  final String? refundId;
  final String? terminationId;
}

final class UnknownBusinessActivityItem extends BusinessActivityItem {
  UnknownBusinessActivityItem({
    required super.activityKey,
    required super.itemKey,
    required super.occurredAt,
    required super.projections,
    super.role = BusinessActivityItemRole.followUp,
  });
}
