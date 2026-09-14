import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/application/credit/reference_rate/reference_rate_service.dart';
import 'package:smartflow/domain/credit/port/reference_rate_source.dart';
import 'package:smartflow/infrastructure/credit/adapter/chinamoney_reference_rate_source.dart';
import 'package:smartflow/infrastructure/credit/adapter/eastmoney_reference_rate_source.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_reference_rate_repository.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/data_management/backup/drift_backup_gateway.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/application/data_management/backup/installment_backup_migration.dart';
import 'package:smartflow/application/data_management/backup/backup_models.dart';

import '../../helper/test_app_database.dart';

const _type = InterestRateType.lprOneYear;
ReferenceRate _rate(String date, int ppm, {InterestRateType type = _type}) =>
    ReferenceRate(
      type: type,
      date: DateTime.parse('${date}T00:00:00Z'),
      ratePpm: ppm,
      source: 'fixture',
    );

void main() {
  late _Fixture f;
  setUp(() => f = _Fixture());
  tearDown(() => f.db.close());

  for (final failure in ['request', 'validation', 'anchor', 'conflict']) {
    test(
      '$failure logs one warning per attempt and preserves fallback',
      () async {
        final logs = <LogRecord>[];
        final subscription = Logger.root.onRecord.listen(logs.add);
        addTearDown(subscription.cancel);
        f.source.fail = failure == 'request';
        f.source.rows = [
          _rate('2026-02-20', failure == 'validation' ? -1 : 29000),
        ];
        if (failure == 'conflict' || failure == 'anchor') {
          await f.seed([_rate('2026-02-20', 30000)]);
        }
        if (failure == 'anchor') f.source.rows = [_rate('2026-03-01', 29000)];
        final fallback = _Source(key: 'fallback', order: 200)
          ..rows = [_rate('2026-02-20', 30000)];
        f.sources.add(fallback);

        for (var attempt = 1; attempt <= 2; attempt++) {
          final results = await Future.wait([
            f.service.resolveOne(_type, DateTime(2026, 3, 2)),
            f.service.resolveOne(_type, DateTime(2026, 3, 2)),
          ]);
          expect(results.every((r) => r.rate?.ratePpm == 30000), isTrue);
          final failures = logs
              .where((r) => r.loggerName == 'application.credit.reference_rate')
              .toList();
          expect(failures, hasLength(attempt));
          final log = failures.last;
          expect(log.level, Level.WARNING);
          expect(log.message, contains('fixture'));
          if (failure == 'conflict') {
            expect(log.message, contains(ReferenceRateErrorCode.conflict.code));
            expect(log.error, isA<AppException>());
          } else {
            expect(log.error, isA<FormatException>());
          }
          expect(log.stackTrace, isNotNull);
        }
        expect(fallback.calls, hasLength(2));
      },
    );
  }

  test(
    'source parse failure logs its cause and stack without response content',
    () async {
      const response = '<html>full upstream response marker</html>';
      final failure = FormatException('Unexpected token', response, 0);
      final stack = StackTrace.fromString('reference source decoder');
      f.source.failure = failure;
      f.source.failureStack = stack;
      final logs = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(logs.add);
      addTearDown(subscription.cancel);
      final result = await f.service.resolveOne(_type, DateTime(2026, 3, 2));
      expect(result.reason, ReferenceRateMissingReason.sourceUnavailable);
      final log = logs
          .where((r) => r.loggerName == 'application.credit.reference_rate')
          .single;
      expect(log.stackTrace, same(stack));
      expect(
        log.error,
        isA<FormatException>().having(
          (e) => e.message,
          'cause',
          failure.message,
        ),
      );
      expect(
        '${log.message} ${log.error} ${log.stackTrace}',
        isNot(contains(response)),
      );
    },
  );

  test(
    'today lookup uses the latest available quote before and after publication',
    () async {
      f.source.rows = [_rate('2026-02-20', 30000)];
      final before = await f.service.resolveOne(_type, DateTime(2026, 3, 2));
      expect(before.rate?.ratePpm, 30000);
      expect(before.reason, isNull);

      f.source.rows.add(_rate('2026-03-02', 29000));
      final after = await f.service.resolveOne(_type, DateTime(2026, 3, 2));
      expect(after.rate?.ratePpm, 29000);
      expect(after.reason, isNull);
    },
  );

  test(
    'history emits local records before the network completes and keeps them on failure',
    () async {
      await f.seed([_rate('2026-01-20', 30000)]);
      f.source.gate = Completer<void>();
      f.source.fail = true;
      final snapshots = <ReferenceRateHistory>[];
      final first = Completer<void>();
      final result = f.service.history([_type]).forEach((snapshot) {
        snapshots.add(snapshot);
        if (!first.isCompleted) first.complete();
      });
      await first.future;
      expect(snapshots.single.rates.single.ratePpm, 30000);
      expect(snapshots.single.updating, isTrue);
      f.source.gate!.complete();
      await result;
      expect(snapshots.last.rates.single.ratePpm, 30000);
      expect(
        snapshots.last.failures[_type],
        ReferenceRateMissingReason.sourceUnavailable,
      );
      expect(snapshots.last.updating, isFalse);
    },
  );

  test(
    'history merges a whole group through today and shares one source request',
    () async {
      const other = InterestRateType.lprFiveYearPlus;
      f.source.rows = [
        _rate('2026-01-20', 30000),
        _rate('2026-02-20', 29000),
        _rate('2026-02-20', 35000, type: other),
      ];
      final snapshots = await f.service.history([_type, other]).toList();
      expect(snapshots.first.rates, isEmpty);
      expect(snapshots.last.rates, hasLength(3));
      expect(snapshots.last.failures, isEmpty);
      expect(f.source.calls.single.types, [_type, other]);
      expect(f.source.calls.single.through, DateTime.utc(2026, 3, 2));
      expect(await f.repository.read(other), hasLength(1));
    },
  );

  test(
    'today history avoids networking and ignores future stored records',
    () async {
      await f.seed([_rate('2026-03-02', 30000), _rate('2027-01-20', 20000)]);
      final snapshots = await f.service.history([_type]).toList();
      expect(snapshots.single.rates.single.ratePpm, 30000);
      expect(snapshots.single.updating, isFalse);
      expect(f.source.calls, isEmpty);
    },
  );

  test(
    'equal priority uses key and construction takes a copy of the source list',
    () async {
      final preferred = _Source(key: 'a-source')
        ..rows = [_rate('2026-02-20', 29000)];
      final other = _Source(key: 'z-source')
        ..rows = [_rate('2026-02-20', 35000)];
      final sources = <ReferenceRateSource>[other, preferred];
      final service = ReferenceRateService(
        repository: f.repository,
        sources: sources,
        runner: f.runner,
        clock: () => DateTime(2026, 3, 2),
      );
      expect(sources.first, same(other));
      sources.clear();
      final result = await service.resolveOne(_type, DateTime(2026, 3, 1));
      expect(result.rate?.source, 'a-source');
      expect(other.calls, isEmpty);
    },
  );

  test(
    'history rejects records whose source evidence does not match the source key',
    () async {
      f.source.rows = [
        ReferenceRate(
          type: _type,
          date: DateTime.utc(2026, 1, 20),
          ratePpm: 30000,
          source: 'another-source',
        ),
      ];
      final snapshots = await f.service.history([_type]).toList();
      expect(
        snapshots.last.failures[_type],
        ReferenceRateMissingReason.sourceUnavailable,
      );
      expect(snapshots.last.rates, isEmpty);
      expect(await f.repository.read(_type), isEmpty);
    },
  );

  for (final mode in ['complete', 'partial', 'failure']) {
    test('source priority overrides reverse injection: $mode', () async {
      const other = InterestRateType.lprFiveYearPlus;
      await f.seed([_rate('2026-01-20', 30000)]);
      await f.seed([_rate('2026-01-20', 35000, type: other)]);
      final calls = <String>[];
      final eastmoney = EastmoneyReferenceRateSource(
        get: (_) async {
          calls.add('eastmoney');
          if (mode == 'failure') {
            throw const FormatException('source unavailable');
          }
          return {
            'success': true,
            'code': 0,
            'result': {
              'pages': 1,
              'count': 2,
              'data': [
                for (final date in ['2026-01-20', '2026-02-20'])
                  {
                    'TRADE_DATE': date,
                    'LPR1Y': 3,
                    if (mode == 'complete') 'LPR5Y': 3.5,
                  },
              ],
            },
          };
        },
      );
      final chinamoney = ChinamoneyReferenceRateSource(
        get: (uri) async {
          calls.add('chinamoney');
          return {
            'head': {'rep_code': '200'},
            'data': {
              'message': '',
              'startDateCN': uri.queryParameters['strStartDate'],
              'endDateCN': uri.queryParameters['strEndDate'],
            },
            'records': [
              for (final date in ['2026-01-20', '2026-02-20'])
                {'showDateCN': date, '1Y': '3.00', '5Y': '3.50'},
            ],
          };
        },
      );
      final service = ReferenceRateService(
        repository: f.repository,
        sources: [chinamoney, eastmoney],
        runner: f.runner,
        clock: () => DateTime(2026, 3, 2),
      );
      final results = await service.resolveMany(
        [_type, other],
        [DateTime(2026, 3, 1)],
      );
      expect(
        calls,
        mode == 'complete' ? ['eastmoney'] : ['eastmoney', 'chinamoney'],
      );
      expect(
        results[_type]!.single.rate?.source,
        mode == 'failure' ? 'chinamoney' : 'eastmoney',
      );
      expect(
        results[other]!.single.rate?.source,
        mode == 'complete' ? 'eastmoney' : 'chinamoney',
      );
    });
  }

  test(
    'historical dates use local records without any remote request',
    () async {
      await f.seed([_rate('2026-01-20', 30000), _rate('2026-02-20', 29000)]);
      f.source.fail = true;
      final results = await f.service.resolve(_type, [
        DateTime(2026, 1, 21),
        DateTime(2026, 2, 1),
        DateTime(2026, 1, 21),
      ]);
      expect(results.map((r) => r.rate?.ratePpm), [30000, 30000, 30000]);
      expect(f.source.calls, isEmpty);
    },
  );

  test(
    'a quote on the requested day resolves locally even while offline',
    () async {
      await f.seed([_rate('2026-01-20', 30000)]);
      f.source.fail = true;
      final result = (await f.service.resolve(_type, [
        DateTime(2026, 1, 20, 23),
      ])).single;
      expect(result.rate?.ratePpm, 30000);
      expect(result.reason, isNull);
      expect(f.source.calls, isEmpty);
    },
  );

  test(
    'empty database fetches full history and retains unchanged monthly quotes',
    () async {
      f.source.rows = [_rate('2026-01-20', 30000), _rate('2026-02-20', 30000)];
      final results = await f.service.resolve(_type, [
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 1),
      ]);
      expect(f.source.calls.single.from, _type.historyStart);
      expect(results.map((r) => r.rate?.date), [
        DateTime.utc(2026, 1, 20),
        DateTime.utc(2026, 2, 20),
      ]);
      expect(await f.repository.read(_type), hasLength(2));
    },
  );

  test('batch synchronizes once from the last date inclusively', () async {
    await f.seed([_rate('2026-01-20', 30000)]);
    f.source.rows = [_rate('2026-01-20', 30000), _rate('2026-02-20', 29000)];
    final results = await f.service.resolve(_type, [
      DateTime(2026, 1, 20),
      DateTime(2026, 3, 1),
    ]);
    expect(f.source.calls.single.from, DateTime.utc(2026, 1, 20));
    expect(f.source.calls.single.through, DateTime.utc(2026, 3, 1));
    expect(results.map((r) => r.rate?.ratePpm), [30000, 29000]);
  });

  test('successful unchanged response confirms the requested date', () async {
    await f.seed([_rate('2026-01-20', 30000)]);
    f.source.rows = [_rate('2026-01-20', 30000)];
    final result = (await f.service.resolve(_type, [
      DateTime(2026, 3, 1),
    ])).single;
    expect(result.rate?.ratePpm, 30000);
    expect(result.reason, isNull);
    expect(await f.repository.read(_type), hasLength(1));
  });

  test(
    'all sources fail: unresolved dates wait, trusted historical dates still resolve',
    () async {
      await f.seed([_rate('2025-12-22', 31000), _rate('2026-01-20', 30000)]);
      f.source.fail = true;
      final results = await f.service.resolve(_type, [
        DateTime(2026, 1, 21),
        DateTime(2026, 1, 19),
      ]);
      expect(
        results.first.reason,
        ReferenceRateMissingReason.sourceUnavailable,
      );
      expect(results.first.rate, isNull);
      expect(results.last.rate?.ratePpm, 31000);
      expect(results.last.reason, isNull);
      expect(await f.repository.read(_type), hasLength(2));
    },
  );

  test(
    'unsupported sources are skipped and failures try the next supported source',
    () async {
      final unsupported = _Source(key: 'unsupported', order: 0)
        ..supported = {InterestRateType.loanBenchmarkLongTerm};
      final failing = _Source(key: 'failing', order: 50)..fail = true;
      f.sources.insertAll(0, [unsupported, failing]);
      f.source.rows = [_rate('2026-01-20', 30000)];
      expect(
        (await f.service.resolve(_type, [DateTime(2026, 3, 1)])).single.rate,
        isNotNull,
      );
      expect(unsupported.calls, isEmpty);
      expect(failing.calls, hasLength(1));
      expect(f.source.calls, hasLength(1));
    },
  );

  test('concurrent resolutions share one in-flight request', () async {
    f.source.gate = Completer<void>();
    f.source.rows = [_rate('2026-01-20', 30000)];
    final one = f.service.resolve(_type, [DateTime(2026, 3, 2)]);
    await f.source.started.future;
    final two = f.service.resolve(_type, [DateTime(2026, 3, 1)]);
    // Let the second local read finish before releasing the shared source.
    await f.repository.read(_type);
    f.source.gate!.complete();
    final results = await Future.wait([one, two]);
    expect(results.map((batch) => batch.single.rate?.ratePpm), [30000, 30000]);
    expect(f.source.calls, hasLength(1));
  });

  test(
    'conflicting values roll back the entire merge and keep the original',
    () async {
      await f.seed([_rate('2026-01-20', 30000)]);
      f.source.rows = [_rate('2026-02-20', 28000), _rate('2026-01-20', 31000)];
      final result = (await f.service.resolve(_type, [
        DateTime(2026, 3, 1),
      ])).single;
      expect(result.rate, isNull);
      expect(result.reason, ReferenceRateMissingReason.dataConflict);
      final stored = await f.repository.read(_type);
      expect(stored, hasLength(1));
      expect(stored.single.ratePpm, 30000);
    },
  );

  test('future dates are not converted into confirmed future quotes', () async {
    final result = (await f.service.resolve(_type, [DateTime(2027)])).single;
    expect(result.reason, ReferenceRateMissingReason.futureDate);
    expect(f.source.calls, isEmpty);
  });

  test(
    'multiple types share the earliest local anchor and latest requested date',
    () async {
      const other = InterestRateType.lprFiveYearPlus;
      await f.seed([_rate('2026-01-20', 30000)]);
      await f.seed([_rate('2025-12-22', 35000, type: other)]);
      f.source.rows = [
        _rate('2026-01-20', 30000),
        _rate('2026-02-20', 29000),
        _rate('2025-12-22', 35000, type: other),
        _rate('2026-02-20', 34000, type: other),
      ];
      final results = await f.service.resolveMany(
        [_type, other, _type],
        [
          DateTime(2026, 3, 1, 23),
          DateTime(2026, 2, 1),
          DateTime(2027),
          DateTime(2026, 2, 1),
        ],
      );
      expect(f.source.calls.single.types, [_type, other]);
      expect(f.source.calls.single.from, DateTime.utc(2025, 12, 22));
      expect(f.source.calls.single.through, DateTime.utc(2026, 3, 1));
      expect(results[_type]!.map((r) => r.rate?.ratePpm), [
        29000,
        30000,
        null,
        30000,
      ]);
      expect(results[other]!.map((r) => r.rate?.ratePpm), [
        34000,
        35000,
        null,
        35000,
      ]);
      expect(results[other]![2].reason, ReferenceRateMissingReason.futureDate);
      expect(results[_type]!.first.date, DateTime.utc(2026, 3, 1));
    },
  );

  test(
    'local coverage excludes a type from fetching and empty history expands the range',
    () async {
      const other = InterestRateType.loanBenchmarkLongTerm;
      await f.seed([_rate('2026-03-01', 30000)]);
      f.source.rows = [_rate('2015-10-24', 49000, type: other)];
      final results = await f.service.resolveMany(
        [_type, other],
        [DateTime(2026, 3, 1)],
      );
      expect(f.source.calls.single.types, [other]);
      expect(f.source.calls.single.from, other.historyStart);
      expect(results[_type]!.single.rate?.ratePpm, 30000);
      expect(results[other]!.single.rate?.ratePpm, 49000);
    },
  );

  test(
    'partial sources only retry remaining types and preserve successes on failure',
    () async {
      const other = InterestRateType.lprFiveYearPlus;
      const missing = InterestRateType.loanBenchmarkLongTerm;
      f.source.rows = [_rate('2026-01-20', 30000)];
      f.source.omitted = {other, missing};
      final failing = _Source(key: 'failing', order: 200)..fail = true;
      final fallback = _Source(key: 'fallback', order: 300)
        ..supported = {_type, other}
        ..rows = [_rate('2026-01-20', 35000, type: other)];
      f.sources.addAll([failing, fallback]);
      final results = await f.service.resolveMany(
        [_type, other, missing],
        [DateTime(2026, 3, 1)],
      );
      expect(f.source.calls.single.types, [_type, other, missing]);
      expect(failing.calls.single.types, [other, missing]);
      expect(fallback.calls.single.types, [other]);
      expect(results[_type]!.single.rate?.ratePpm, 30000);
      expect(results[other]!.single.rate?.ratePpm, 35000);
      expect(
        results[missing]!.single.reason,
        ReferenceRateMissingReason.sourceUnavailable,
      );
      expect(await f.repository.read(_type), hasLength(1));
      expect(await f.repository.read(other), hasLength(1));
      expect(await f.repository.read(missing), isEmpty);
    },
  );

  test(
    'a conflict rolls back only its type while another type is committed',
    () async {
      const other = InterestRateType.lprFiveYearPlus;
      await f.seed([_rate('2026-01-20', 30000)]);
      f.source.rows = [
        _rate('2026-02-20', 28000),
        _rate('2026-01-20', 31000),
        _rate('2026-02-20', 35000, type: other),
      ];
      final results = await f.service.resolveMany(
        [_type, other],
        [DateTime(2026, 3, 1)],
      );
      expect(
        results[_type]!.single.reason,
        ReferenceRateMissingReason.dataConflict,
      );
      expect((await f.repository.read(_type)).single.ratePpm, 30000);
      expect(results[other]!.single.rate?.ratePpm, 35000);
      expect((await f.repository.read(other)).single.ratePpm, 35000);
    },
  );

  test(
    'same-day trusted answers survive failed updates for later dates',
    () async {
      await f.seed([_rate('2026-01-20', 30000)]);
      f.source.fail = true;
      final results = await f.service.resolve(_type, [
        DateTime(2026, 1, 20),
        DateTime(2026, 2),
      ]);
      expect(results.first.rate?.ratePpm, 30000);
      expect(results.last.reason, ReferenceRateMissingReason.sourceUnavailable);
    },
  );

  test('a shorter in-flight range cannot confirm a later date', () async {
    f.source.gate = Completer<void>();
    f.source.rows = [_rate('2026-01-20', 30000), _rate('2026-02-20', 29000)];
    final earlier = f.service.resolveOne(_type, DateTime(2026, 2, 1));
    await f.source.started.future;
    final later = f.service.resolveOne(_type, DateTime(2026, 3, 1));
    await f.repository.read(_type);
    f.source.gate!.complete();
    final results = await Future.wait([earlier, later]);
    expect(results.map((r) => r.rate?.ratePpm), [30000, 29000]);
    expect(f.source.calls, hasLength(2));
  });

  test('empty requests and dates before history never fetch', () async {
    expect(await f.service.resolveMany([], [DateTime(2026)]), isEmpty);
    expect((await f.service.resolveMany([_type], []))[_type], isEmpty);
    expect(
      (await f.service.resolveOne(_type, DateTime(1990))).reason,
      ReferenceRateMissingReason.noHistory,
    );
    expect(f.source.calls, isEmpty);
  });

  test(
    'empty history tries a later source and exhausted empty histories report no history',
    () async {
      final fallback = _Source(key: 'fallback', order: 300)
        ..rows = [_rate('2026-01-20', 30000)];
      f.sources.add(fallback);
      expect(
        (await f.service.resolveOne(_type, DateTime(2026, 2))).rate?.ratePpm,
        30000,
      );
      expect(fallback.calls.single.types, [_type]);
      final missing = await f.service.resolveOne(
        InterestRateType.loanBenchmarkLongTerm,
        DateTime(2026, 2),
      );
      expect(missing.reason, ReferenceRateMissingReason.noHistory);
    },
  );

  test(
    'an inclusive response missing its saved anchor falls back without merging',
    () async {
      await f.seed([_rate('2026-01-20', 30000)]);
      f.source.rows = [_rate('2026-02-20', 29000)];
      final fallback = _Source(key: 'fallback', order: 300)
        ..rows = [_rate('2026-01-20', 30000), _rate('2026-02-20', 28000)];
      f.sources.add(fallback);
      expect(
        (await f.service.resolveOne(_type, DateTime(2026, 3, 1))).rate?.ratePpm,
        28000,
      );
      expect((await f.repository.read(_type)).map((r) => r.ratePpm), [
        30000,
        28000,
      ]);
    },
  );

  test(
    'resolution isolates types and preserves input date order and boundaries',
    () async {
      await f.seed([_rate('2026-01-20', 30000), _rate('2026-02-20', 29000)]);
      const otherType = InterestRateType.loanBenchmarkLongTerm;
      await f.seed([
        _rate('2026-01-20', 49000, type: otherType),
        _rate('2026-02-20', 48000, type: otherType),
      ]);
      final dates = [
        DateTime(2026, 1, 20, 23),
        DateTime(2026, 1, 19),
        DateTime(2026, 1, 20),
        DateTime(2027),
      ];
      final lpr = await f.service.resolve(_type, dates);
      final benchmark = await f.service.resolve(otherType, dates);
      expect(lpr.map((r) => r.rate?.ratePpm), [30000, null, 30000, null]);
      expect(benchmark.map((r) => r.rate?.ratePpm), [49000, null, 49000, null]);
      expect(lpr[1].reason, ReferenceRateMissingReason.noHistory);
      expect(lpr.last.reason, ReferenceRateMissingReason.futureDate);
      expect(lpr.first.date, DateTime.utc(2026, 1, 20));
      expect(f.source.calls, isEmpty);
    },
  );

  test(
    'all four types survive logical backup replacement without sync metadata',
    () async {
      for (final type in InterestRateType.referenceTypes) {
        await f.seed([_rate('2026-01-20', 30000, type: type)]);
      }
      final snapshot = await DriftBackupGateway(f.db).readSnapshot();
      BackupService.validateSnapshot(snapshot);
      expect(snapshot.rows('reference_rates'), hasLength(4));
      final target = createTestDatabase();
      addTearDown(target.close);
      await DriftBackupGateway(target).replaceSnapshot(snapshot);
      expect(await target.select(target.referenceRates).get(), hasLength(4));
      expect(
        await target
            .customSelect(
              "SELECT name FROM sqlite_master WHERE name = 'reference_rate_sync_states'",
            )
            .get(),
        isEmpty,
      );
    },
  );

  test(
    'schema 36 logical backups migrate quote identity and preserve rate evidence',
    () {
      final tables = <String, Iterable<BackupJson>>{
        'lpr_quotes': [
          {
            'quoteDate': 123000,
            'tenor': 'fiveYearPlus',
            'ratePpm': 42000,
            'source': 'legacy',
            'createdAt': 124000,
          },
        ],
      };
      migrateInstallmentBackup(tables, schemaVersion: 36, formatVersion: 2);
      expect(tables.containsKey('lpr_quotes'), isFalse);
      expect(tables['reference_rates']!.single, {
        'rateDate': 123000,
        'type': 'lprFiveYearPlus',
        'ratePpm': 42000,
        'source': 'legacy',
        'createdAt': 124000,
      });
    },
  );
}

class _Fixture {
  final db = createTestDatabase();
  final source = _Source();
  late final sources = <ReferenceRateSource>[source];
  late final repository = DriftReferenceRateRepository(db);
  late final runner = DriftTransactionRunner(db);
  late final service = ReferenceRateService(
    repository: repository,
    sources: sources,
    runner: runner,
    clock: () => DateTime(2026, 3, 2),
  );
  Future<void> seed(List<ReferenceRate> rows) =>
      runner.run(() => repository.merge(rows.first.type, rows));
}

class _Source implements ReferenceRateSource {
  _Source({this.key = 'fixture', this.order = 100});
  @override
  final String key;
  @override
  final int order;
  Set<InterestRateType> supported = InterestRateType.referenceTypes.toSet();
  @override
  Set<InterestRateType> get supportedTypes => supported;
  List<ReferenceRate> rows = [];
  bool fail = false;
  Exception? failure;
  StackTrace? failureStack;
  Completer<void>? gate;
  final started = Completer<void>();
  Set<InterestRateType> omitted = {};
  final calls =
      <({List<InterestRateType> types, DateTime from, DateTime through})>[];
  @override
  Future<Map<InterestRateType, List<ReferenceRate>>> fetch(
    List<InterestRateType> types, {
    required DateTime from,
    required DateTime through,
  }) async {
    calls.add((types: types, from: from, through: through));
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
    if (fail) throw const FormatException('invalid source');
    return {
      for (final type in types)
        if (!omitted.contains(type))
          type: rows
              .where(
                (row) =>
                    row.type == type &&
                    !row.date.isBefore(from) &&
                    !row.date.isAfter(through),
              )
              .map(
                (row) => ReferenceRate(
                  type: row.type,
                  date: row.date,
                  ratePpm: row.ratePpm,
                  source: row.source == 'fixture' ? key : row.source,
                ),
              )
              .toList(),
    };
  }
}
