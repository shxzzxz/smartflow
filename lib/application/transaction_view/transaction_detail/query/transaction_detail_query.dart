import 'dart:async';

import '../../business_activity/query/business_activity_query_service.dart';
import '../../business_activity/query/business_activity_read_models.dart';
import '../../transaction_view_query_streams.dart';
import 'transaction_detail_context_query.dart';
import 'transaction_detail_context_read_models.dart';

/// Loads local transaction facts and the activity module only when the current
/// transaction is an activity entry.
abstract interface class TransactionDetailQuery {
  Future<TransactionDetailReadModel?> findById(String transactionId);

  Stream<TransactionDetailReadModel?> watchById(String transactionId);
}

final class TransactionDetailQueryImpl implements TransactionDetailQuery {
  const TransactionDetailQueryImpl({
    required TransactionDetailContextQuery localContext,
    required BusinessActivityQueryService businessActivities,
  }) : _localContext = localContext,
       _businessActivities = businessActivities;

  final TransactionDetailContextQuery _localContext;
  final BusinessActivityQueryService _businessActivities;

  @override
  Future<TransactionDetailReadModel?> findById(String transactionId) async {
    final context = await _localContext.findById(transactionId);
    if (context == null) return null;
    return TransactionDetailReadModel(
      context: context,
      businessActivity: await _findActivity(context),
    );
  }

  @override
  Stream<TransactionDetailReadModel?> watchById(String transactionId) {
    return switchMapStreams(_localContext.watchById(transactionId), (context) {
      if (context == null) return Stream.value(null);
      return _watchActivity(context);
    });
  }

  Stream<TransactionDetailReadModel> _watchActivity(
    TransactionDetailContext context,
  ) async* {
    final activity = await _findActivity(context);
    yield TransactionDetailReadModel(
      context: context,
      businessActivity: activity,
    );
    if (activity == null) return;

    await for (final values
        in _businessActivities.watchContents([activity]).skip(1)) {
      yield TransactionDetailReadModel(
        context: context,
        businessActivity: values[activity.activityKey],
      );
    }
  }

  Future<BusinessActivityReadModel?> _findActivity(
    TransactionDetailContext context,
  ) {
    final item = context.businessItem;
    if (!_requiresBusinessActivity(item)) return Future.value(null);
    return _businessActivities.findForActivity(
      activityKey: item!.activityKey,
      activityAt: context.transaction.occurredAt,
      displayTransaction: context.transaction,
    );
  }

  bool _requiresBusinessActivity(BusinessActivityItem? item) {
    return item != null &&
        item is! UnknownBusinessActivityItem &&
        item.isOrigin;
  }
}
