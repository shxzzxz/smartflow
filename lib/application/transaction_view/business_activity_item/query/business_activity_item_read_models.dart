import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../../../domain/credit/valobj/repayment_enums.dart';
import '../../../../domain/ledger/valobj/account_amount_allocation.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../../shared/business_activity/business_activity_item_role.dart';
import '../../business_activity/query/business_activity_queries.dart';

/// 一笔实际交易在所属业务活动中的业务侧投影。
///
/// 该模型只包含当前交易自身的业务含义和局部业务事实，不包含活动级余额、
/// 进度或完整业务模块信息。
sealed class BusinessActivityItem {
  const BusinessActivityItem({
    required this.activityKey,
    required this.transactionId,
    required this.role,
  });

  final BusinessActivityKey activityKey;
  final String transactionId;
  final BusinessActivityItemRole role;

  String get ownerType => activityKey.type;
  String get ownerId => activityKey.id;

  bool get isOrigin => role == BusinessActivityItemRole.origin;
}

final class AdvanceBusinessActivityItem extends BusinessActivityItem {
  const AdvanceBusinessActivityItem({
    required super.activityKey,
    required super.transactionId,
    required super.role,
    required this.factKind,
    required this.scenario,
    required this.trackingMode,
  });

  final AdvanceTransactionFactKind factKind;
  final AdvanceScenario scenario;
  final AdvanceTrackingMode trackingMode;
}

final class InstallmentBusinessActivityItem extends BusinessActivityItem {
  const InstallmentBusinessActivityItem({
    required super.activityKey,
    required super.transactionId,
    required super.role,
    required this.installmentType,
    required this.factKind,
  });

  final InstallmentType installmentType;
  final InstallmentTransactionFactKind factKind;
}

final class RepaymentBusinessActivityItem extends BusinessActivityItem {
  const RepaymentBusinessActivityItem({
    required super.activityKey,
    required super.transactionId,
    required super.role,
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

final class AmortizationBusinessActivityItem extends BusinessActivityItem {
  AmortizationBusinessActivityItem({
    required super.activityKey,
    required super.transactionId,
    required super.role,
    required this.kind,
    required this.factKind,
    required Iterable<AccountAmountAllocation> localCategoryAllocations,
    this.occurrencePeriodSequence,
    this.occurrencePeriodDueAt,
    this.refundId,
    this.terminationId,
  }) : localCategoryAllocations = List.unmodifiable(localCategoryAllocations);

  final AmortizationKind kind;
  final AmortizationTransactionFactKind factKind;
  final List<AccountAmountAllocation> localCategoryAllocations;
  final int? occurrencePeriodSequence;
  final DateTime? occurrencePeriodDueAt;
  final String? refundId;
  final String? terminationId;
}

final class UnknownBusinessActivityItem extends BusinessActivityItem {
  const UnknownBusinessActivityItem({
    required super.activityKey,
    required super.transactionId,
    super.role = BusinessActivityItemRole.followUp,
  });
}
