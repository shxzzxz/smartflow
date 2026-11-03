import 'dart:async';

import '../../../ledger/ledger_query_api.dart';
import 'business_item_queries.dart';
import 'business_item_read_models.dart';
import 'business_item_source.dart';

/// 跨业务来源的业务事项查询用例。
///
/// 实现负责合并各来源锚点、确定全局 `hasMore`、批量加载摘要和校验锚点
/// 交易。来源查询已经完成全部筛选和游标条件，本服务不得补做业务过滤。
abstract interface class BusinessItemQueryService {
  Future<BusinessItemPage> findPage(BusinessItemPageQuery query);

  Stream<BusinessItemPage> watchPage(BusinessItemPageQuery query);
}

/// Merges bounded source pages and loads only the resulting page in batches.
final class BusinessItemQueryServiceImpl implements BusinessItemQueryService {
  BusinessItemQueryServiceImpl({
    required Iterable<BusinessItemSource> sources,
    required TransactionBatchQueryService transactionQuery,
  }) : _sources = List.unmodifiable(sources),
       _transactionQuery = transactionQuery;

  final List<BusinessItemSource> _sources;
  final TransactionBatchQueryService _transactionQuery;

  @override
  Future<BusinessItemPage> findPage(BusinessItemPageQuery query) async {
    final sources = _sourcesFor(query);
    if (sources.isEmpty) {
      return BusinessItemPage(items: const [], hasMore: false);
    }
    final pages = await Future.wait(
      sources.map((source) => source.findAnchorPage(query)),
    );
    return _assemblePage(query, sources, pages);
  }

  @override
  Stream<BusinessItemPage> watchPage(BusinessItemPageQuery query) {
    final sources = _sourcesFor(query);
    if (sources.isEmpty) {
      return Stream.value(BusinessItemPage(items: const [], hasMore: false));
    }
    final streams = sources.map((source) => source.watchAnchorPage(query));
    return _combineLatest(
      streams,
    ).asyncMap((pages) => _assemblePage(query, sources, pages));
  }

  Future<BusinessItemPage> _assemblePage(
    BusinessItemPageQuery query,
    List<BusinessItemSource> sources,
    List<BusinessItemSourcePage> pages,
  ) async {
    final merged = <_SourcedCandidate>[];
    for (var sourceIndex = 0; sourceIndex < pages.length; sourceIndex++) {
      final page = pages[sourceIndex];
      if (page.anchors.length > query.limit + 1) {
        throw StateError(
          'Source ${sources[sourceIndex].sourceKey} returned more than '
          'limit + 1 anchors.',
        );
      }
      if (page.hasMore != (page.anchors.length > query.limit)) {
        throw StateError(
          'Source ${sources[sourceIndex].sourceKey} returned an inconsistent '
          'hasMore flag.',
        );
      }
      merged.addAll([
        for (final candidate in page.anchors)
          _SourcedCandidate(sourceIndex: sourceIndex, candidate: candidate),
      ]);
    }
    merged.sort(_compareCandidates);

    final unique = <_SourcedCandidate>[];
    final seenKeys = <BusinessItemKey>{};
    for (final candidate in merged) {
      if (seenKeys.add(candidate.candidate.itemKey)) {
        unique.add(candidate);
      }
    }
    final hasMore = unique.length > query.limit;
    final selected = hasMore ? unique.take(query.limit).toList() : unique;
    if (selected.isEmpty) {
      return BusinessItemPage(items: const [], hasMore: false);
    }

    final anchorsBySource = <int, List<BusinessItemAnchorCandidate>>{};
    for (final candidate in selected) {
      anchorsBySource
          .putIfAbsent(candidate.sourceIndex, () => [])
          .add(candidate.candidate);
    }
    final transactionFuture = _transactionQuery.findTransactionsByIds({
      for (final candidate in selected) candidate.candidate.anchorTransactionId,
    });
    final summaryFutures = [
      for (var sourceIndex = 0; sourceIndex < sources.length; sourceIndex++)
        if (anchorsBySource[sourceIndex] case final anchors?)
          sources[sourceIndex].findSummaries(anchors)
        else
          Future.value(const <BusinessItemKey, BusinessItemSummary>{}),
    ];
    final summariesFuture = Future.wait(summaryFutures);
    final transactions = await transactionFuture;
    final transactionsById = {
      for (final transaction in transactions) transaction.id: transaction,
    };
    final summariesBySource = await summariesFuture;

    return BusinessItemPage(
      hasMore: hasMore,
      items: [
        for (final sourced in selected)
          _buildReadModel(
            sourced,
            summariesBySource[sourced.sourceIndex],
            transactionsById,
          ),
      ],
    );
  }

  BusinessItemReadModel _buildReadModel(
    _SourcedCandidate sourced,
    Map<BusinessItemKey, BusinessItemSummary> summaries,
    Map<String, TransactionReadModel> transactionsById,
  ) {
    final candidate = sourced.candidate;
    final transaction = transactionsById[candidate.anchorTransactionId];
    if (transaction == null) {
      throw StateError(
        'Anchor transaction ${candidate.anchorTransactionId} was not found.',
      );
    }
    final summary = summaries[candidate.itemKey];
    if (summary == null) {
      throw StateError(
        'Summary for business item ${candidate.itemKey.type}:'
        '${candidate.itemKey.id} was not found.',
      );
    }
    return BusinessItemReadModel.fromCandidate(
      candidate: candidate,
      anchorTransaction: transaction,
      summary: summary,
    );
  }

  int _compareCandidates(_SourcedCandidate left, _SourcedCandidate right) {
    final byTime = right.candidate.anchorAt.compareTo(left.candidate.anchorAt);
    if (byTime != 0) return byTime;
    return right.candidate.itemKey.compareTo(left.candidate.itemKey);
  }

  List<BusinessItemSource> _sourcesFor(BusinessItemPageQuery query) {
    final itemTypes = query.itemTypes;
    if (itemTypes == null) return _sources;
    return List.unmodifiable(
      _sources.where(
        (source) => source.supportedItemTypes.any(itemTypes.contains),
      ),
    );
  }
}

final class _SourcedCandidate {
  const _SourcedCandidate({required this.sourceIndex, required this.candidate});

  final int sourceIndex;
  final BusinessItemAnchorCandidate candidate;
}

Stream<List<T>> _combineLatest<T>(Iterable<Stream<T>> streams) {
  final values = List<Stream<T>>.unmodifiable(streams);
  if (values.isEmpty) {
    return Stream.value(const []);
  }
  return Stream.multi((controller) {
    final latest = List<T?>.filled(values.length, null);
    final subscriptions = List<StreamSubscription<T>?>.filled(
      values.length,
      null,
    );
    var cancelled = false;

    Future<void> cancelAll() async {
      for (final subscription in subscriptions) {
        await subscription?.cancel();
      }
    }

    for (var index = 0; index < values.length; index++) {
      subscriptions[index] = values[index].listen(
        (value) {
          if (cancelled) return;
          latest[index] = value;
          if (latest.every((value) => value != null)) {
            controller.add(List<T>.unmodifiable(latest.cast<T>()));
          }
        },
        onError: controller.addError,
        onDone: () {
          if (cancelled) return;
          cancelled = true;
          unawaited(cancelAll());
          controller.close();
        },
        cancelOnError: true,
      );
    }

    controller.onCancel = () {
      cancelled = true;
      return cancelAll();
    };
  });
}
