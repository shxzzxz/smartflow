import '../../../../core/money/money.dart';
import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../../../domain/credit/valobj/repayment_enums.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import 'business_item_queries.dart';

/// 业务事项列表所需的有限业务摘要。
///
/// 摘要承载业务事实，不在 application 层生成标题、图标或展示文案。
sealed class BusinessItemSummary {
  const BusinessItemSummary();
}

/// 没有额外业务进度的普通账务事项。
final class LedgerBusinessItemSummary extends BusinessItemSummary {
  const LedgerBusinessItemSummary();
}

final class AdvanceBusinessItemSummary extends BusinessItemSummary {
  const AdvanceBusinessItemSummary({
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

final class InstallmentBusinessItemSummary extends BusinessItemSummary {
  const InstallmentBusinessItemSummary({
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

final class RepaymentBusinessItemSummary extends BusinessItemSummary {
  const RepaymentBusinessItemSummary({
    required this.repaymentType,
    required this.targetType,
  });

  final RepaymentType repaymentType;
  final RepaymentTargetType targetType;
}

final class AmortizationBusinessItemSummary extends BusinessItemSummary {
  const AmortizationBusinessItemSummary({
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

/// 业务事项的统一读模型。
///
/// 锚点交易是该事项在交易列表和交易详情中的默认入口。`anchorAt` 不单独
/// 持久化，始终等于锚点交易的 `occurredAt`。
final class BusinessItemReadModel {
  BusinessItemReadModel._({
    required this.itemKey,
    required this.ownerType,
    required this.ownerId,
    required this.anchorTransaction,
    required this.summary,
  });

  factory BusinessItemReadModel.fromCandidate({
    required BusinessItemAnchorCandidate candidate,
    required TransactionReadModel anchorTransaction,
    required BusinessItemSummary summary,
  }) {
    if (anchorTransaction.parentTransactionId != null) {
      throw ArgumentError.value(
        anchorTransaction.id,
        'anchorTransaction',
        'A business item anchor must be a top-level transaction.',
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
      if (candidate.itemKey.type != ledgerTransactionGroupItemType) {
        throw ArgumentError.value(
          candidate.itemKey,
          'candidate.itemKey',
          'An ownerless business item must use the transaction-group type.',
        );
      }
    } else if (candidate.itemKey.type != ownership.ownerType ||
        candidate.itemKey.id != ownership.ownerId) {
      throw ArgumentError.value(
        candidate.itemKey,
        'candidate.itemKey',
        'The item key does not match the anchor transaction ownership.',
      );
    }

    return BusinessItemReadModel._(
      itemKey: candidate.itemKey,
      ownerType: ownership?.ownerType,
      ownerId: ownership?.ownerId,
      anchorTransaction: anchorTransaction,
      summary: summary,
    );
  }

  final BusinessItemKey itemKey;
  final String? ownerType;
  final String? ownerId;
  final TransactionReadModel anchorTransaction;
  final BusinessItemSummary summary;

  String get anchorTransactionId => anchorTransaction.id;

  DateTime get anchorAt => anchorTransaction.occurredAt;
}

/// 公共业务事项查询返回的一页结果。
final class BusinessItemPage {
  BusinessItemPage({
    required Iterable<BusinessItemReadModel> items,
    required this.hasMore,
  }) : items = List.unmodifiable(items);

  final List<BusinessItemReadModel> items;
  final bool hasMore;

  BusinessItemCursor? get nextCursor {
    if (!hasMore || items.isEmpty) return null;
    final last = items.last;
    return BusinessItemCursor(anchorAt: last.anchorAt, itemKey: last.itemKey);
  }
}
