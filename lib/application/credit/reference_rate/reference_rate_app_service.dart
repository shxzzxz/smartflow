import 'package:logging/logging.dart';

import '../../shared/transaction_runner.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/credit/port/reference_rate_repository.dart';
import '../../../domain/credit/port/reference_rate_source.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import 'reference_rate_history.dart';

export '../../../domain/credit/valobj/reference_rate.dart';
export 'reference_rate_history.dart';

class ReferenceRateAppService {
  ReferenceRateAppService({
    required this.repository,
    required List<ReferenceRateSource> sources,
    required this.runner,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now,
       _sources = List.unmodifiable(
         List<ReferenceRateSource>.of(sources)..sort((a, b) {
           final order = a.order.compareTo(b.order);
           return order != 0 ? order : a.key.compareTo(b.key);
         }),
       );

  final ReferenceRateRepository repository;
  final List<ReferenceRateSource> _sources;
  final TransactionRunner runner;
  final DateTime Function() clock;
  final _synchronizations = <_Synchronization>[];

  /// Reads one coherent local snapshot, then supplements it through today.
  /// Source selection, merging and partial failures stay inside this service.
  Stream<ReferenceRateHistory> history(List<InterestRateType> types) async* {
    final today = referenceDate(clock());
    final uniqueTypes = types.toSet();
    final local = <ReferenceRate>[];
    final starts = <InterestRateType, DateTime>{};
    for (final type in uniqueTypes) {
      final rows = (await repository.read(
        type,
      )).where((rate) => !rate.date.isAfter(today)).toList();
      local.addAll(rows);
      final latest = rows.lastOrNull?.date;
      if (!today.isBefore(type.historyStart) &&
          (latest == null || latest.isBefore(today))) {
        starts[type] = latest ?? type.historyStart;
      }
    }
    yield ReferenceRateHistory(
      asOf: today,
      rates: local,
      updating: starts.isNotEmpty,
    );
    if (starts.isEmpty) return;
    final results = await _synchronize(starts, today);
    final rates = <ReferenceRate>[];
    for (final type in uniqueTypes) {
      rates.addAll(
        (await repository.read(
          type,
        )).where((rate) => !rate.date.isAfter(today)),
      );
    }
    yield ReferenceRateHistory(
      asOf: today,
      rates: rates,
      failures: {
        for (final entry in results.entries)
          if (entry.value != null) entry.key: entry.value!,
      },
    );
  }

  Future<ReferenceRateResolution> resolveOne(
    InterestRateType type,
    DateTime date,
  ) async => (await resolveMany([type], [date]))[type]!.single;

  Future<List<ReferenceRateResolution>> resolve(
    InterestRateType type,
    List<DateTime> dates,
  ) async => (await resolveMany([type], dates))[type]!;

  /// Every type is resolved for every date. Duplicate types are collapsed;
  /// date order and duplicate dates are preserved within each result list.
  Future<Map<InterestRateType, List<ReferenceRateResolution>>> resolveMany(
    List<InterestRateType> types,
    List<DateTime> dates,
  ) async {
    final uniqueTypes = types.toSet();
    final requested = dates.map(referenceDate).toList();
    if (uniqueTypes.isEmpty || requested.isEmpty) {
      return Map.unmodifiable({
        for (final type in uniqueTypes) type: const <ReferenceRateResolution>[],
      });
    }
    final today = referenceDate(clock());
    final local = <InterestRateType, List<ReferenceRate>>{};
    final needsSync = <InterestRateType, List<bool>>{};
    final starts = <InterestRateType, DateTime>{};
    DateTime? through;
    for (final type in uniqueTypes) {
      final rows = local[type] = await repository.read(type);
      final latest = rows.lastOrNull?.date;
      needsSync[type] = [
        for (final date in requested)
          !date.isAfter(today) &&
              !date.isBefore(type.historyStart) &&
              (latest == null || latest.isBefore(date)),
      ];
      if (needsSync[type]!.contains(true)) {
        starts[type] = latest ?? type.historyStart;
        for (var i = 0; i < requested.length; i++) {
          if (needsSync[type]![i] &&
              (through == null || requested[i].isAfter(through))) {
            through = requested[i];
          }
        }
      }
    }
    final failures = through == null
        ? <InterestRateType, ReferenceRateMissingReason?>{}
        : await _synchronize(starts, through);
    for (final type in starts.keys) {
      local[type] = await repository.read(type);
    }
    return Map.unmodifiable({
      for (final type in uniqueTypes)
        type: List<ReferenceRateResolution>.unmodifiable([
          for (var i = 0; i < requested.length; i++)
            if (requested[i].isAfter(today))
              ReferenceRateResolution(
                date: requested[i],
                reason: ReferenceRateMissingReason.futureDate,
              )
            else if (needsSync[type]![i] && failures[type] != null)
              ReferenceRateResolution(
                date: requested[i],
                reason: failures[type],
              )
            else
              _resolveLocal(local[type]!, requested[i]),
        ]),
    });
  }

  ReferenceRateResolution _resolveLocal(
    List<ReferenceRate> rates,
    DateTime date,
  ) {
    final rate = rates.where((r) => !r.date.isAfter(date)).lastOrNull;
    return ReferenceRateResolution(
      date: date,
      rate: rate,
      reason: rate == null ? ReferenceRateMissingReason.noHistory : null,
    );
  }

  Future<Map<InterestRateType, ReferenceRateMissingReason?>> _synchronize(
    Map<InterestRateType, DateTime> starts,
    DateTime through,
  ) async {
    final remaining = Map<InterestRateType, DateTime>.of(starts);
    final pending =
        <Future<Map<InterestRateType, ReferenceRateMissingReason?>>>[];
    for (final active in _synchronizations) {
      if (active.through.isBefore(through)) continue;
      final covered = remaining.keys
          .where(
            (type) =>
                active.starts[type] != null &&
                !active.starts[type]!.isAfter(remaining[type]!),
          )
          .toList();
      if (covered.isEmpty) continue;
      for (final type in covered) {
        remaining.remove(type);
      }
      pending.add(
        active.result.then(
          (result) => {for (final type in covered) type: result[type]},
        ),
      );
    }
    if (remaining.isNotEmpty) {
      final active = _Synchronization(remaining, through);
      _synchronizations.add(active);
      active.result = _fetchAndMerge(remaining, through).whenComplete(() {
        _synchronizations.remove(active);
      });
      pending.add(active.result);
    }
    return {for (final result in await Future.wait(pending)) ...result};
  }

  Future<Map<InterestRateType, ReferenceRateMissingReason?>> _fetchAndMerge(
    Map<InterestRateType, DateTime> starts,
    DateTime through,
  ) async {
    final remaining = starts.keys.toSet();
    final results = <InterestRateType, ReferenceRateMissingReason?>{
      for (final type in remaining)
        type: ReferenceRateMissingReason.sourceUnavailable,
    };
    for (final source in _sources) {
      final types = remaining.where(source.supportedTypes.contains).toList();
      if (types.isEmpty) continue;
      final from = types.map((type) => starts[type]!).reduce(_earlier);
      Map<InterestRateType, List<ReferenceRate>> histories;
      try {
        histories = await source.fetch(types, from: from, through: through);
      } on Exception catch (error, stack) {
        _logFallback(source.key, 'request failed', error, stack);
        continue;
      }
      for (final type in types) {
        final rows = histories[type];
        if (rows == null) continue;
        try {
          _validate(rows, type, source.key, from, through);
          // Inclusive refresh must retain the stored anchor. Otherwise the
          // source has not established complete coverage for this type.
          final stored = await repository.read(type);
          final anchor = stored
              .where((row) => !row.date.isAfter(through))
              .lastOrNull;
          if (anchor != null &&
              !anchor.date.isBefore(from) &&
              !rows.any((row) => row.date == anchor.date)) {
            throw const FormatException(
              'Reference rate history omits the stored anchor.',
            );
          }
        } on FormatException catch (error, stack) {
          _logFallback(
            source.key,
            'history validation failed for ${type.name}',
            error,
            stack,
          );
          continue;
        }
        if (rows.isEmpty) {
          if (results[type] != ReferenceRateMissingReason.dataConflict) {
            results[type] = ReferenceRateMissingReason.noHistory;
          }
          continue;
        }
        try {
          await runner.run(() => repository.merge(type, rows));
        } on AppException catch (error, stack) {
          if (error.code != ReferenceRateErrorCode.conflict.code) rethrow;
          _logFallback(
            source.key,
            'history conflict for ${type.name}',
            error,
            stack,
          );
          results[type] = ReferenceRateMissingReason.dataConflict;
          continue;
        }
        results[type] = null;
        remaining.remove(type);
      }
      if (remaining.isEmpty) break;
    }
    return results;
  }

  void _logFallback(
    String source,
    String operation,
    Exception error,
    StackTrace stack,
  ) {
    final appError = error is AppException ? error : null;
    final cause = appError?.cause ?? error;
    // JSON decoding FormatException.source may contain the full response.
    final safeCause = cause is FormatException && cause.source != null
        ? FormatException(cause.message)
        : cause;
    Logger('application.credit.reference_rate').warning(
      'Reference rate $operation from $source'
      '${appError == null ? '' : ' [${appError.code}]'}; '
      'trying remaining sources, otherwise returning a missing result.',
      safeCause,
      appError?.stackTrace ?? stack,
    );
  }

  void _validate(
    List<ReferenceRate> rows,
    InterestRateType type,
    String source,
    DateTime from,
    DateTime through,
  ) {
    final dates = <DateTime>{};
    for (final row in rows) {
      if (row.type != type || row.source != source) {
        throw const FormatException(
          'Reference rate type or source does not match the request.',
        );
      }
      if (row.ratePpm < 0) {
        throw const FormatException('Reference rate must not be negative.');
      }
      if (row.date != referenceDate(row.date)) {
        throw const FormatException(
          'Reference rate date must be a UTC calendar date.',
        );
      }
      if (row.date.isBefore(from) ||
          row.date.isBefore(type.historyStart) ||
          row.date.isAfter(through)) {
        throw const FormatException(
          'Reference rate date is outside the requested history range.',
        );
      }
      if (!dates.add(row.date)) {
        throw const FormatException(
          'Reference rate history contains duplicate dates.',
        );
      }
    }
  }
}

DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

class _Synchronization {
  _Synchronization(this.starts, this.through);
  final Map<InterestRateType, DateTime> starts;
  final DateTime through;
  late final Future<Map<InterestRateType, ReferenceRateMissingReason?>> result;
}
