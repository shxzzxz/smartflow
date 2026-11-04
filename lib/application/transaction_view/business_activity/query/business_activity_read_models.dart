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
    required this.completedPeriodCount,
    required this.totalPeriodCount,
  }) : assert(completedPeriodCount >= 0),
       assert(totalPeriodCount >= 0);

  final InstallmentType installmentType;
  final InstallmentContractStatus status;
  final Money principal;
  final Money remainingPrincipal;
  final int completedPeriodCount;
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
/// 展示交易是可选的列表投影，不是活动身份、业务时间或详情入口的前提。
/// [activityAt] 由来源显式给出，不能从展示交易隐式推导。
final class BusinessActivityReadModel {
  BusinessActivityReadModel._({
    required this.activityKey,
    required this.activityAt,
    required this.displayTransaction,
    required this.summary,
  });

  factory BusinessActivityReadModel.fromCandidate({
    required BusinessActivityCandidate candidate,
    TransactionReadModel? displayTransaction,
    required BusinessActivitySummary summary,
  }) {
    final displayTransactionId = candidate.displayTransactionId;
    if ((displayTransactionId == null) != (displayTransaction == null) ||
        (displayTransactionId != null &&
            displayTransaction!.id != displayTransactionId)) {
      throw ArgumentError.value(
        displayTransaction?.id,
        'displayTransaction',
        'The loaded transaction does not match the candidate display '
            'transaction.',
      );
    }

    return BusinessActivityReadModel._(
      activityKey: candidate.activityKey,
      activityAt: candidate.activityAt,
      displayTransaction: displayTransaction,
      summary: summary,
    );
  }

  final BusinessActivityKey activityKey;
  final DateTime activityAt;
  final TransactionReadModel? displayTransaction;
  final BusinessActivitySummary summary;

  String? get displayTransactionId => displayTransaction?.id;
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
      activityAt: last.activityAt,
      activityKey: last.activityKey,
    );
  }
}
