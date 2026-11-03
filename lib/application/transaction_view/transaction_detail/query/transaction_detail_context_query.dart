import 'dart:async';

import '../../../ledger/transaction/query/transaction_query_service.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../business_context/query/transaction_business_context_query.dart';
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
    required TransactionBusinessContextQuery businessContexts,
  }) : _transactions = transactions,
       _businessContexts = businessContexts;

  final TransactionQueryService _transactions;
  final TransactionBusinessContextQuery _businessContexts;

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
    StreamSubscription<Map<String, TransactionDetailOwnerContext>>?
    ownerSubscription;
    TransactionReadModel? latestTransaction;
    Map<String, TransactionDetailOwnerContext> latestBusinessContexts =
        const {};
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
        final context = await _assemble(
          transaction,
          businessContexts: latestBusinessContexts,
        );
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
        latestBusinessContexts = await _businessContexts.findContexts(
          context.currentGroup.transactions,
        );
        if (closed || currentRevision != revision) return;
        controller.add(context);
        ownerSubscription = _businessContexts
            .watchContexts(context.currentGroup.transactions)
            .skip(1)
            .listen((contexts) {
              latestBusinessContexts = contexts;
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
    TransactionReadModel transaction, {
    Map<String, TransactionDetailOwnerContext>? businessContexts,
  }) async {
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

    final contexts =
        businessContexts ??
        await _businessContexts.findContexts(currentGroup.transactions);
    final owner = contexts[transaction.id] ?? contexts[currentGroup.anchor.id];
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
}
