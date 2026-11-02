import 'dart:async';

import '../../../../domain/ledger/valobj/transaction_ownership.dart';
import '../../../ledger/transaction/query/transaction_query_service.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import 'port/transaction_detail_owner_query.dart';
import 'transaction_detail_context_read_models.dart';

/// Loads all ledger and owner facts needed to compose a transaction detail.
///
/// Feature code observes this query only. It must not reconstruct business
/// state by combining owner-specific query providers.
abstract interface class TransactionDetailContextQuery {
  Future<TransactionDetailContext?> findById(String transactionId);

  Stream<TransactionDetailContext?> watchById(String transactionId);
}

final class TransactionDetailContextQueryImpl
    implements TransactionDetailContextQuery {
  TransactionDetailContextQueryImpl({
    required TransactionQueryService transactions,
    required Iterable<TransactionDetailOwnerQuery> ownerQueries,
  }) : _transactions = transactions,
       _ownerQueries = List.unmodifiable(ownerQueries);

  final TransactionQueryService _transactions;
  final List<TransactionDetailOwnerQuery> _ownerQueries;

  @override
  Future<TransactionDetailContext?> findById(String transactionId) async {
    final transaction = await _transactions.findTransactionDetail(
      transactionId,
    );
    return transaction == null ? null : _assemble(transaction);
  }

  @override
  Stream<TransactionDetailContext?> watchById(String transactionId) {
    late StreamController<TransactionDetailContext?> controller;
    StreamSubscription<TransactionReadModel?>? transactionSubscription;
    StreamSubscription<TransactionDetailOwnerContext?>? ownerSubscription;
    TransactionReadModel? latestTransaction;
    var revision = 0;
    var ownerRevision = 0;
    var closed = false;

    Future<void> cancelOwner() async {
      await ownerSubscription?.cancel();
      ownerSubscription = null;
    }

    Future<void> handleOwnerChange(
      int transactionRevision,
      int currentOwnerRevision,
    ) async {
      if (closed ||
          transactionRevision != revision ||
          currentOwnerRevision != ownerRevision) {
        return;
      }
      final transaction = latestTransaction;
      if (transaction == null) return;
      try {
        final context = await _assemble(transaction);
        if (!closed &&
            transactionRevision == revision &&
            currentOwnerRevision == ownerRevision) {
          controller.add(context);
        }
      } catch (error, stackTrace) {
        if (!closed &&
            transactionRevision == revision &&
            currentOwnerRevision == ownerRevision) {
          controller.addError(error, stackTrace);
        }
      }
    }

    Future<void> handleTransaction(TransactionReadModel? transaction) async {
      final currentRevision = ++revision;
      latestTransaction = transaction;
      await cancelOwner();
      if (closed) return;
      if (transaction == null) {
        controller.add(null);
        return;
      }
      try {
        final context = await _assemble(transaction);
        if (closed || currentRevision != revision) return;
        controller.add(context);
        final ownership =
            context.transaction.ownership ??
            context.currentGroup.anchor.ownership;
        if (ownership == null) return;
        final ownerQuery = _ownerQueryFor(ownership.ownerType);
        if (ownerQuery == null) return;
        ownerSubscription = ownerQuery.watch(ownership).skip(1).listen((_) {
          final requestRevision = ++ownerRevision;
          unawaited(handleOwnerChange(currentRevision, requestRevision));
        }, onError: controller.addError);
      } catch (error, stackTrace) {
        if (!closed && currentRevision == revision) {
          controller.addError(error, stackTrace);
        }
      }
    }

    controller = StreamController<TransactionDetailContext?>(
      onListen: () {
        transactionSubscription = _transactions
            .watchTransactionDetail(transactionId)
            .listen(
              (transaction) => unawaited(handleTransaction(transaction)),
              onError: controller.addError,
              onDone: () async {
                closed = true;
                await cancelOwner();
                await controller.close();
              },
            );
      },
      onCancel: () async {
        closed = true;
        await transactionSubscription?.cancel();
        await cancelOwner();
      },
    );
    return controller.stream;
  }

  Future<TransactionDetailContext> _assemble(
    TransactionReadModel transaction,
  ) async {
    final parent = transaction.parentTransactionId == null
        ? null
        : await _transactions.findTransactionDetail(
            transaction.parentTransactionId!,
          );
    final currentGroup = parent == null
        ? TransactionDetailGroup(
            anchor: transaction,
            children: transaction.children,
          )
        : TransactionDetailGroup(anchor: parent, children: parent.children);

    final ownership = transaction.ownership ?? currentGroup.anchor.ownership;
    final owner = await _loadOwner(ownership);
    final anchorId = switch (owner) {
      AmortizationTransactionDetailOwnerContext(:final initialTransactionId) =>
        initialTransactionId,
      _ => currentGroup.anchor.id,
    };
    final anchorGroup = anchorId == currentGroup.anchor.id
        ? currentGroup
        : await _loadAnchorGroup(anchorId);
    return TransactionDetailContext(
      transaction: transaction,
      parentTransaction: parent,
      currentGroup: currentGroup,
      anchorGroup: anchorGroup,
      owner: owner,
    );
  }

  Future<TransactionDetailGroup> _loadAnchorGroup(String anchorId) async {
    final anchor = await _transactions.findTransactionDetail(anchorId);
    if (anchor == null) {
      throw StateError(
        'Transaction detail anchor $anchorId could not be loaded.',
      );
    }
    if (anchor.parentTransactionId != null) {
      throw StateError(
        'Transaction detail anchor $anchorId is not a top-level transaction.',
      );
    }
    return TransactionDetailGroup(anchor: anchor, children: anchor.children);
  }

  Future<TransactionDetailOwnerContext?> _loadOwner(
    TransactionOwnership? ownership,
  ) async {
    if (ownership == null) return null;
    final query = _ownerQueryFor(ownership.ownerType);
    final loaded = query == null ? null : await query.find(ownership);
    return loaded ??
        UnknownTransactionDetailOwnerContext(
          ownerType: ownership.ownerType,
          ownerId: ownership.ownerId,
        );
  }

  TransactionDetailOwnerQuery? _ownerQueryFor(String ownerType) {
    for (final query in _ownerQueries) {
      if (query.supportedOwnerTypes.contains(ownerType)) return query;
    }
    return null;
  }
}
