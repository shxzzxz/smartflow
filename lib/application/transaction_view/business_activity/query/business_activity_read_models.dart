import '../../../../core/money/money.dart';
import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../../../domain/credit/valobj/repayment_enums.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import 'business_activity_queries.dart';

/// 业务活动列表所需的有限业务摘要。
///
/// 摘要承载业务事实，不在 application 层生成标题、图标或展示文案。
sealed class BusinessActivitySummary {
  const BusinessActivitySummary();
}

/// 没有额外业务进度的普通账务事项。
final class LedgerBusinessActivitySummary extends BusinessActivitySummary {
  const LedgerBusinessActivitySummary();
}

final class AdvanceBusinessActivitySummary extends BusinessActivitySummary {
  const AdvanceBusinessActivitySummary({
    required this.scenario,
    required this.trackingMode,
    required this.outstanding,
    required this.isClosed,
    this.aaPeopleCount,
  });

  final AdvanceScenario scenario;
  final AdvanceTrackingMode trackingMode;
  final Money outstanding;
  final bool isClosed;
  final int? aaPeopleCount;
}

final class InstallmentBusinessActivitySummary extends BusinessActivitySummary {
  const InstallmentBusinessActivitySummary({
    required this.installmentType,
    required this.status,
    required this.principal,
    required this.remainingPrincipal,
    required this.paidPeriodCount,
    required this.totalPeriodCount,
  }) : assert(paidPeriodCount >= 0),
       assert(totalPeriodCount >= 0);

  final InstallmentType installmentType;
  final InstallmentContractStatus status;
  final Money principal;
  final Money remainingPrincipal;
  final int paidPeriodCount;
  final int totalPeriodCount;
}

final class RepaymentBusinessActivitySummary extends BusinessActivitySummary {
  const RepaymentBusinessActivitySummary({
    required this.repaymentType,
    required this.targetType,
  });

  final RepaymentType repaymentType;
  final RepaymentTargetType targetType;
}

final class AmortizationBusinessActivitySummary
    extends BusinessActivitySummary {
  const AmortizationBusinessActivitySummary({
    required this.kind,
    required this.status,
    required this.originalAmount,
    required this.recognizedAmount,
    required this.remainingAmount,
    required this.postedPeriodCount,
    required this.totalPeriodCount,
    this.categoryAccountIds = const [],
    this.currentPeriodSequence,
    this.currentPeriodDueAt,
    this.currentPeriodAmount,
  }) : assert(postedPeriodCount >= 0),
       assert(totalPeriodCount >= 0);

  final AmortizationKind kind;
  final AmortizationStatus status;
  final Money originalAmount;
  final Money recognizedAmount;
  final Money remainingAmount;
  final int postedPeriodCount;
  final int totalPeriodCount;
  final List<String> categoryAccountIds;
  final int? currentPeriodSequence;
  final DateTime? currentPeriodDueAt;
  final Money? currentPeriodAmount;
}

/// 业务活动的统一读模型。
///
/// 锚点交易是该事项在交易列表和交易详情中的默认入口。`anchorAt` 不单独
/// 持久化，始终等于锚点交易的 `occurredAt`。
final class BusinessActivityReadModel {
  BusinessActivityReadModel._({
    required this.activityKey,
    required this.ownerType,
    required this.ownerId,
    required this.anchorTransaction,
    required this.summary,
  });

  factory BusinessActivityReadModel.fromCandidate({
    required BusinessActivityAnchorCandidate candidate,
    required TransactionReadModel anchorTransaction,
    required BusinessActivitySummary summary,
  }) {
    if (anchorTransaction.parentTransactionId != null) {
      throw ArgumentError.value(
        anchorTransaction.id,
        'anchorTransaction',
        'A business activity anchor must be a top-level transaction.',
      );
    }
    if (anchorTransaction.id != candidate.anchorTransactionId) {
      throw ArgumentError.value(
        candidate.anchorTransactionId,
        'candidate.anchorTransactionId',
        'The loaded transaction does not match the anchor candidate.',
      );
    }
    if (anchorTransaction.occurredAt != candidate.anchorAt) {
      throw ArgumentError.value(
        candidate.anchorAt,
        'candidate.anchorAt',
        'anchorAt must equal the anchor transaction occurredAt.',
      );
    }

    final ownership = anchorTransaction.ownership;
    if (ownership == null) {
      if (candidate.activityKey.type != ledgerTransactionGroupActivityType) {
        throw ArgumentError.value(
          candidate.activityKey,
          'candidate.activityKey',
          'An ownerless business activity must use the transaction-group type.',
        );
      }
    } else if (candidate.activityKey.type != ownership.ownerType ||
        candidate.activityKey.id != ownership.ownerId) {
      throw ArgumentError.value(
        candidate.activityKey,
        'candidate.activityKey',
        'The item key does not match the anchor transaction ownership.',
      );
    }

    return BusinessActivityReadModel._(
      activityKey: candidate.activityKey,
      ownerType: ownership?.ownerType,
      ownerId: ownership?.ownerId,
      anchorTransaction: anchorTransaction,
      summary: summary,
    );
  }

  final BusinessActivityKey activityKey;
  final String? ownerType;
  final String? ownerId;
  final TransactionReadModel anchorTransaction;
  final BusinessActivitySummary summary;

  String get anchorTransactionId => anchorTransaction.id;

  DateTime get anchorAt => anchorTransaction.occurredAt;
}

/// 公共业务活动查询返回的一页结果。
final class BusinessActivityPage {
  BusinessActivityPage({
    required Iterable<BusinessActivityReadModel> items,
    required this.hasMore,
  }) : items = List.unmodifiable(items);

  final List<BusinessActivityReadModel> items;
  final bool hasMore;

  BusinessActivityCursor? get nextCursor {
    if (!hasMore || items.isEmpty) return null;
    final last = items.last;
    return BusinessActivityCursor(
      anchorAt: last.anchorAt,
      activityKey: last.activityKey,
    );
  }
}
