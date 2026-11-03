import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../source/transaction_business_context_source.dart';
import 'business_context_stream.dart';
import 'transaction_business_context_read_models.dart';

abstract interface class TransactionBusinessContextQuery {
  Future<Map<String, TransactionBusinessContext>> findContexts(
    Iterable<TransactionReadModel> transactions,
  );

  Stream<Map<String, TransactionBusinessContext>> watchContexts(
    Iterable<TransactionReadModel> transactions,
  );
}

final class TransactionBusinessContextQueryImpl
    implements TransactionBusinessContextQuery {
  TransactionBusinessContextQueryImpl({
    required Iterable<TransactionBusinessContextSource> sources,
  }) : _sources = List.unmodifiable(sources);

  final List<TransactionBusinessContextSource> _sources;

  @override
  Future<Map<String, TransactionBusinessContext>> findContexts(
    Iterable<TransactionReadModel> transactions,
  ) async {
    final values = transactions.toList();
    final groups = _groupBySource(values);
    final loaded = await Future.wait([
      for (final entry in groups.entries) entry.key.findContexts(entry.value),
    ]);
    return _complete(values, loaded);
  }

  @override
  Stream<Map<String, TransactionBusinessContext>> watchContexts(
    Iterable<TransactionReadModel> transactions,
  ) {
    final values = transactions.toList();
    final groups = _groupBySource(values);
    if (groups.isEmpty) {
      return Stream.value(_complete(values, const []));
    }
    return combineLatestStreams([
      for (final entry in groups.entries) entry.key.watchContexts(entry.value),
    ]).map((loaded) => _complete(values, loaded));
  }

  Map<TransactionBusinessContextSource, List<TransactionReadModel>>
  _groupBySource(List<TransactionReadModel> transactions) {
    final groups =
        <TransactionBusinessContextSource, List<TransactionReadModel>>{};
    for (final transaction in transactions) {
      final ownership = transaction.ownership;
      if (ownership == null) continue;
      final source = _sourceFor(ownership.ownerType);
      if (source == null) continue;
      groups.putIfAbsent(source, () => []).add(transaction);
    }
    return groups;
  }

  Map<String, TransactionBusinessContext> _complete(
    List<TransactionReadModel> transactions,
    Iterable<Map<String, TransactionBusinessContext>> loaded,
  ) {
    final contexts = {for (final values in loaded) ...values};
    for (final transaction in transactions) {
      final ownership = transaction.ownership;
      if (ownership == null || contexts.containsKey(transaction.id)) continue;
      contexts[transaction.id] = UnknownTransactionBusinessContext(
        ownerType: ownership.ownerType,
        ownerId: ownership.ownerId,
      );
    }
    return contexts;
  }

  TransactionBusinessContextSource? _sourceFor(String ownerType) {
    for (final source in _sources) {
      if (source.supportedOwnerTypes.contains(ownerType)) return source;
    }
    return null;
  }
}
