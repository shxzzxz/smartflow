import '../../../ledger/ledger_query_api.dart';
import '../../transaction_view_query_streams.dart';
import 'business_activity_queries.dart';
import 'business_activity_read_models.dart';
import 'business_activity_source.dart';

/// 跨业务来源的业务活动查询用例。
///
/// 实现负责合并各来源候选、确定全局 `hasMore`、批量加载摘要和可选的展示
/// 交易。来源查询已经完成全部筛选和游标条件，本服务不得补做业务过滤。
abstract interface class BusinessActivityQueryService {
  Future<BusinessActivityPage> findPage(BusinessActivityPageQuery query);

  Stream<BusinessActivityPage> watchPage(BusinessActivityPageQuery query);

  Future<BusinessActivityReadModel?> findForActivity({
    required BusinessActivityKey activityKey,
    required DateTime activityAt,
    TransactionReadModel? displayTransaction,
  });

  /// Refreshes the content of existing members without discovering new ones.
  Stream<Map<BusinessActivityKey, BusinessActivityReadModel>> watchContents(
    Iterable<BusinessActivityReadModel> currentActivities,
  );
}

/// Merges bounded source pages and loads only the resulting page in batches.
final class BusinessActivityQueryServiceImpl
    implements BusinessActivityQueryService {
  BusinessActivityQueryServiceImpl({
    required Iterable<BusinessActivitySource> sources,
    required TransactionBatchQueryService transactionQuery,
  }) : _sources = List.unmodifiable(sources),
       _transactionQuery = transactionQuery;

  final List<BusinessActivitySource> _sources;
  final TransactionBatchQueryService _transactionQuery;

  @override
  Future<BusinessActivityPage> findPage(BusinessActivityPageQuery query) async {
    final sources = _sourcesFor(query);
    if (sources.isEmpty) {
      return BusinessActivityPage(items: const [], hasMore: false);
    }
    final pages = await Future.wait(
      sources.map((source) => source.findCandidatePage(query)),
    );
    return _assemblePage(query, sources, pages);
  }

  @override
  Stream<BusinessActivityPage> watchPage(BusinessActivityPageQuery query) {
    final sources = _sourcesFor(query);
    if (sources.isEmpty) {
      return Stream.value(
        BusinessActivityPage(items: const [], hasMore: false),
      );
    }
    final streams = sources.map((source) => source.watchCandidatePage(query));
    return combineLatestStreams(
      streams,
    ).asyncMap((pages) => _assemblePage(query, sources, pages));
  }

  @override
  Stream<Map<BusinessActivityKey, BusinessActivityReadModel>> watchContents(
    Iterable<BusinessActivityReadModel> currentActivities,
  ) {
    final activities = currentActivities.toList(growable: false);
    if (activities.isEmpty) return Stream.value(const {});

    final activitiesBySource =
        <BusinessActivitySource, List<BusinessActivityReadModel>>{};
    for (final activity in activities) {
      final source = _sourceForType(activity.activityKey.type);
      if (source == null) continue;
      activitiesBySource.putIfAbsent(source, () => []).add(activity);
    }
    if (activitiesBySource.isEmpty) return Stream.value(const {});

    final sourceEntries = activitiesBySource.entries.toList(growable: false);
    final summaryStreams = <Stream<Object?>>[
      for (final entry in sourceEntries)
        entry.key
            .watchSummaries(entry.value.map(_candidateForActivity))
            .map<Object?>((summaries) => summaries),
    ];
    final transactionIds = {
      for (final activity in activities) ?activity.displayTransactionId,
    };
    final transactionStream = transactionIds.isEmpty
        ? Stream<Object?>.value(const <TransactionReadModel>[])
        : _transactionQuery
              .watchTransactionsByIds(transactionIds)
              .map<Object?>((transactions) => transactions);

    return combineLatestStreams<Object?>([
      ...summaryStreams,
      transactionStream,
    ]).map((values) {
      final summaries = <BusinessActivityKey, BusinessActivitySummary>{};
      for (var index = 0; index < sourceEntries.length; index++) {
        final sourceSummaries =
            values[index] as Map<BusinessActivityKey, BusinessActivitySummary>;
        summaries.addAll(sourceSummaries);
      }
      final transactions = values.last as List<TransactionReadModel>;
      final transactionsById = {
        for (final transaction in transactions) transaction.id: transaction,
      };
      final updated = <BusinessActivityKey, BusinessActivityReadModel>{};
      for (final activity in activities) {
        final summary = summaries[activity.activityKey];
        final displayTransactionId = activity.displayTransactionId;
        final transaction = displayTransactionId == null
            ? null
            : transactionsById[displayTransactionId];
        if (summary == null ||
            (displayTransactionId != null && transaction == null)) {
          continue;
        }
        updated[activity.activityKey] = BusinessActivityReadModel.fromCandidate(
          candidate: _candidateForActivity(activity),
          displayTransaction: transaction,
          summary: summary,
        );
      }
      return updated;
    });
  }

  Future<BusinessActivityPage> _assemblePage(
    BusinessActivityPageQuery query,
    List<BusinessActivitySource> sources,
    List<BusinessActivitySourcePage> pages,
  ) async {
    final merged = <_SourcedCandidate>[];
    for (var sourceIndex = 0; sourceIndex < pages.length; sourceIndex++) {
      final page = pages[sourceIndex];
      if (page.candidates.length > query.limit + 1) {
        throw StateError(
          'Source ${sources[sourceIndex].sourceKey} returned more than '
          'limit + 1 candidates.',
        );
      }
      if (page.hasMore != (page.candidates.length > query.limit)) {
        throw StateError(
          'Source ${sources[sourceIndex].sourceKey} returned an inconsistent '
          'hasMore flag.',
        );
      }
      merged.addAll([
        for (final candidate in page.candidates)
          _SourcedCandidate(sourceIndex: sourceIndex, candidate: candidate),
      ]);
    }
    merged.sort(_compareCandidates);

    final unique = <_SourcedCandidate>[];
    final seenKeys = <BusinessActivityKey>{};
    for (final candidate in merged) {
      if (seenKeys.add(candidate.candidate.activityKey)) {
        unique.add(candidate);
      }
    }
    final hasMore = unique.length > query.limit;
    final selected = hasMore ? unique.take(query.limit).toList() : unique;
    if (selected.isEmpty) {
      return BusinessActivityPage(items: const [], hasMore: false);
    }

    final candidatesBySource = <int, List<BusinessActivityCandidate>>{};
    for (final candidate in selected) {
      candidatesBySource
          .putIfAbsent(candidate.sourceIndex, () => [])
          .add(candidate.candidate);
    }
    final displayTransactionIds = {
      for (final candidate in selected)
        ?candidate.candidate.displayTransactionId,
    };
    final transactionFuture = displayTransactionIds.isEmpty
        ? Future<List<TransactionReadModel>>.value(const [])
        : _transactionQuery.findTransactionsByIds(displayTransactionIds);
    final summaryFutures = [
      for (var sourceIndex = 0; sourceIndex < sources.length; sourceIndex++)
        if (candidatesBySource[sourceIndex] case final candidates?)
          sources[sourceIndex].findSummaries(candidates)
        else
          Future.value(const <BusinessActivityKey, BusinessActivitySummary>{}),
    ];
    final summariesFuture = Future.wait(summaryFutures);
    final transactions = await transactionFuture;
    final transactionsById = {
      for (final transaction in transactions) transaction.id: transaction,
    };
    final summariesBySource = await summariesFuture;

    return BusinessActivityPage(
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

  @override
  Future<BusinessActivityReadModel?> findForActivity({
    required BusinessActivityKey activityKey,
    required DateTime activityAt,
    TransactionReadModel? displayTransaction,
  }) async {
    final source = _sourceForType(activityKey.type);
    if (source == null) return null;
    final candidate = BusinessActivityCandidate(
      activityKey: activityKey,
      activityAt: activityAt,
      displayTransactionId: displayTransaction?.id,
    );
    final summaries = await source.findSummaries([candidate]);
    final summary = summaries[activityKey];
    if (summary == null) return null;
    return BusinessActivityReadModel.fromCandidate(
      candidate: candidate,
      displayTransaction: displayTransaction,
      summary: summary,
    );
  }

  BusinessActivityReadModel _buildReadModel(
    _SourcedCandidate sourced,
    Map<BusinessActivityKey, BusinessActivitySummary> summaries,
    Map<String, TransactionReadModel> transactionsById,
  ) {
    final candidate = sourced.candidate;
    final displayTransactionId = candidate.displayTransactionId;
    final transaction = displayTransactionId == null
        ? null
        : transactionsById[displayTransactionId];
    if (displayTransactionId != null && transaction == null) {
      throw StateError(
        'Display transaction $displayTransactionId was not found.',
      );
    }
    final summary = summaries[candidate.activityKey];
    if (summary == null) {
      throw StateError(
        'Summary for business activity ${candidate.activityKey.type}:'
        '${candidate.activityKey.id} was not found.',
      );
    }
    return BusinessActivityReadModel.fromCandidate(
      candidate: candidate,
      displayTransaction: transaction,
      summary: summary,
    );
  }

  int _compareCandidates(_SourcedCandidate left, _SourcedCandidate right) {
    final byTime = right.candidate.activityAt.compareTo(
      left.candidate.activityAt,
    );
    if (byTime != 0) return byTime;
    return right.candidate.activityKey.compareTo(left.candidate.activityKey);
  }

  List<BusinessActivitySource> _sourcesFor(BusinessActivityPageQuery query) {
    final activityTypes = query.activityTypes;
    if (activityTypes == null) return _sources;
    return List.unmodifiable(
      _sources.where(
        (source) => source.supportedActivityTypes.any(activityTypes.contains),
      ),
    );
  }

  BusinessActivitySource? _sourceForType(String activityType) {
    for (final source in _sources) {
      if (source.supportedActivityTypes.contains(activityType)) return source;
    }
    return null;
  }

  BusinessActivityCandidate _candidateForActivity(
    BusinessActivityReadModel activity,
  ) {
    return BusinessActivityCandidate(
      activityKey: activity.activityKey,
      activityAt: activity.activityAt,
      displayTransactionId: activity.displayTransactionId,
    );
  }
}

final class _SourcedCandidate {
  const _SourcedCandidate({required this.sourceIndex, required this.candidate});

  final int sourceIndex;
  final BusinessActivityCandidate candidate;
}
