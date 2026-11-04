import '../../../../domain/ledger/valobj/ledger_enum.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../ledger/transaction/query/transaction_query_service.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../../orchestration/amortization/query/amortization_plan_query_service.dart';
import '../../business_activity_item/query/business_activity_item_query.dart';
import '../../transaction_view_query_streams.dart';
import 'transaction_detail_context_read_models.dart';

/// Loads the local transaction detail and only the activity facts required by
/// the concrete transaction.
abstract interface class TransactionDetailContextQuery {
  Future<TransactionDetailContext?> findById(String transactionId);

  Stream<TransactionDetailContext?> watchById(String transactionId);
}

final class TransactionDetailContextQueryImpl
    implements TransactionDetailContextQuery {
  TransactionDetailContextQueryImpl({
    required TransactionQueryService transactions,
    required BusinessActivityItemQuery businessItems,
    AmortizationPlanQueryService? amortizationPlans,
  }) : _transactions = transactions,
       _businessItems = businessItems,
       _amortizationPlans = amortizationPlans;

  final TransactionQueryService _transactions;
  final BusinessActivityItemQuery _businessItems;
  final AmortizationPlanQueryService? _amortizationPlans;

  @override
  Future<TransactionDetailContext?> findById(String transactionId) async {
    final transaction = await _transactions.findTransactionDetail(
      transactionId,
    );
    if (transaction == null) return null;
    final businessItems = await _businessItems.findItems([transaction]);
    return _assemble(transaction, businessItems: businessItems);
  }

  @override
  Stream<TransactionDetailContext?> watchById(String transactionId) {
    return switchMapStreams(
      _transactions.watchTransactionDetail(transactionId),
      (transaction) {
        if (transaction == null) return Stream.value(null);
        return _watchTransaction(transaction);
      },
    );
  }

  Stream<TransactionDetailContext> _watchTransaction(
    TransactionReadModel transaction,
  ) async* {
    final businessItems = await _businessItems.findItems([transaction]);
    yield await _assemble(transaction, businessItems: businessItems);

    final item = businessItems[transaction.id];
    final streams = <Stream<Object?>>[
      _businessItems.watchItems([transaction]).map<Object?>((items) => items),
      if (item is AmortizationBusinessActivityItem &&
          _amortizationPlans != null)
        _amortizationPlans
            .watchByIds({item.ownerId})
            .map<Object?>(
              (plans) =>
                  plans
                      .where((plan) => plan.id == item.ownerId)
                      .firstOrNull
                      ?.status ==
                  AmortizationStatus.terminated,
            ),
    ];
    if (streams.isEmpty) return;

    await for (final values in combineLatestStreams(streams).skip(1)) {
      final latestItems = values.first as Map<String, BusinessActivityItem>;
      final isTerminated = values.length > 1
          ? values.last as bool
          : await _loadAmortizationTermination(latestItems[transaction.id]);
      yield await _assemble(
        transaction,
        businessItems: latestItems,
        amortizationTerminated: isTerminated,
      );
    }
  }

  Future<TransactionDetailContext> _assemble(
    TransactionReadModel transaction, {
    Map<String, BusinessActivityItem>? businessItems,
    bool? amortizationTerminated,
  }) async {
    final items =
        businessItems ?? await _businessItems.findItems([transaction]);
    final businessItem = items[transaction.id];
    return TransactionDetailContext(
      transaction: transaction,
      parentFacts: await _loadParentFacts(transaction),
      businessItem: businessItem,
      isAmortizationTerminated:
          amortizationTerminated ??
          await _loadAmortizationTermination(businessItem),
    );
  }

  Future<bool> _loadAmortizationTermination(BusinessActivityItem? item) async {
    if (item is! AmortizationBusinessActivityItem ||
        _amortizationPlans == null) {
      return false;
    }
    final plans = await _amortizationPlans.findByIds({item.ownerId});
    return plans.where((plan) => plan.id == item.ownerId).firstOrNull?.status ==
        AmortizationStatus.terminated;
  }

  Future<TransactionParentFacts?> _loadParentFacts(
    TransactionReadModel transaction,
  ) async {
    final parentId = transaction.parentTransactionId;
    if (parentId == null) return null;
    final parent = await _transactions.findTransactionById(parentId);
    if (parent == null) return null;
    final isAdvanceClosed = parent.businessPurpose == BusinessPurpose.advance
        ? await _transactions.hasChildTransaction(
            parentTransactionId: parentId,
            businessPurpose: BusinessPurpose.advanceSettlement,
          )
        : false;
    return TransactionParentFacts(
      isExcludedFromStats: parent.isExcludedFromStats,
      isExcludedFromBudget: parent.isExcludedFromBudget,
      isAdvanceClosed: isAdvanceClosed,
    );
  }
}
