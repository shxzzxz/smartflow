import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/credit/valobj/reference_rate.dart';
import 'package:smartflow/infrastructure/credit/adapter/chinamoney_reference_rate_source.dart';
import 'package:smartflow/infrastructure/credit/adapter/eastmoney_reference_rate_source.dart';
import 'package:smartflow/infrastructure/credit/adapter/reference_rate_http.dart';

void main() {
  test(
    'Eastmoney retrieves every page and preserves unchanged LPR releases',
    () async {
      final requests = <Uri>[];
      final source = EastmoneyReferenceRateSource(
        get: (uri) async {
          requests.add(uri);
          final second = uri.queryParameters['pageNumber'] == '2';
          return _eastmoney(
            [
              {
                'TRADE_DATE': second
                    ? '2026-02-20 00:00:00'
                    : '2026-01-20 00:00:00',
                'LPR1Y': 3.05,
              },
            ],
            pages: 2,
            count: 2,
          );
        },
      );
      final rates = await source.fetch(
        [InterestRateType.lprOneYear],
        from: DateTime(2019, 8, 20),
        through: DateTime(2026, 3),
      );
      expect(rates[InterestRateType.lprOneYear]!.map((r) => r.ratePpm), [
        30500,
        30500,
      ]);
      expect(requests, hasLength(2));
      expect(
        requests.first.queryParameters['filter'],
        "(TRADE_DATE>='2019-08-20')(TRADE_DATE<='2026-03-01')",
      );
    },
  );

  test('Eastmoney rejects incomplete, repeated or changing pages', () async {
    for (final mode in ['count', 'duplicate', 'changing']) {
      var call = 0;
      final source = EastmoneyReferenceRateSource(
        get: (_) async {
          call++;
          return _eastmoney(
            [
              {
                'TRADE_DATE': mode == 'duplicate' || call == 1
                    ? '2026-01-20'
                    : '2026-02-20',
                'LPR1Y': 3,
              },
            ],
            pages: 2,
            count: mode == 'count'
                ? 3
                : mode == 'changing' && call == 2
                ? 4
                : 2,
          );
        },
      );
      await expectLater(
        source.fetch(
          [InterestRateType.lprOneYear],
          from: DateTime(2019, 8, 20),
          through: DateTime(2026, 3),
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'benchmark range compares preceding history and emits only per-type changes',
    () async {
      final requests = <Uri>[];
      final source = EastmoneyReferenceRateSource(
        get: (uri) async {
          requests.add(uri);
          return _eastmoney([
            {'TRADE_DATE': '2015-08-26', 'RATE_1': 4.6},
            {'TRADE_DATE': '2015-10-24', 'RATE_1': 4.35},
            {'TRADE_DATE': '2026-01-20', 'RATE_1': 4.35},
            {'TRADE_DATE': '2026-02-20', 'RATE_1': 4.35},
          ]);
        },
      );
      final rates = await source.fetch(
        [InterestRateType.loanBenchmarkShortTerm],
        from: DateTime(2015, 10, 24),
        through: DateTime(2026, 3),
      );
      expect(requests.single.queryParameters['filter'], contains("1991-04-21"));
      expect(rates[InterestRateType.loanBenchmarkShortTerm], hasLength(1));
      expect(
        rates[InterestRateType.loanBenchmarkShortTerm]!.single.date,
        DateTime.utc(2015, 10, 24),
      );
      expect(
        rates[InterestRateType.loanBenchmarkShortTerm]!.single.ratePpm,
        43500,
      );
      final absent = await source.fetch(
        [InterestRateType.loanBenchmarkShortTerm],
        from: DateTime(2026),
        through: DateTime(2026, 3),
      );
      expect(absent[InterestRateType.loanBenchmarkShortTerm], isEmpty);
    },
  );

  test(
    'ChinaMoney partitions inclusive years without overlapping boundaries',
    () async {
      final requests = <Uri>[];
      final source = ChinamoneyReferenceRateSource(
        get: (uri) async {
          requests.add(uri);
          final start = uri.queryParameters['strStartDate']!;
          final stop = uri.queryParameters['strEndDate']!;
          return _chinamoney(start, stop, [
            {
              'showDateCN': start == '2025-12-01' ? '2025-12-22' : '2026-01-20',
              '1Y': '3.00',
              '5Y': '3.50',
            },
          ]);
        },
      );
      final rows = await source.fetch(
        [InterestRateType.lprFiveYearPlus],
        from: DateTime(2025, 12),
        through: DateTime(2026, 1, 31),
      );
      expect(requests.map((r) => r.queryParameters['strStartDate']), [
        '2025-12-01',
        '2026-01-01',
      ]);
      expect(requests.map((r) => r.queryParameters['strEndDate']), [
        '2025-12-31',
        '2026-01-31',
      ]);
      expect(rows[InterestRateType.lprFiveYearPlus]!.map((r) => r.ratePpm), [
        35000,
        35000,
      ]);
      expect(
        source.supportedTypes.contains(InterestRateType.loanBenchmarkLongTerm),
        isFalse,
      );
    },
  );

  test(
    'ChinaMoney 200 business error and malformed later segment fail the whole fetch',
    () async {
      final businessError = ChinamoneyReferenceRateSource(
        get: (_) async => {
          'head': {'rep_code': '200'},
          'data': {'message': '只提供一年历史数据查询及下载'},
          'records': [],
        },
      );
      await expectLater(
        businessError.fetch(
          [InterestRateType.lprOneYear],
          from: DateTime(2019, 8, 20),
          through: DateTime(2026),
        ),
        throwsFormatException,
      );
      var call = 0;
      final partial = ChinamoneyReferenceRateSource(
        get: (uri) async {
          if (++call == 2) throw const FormatException('verification page');
          return _chinamoney(
            uri.queryParameters['strStartDate']!,
            uri.queryParameters['strEndDate']!,
            [
              {'showDateCN': '2025-12-22', '1Y': '3.00', '5Y': '3.50'},
            ],
          );
        },
      );
      await expectLater(
        partial.fetch(
          [InterestRateType.lprOneYear],
          from: DateTime(2025, 12),
          through: DateTime(2026, 2),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'rates retain decimal precision and reject null and invalid calendar dates',
    () {
      expect(ratePercentToPpm('3.0501'), 30501);
      expect(() => ratePercentToPpm(null), throwsFormatException);
      expect(() => ratePercentToPpm('-1'), throwsFormatException);
      expect(() => parseReferenceRateDate('2026-02-30'), throwsFormatException);
    },
  );

  test(
    'Eastmoney fetches four columns together and isolates a malformed type across pages',
    () async {
      final requests = <Uri>[];
      final source = EastmoneyReferenceRateSource(
        get: (uri) async {
          requests.add(uri);
          final second = uri.queryParameters['pageNumber'] == '2';
          return _eastmoney(
            [
              {
                'TRADE_DATE': second ? '2026-02-20' : '2026-01-20',
                'LPR1Y': 3,
                'LPR5Y': second ? 'invalid' : 3.5,
                'RATE_1': 4.35,
                'RATE_2': second ? 4.8 : 4.9,
              },
            ],
            pages: 2,
            count: 2,
          );
        },
      );
      final result = await source.fetch(
        InterestRateType.referenceTypes,
        from: DateTime(1991, 4, 21),
        through: DateTime(2026, 3),
      );
      expect(requests, hasLength(2));
      expect(
        requests.first.queryParameters['columns'],
        'TRADE_DATE,LPR1Y,LPR5Y,RATE_1,RATE_2',
      );
      expect(result[InterestRateType.lprOneYear], hasLength(2));
      expect(result.containsKey(InterestRateType.lprFiveYearPlus), isFalse);
      expect(
        result[InterestRateType.loanBenchmarkShortTerm]!.single.ratePpm,
        43500,
      );
      expect(
        result[InterestRateType.loanBenchmarkLongTerm]!.map((r) => r.ratePpm),
        [49000, 48000],
      );
    },
  );

  test(
    'mixed Eastmoney history ignores LPR fields before the supported start',
    () async {
      final source = EastmoneyReferenceRateSource(
        get: (_) async => _eastmoney([
          {'TRADE_DATE': '2015-10-24', 'RATE_1': 4.35, 'RATE_2': 4.9},
          {
            'TRADE_DATE': '2026-01-20',
            'RATE_1': 4.35,
            'RATE_2': 4.9,
            'LPR1Y': 3,
            'LPR5Y': 3.5,
          },
        ]),
      );
      final result = await source.fetch(
        InterestRateType.referenceTypes,
        from: DateTime(1991, 4, 21),
        through: DateTime(2026, 3),
      );
      expect(result.keys, unorderedEquals(InterestRateType.referenceTypes));
      expect(
        result[InterestRateType.lprOneYear]!.single.date,
        DateTime.utc(2026, 1, 20),
      );
      expect(
        result[InterestRateType.loanBenchmarkShortTerm]!.single.date,
        DateTime.utc(2015, 10, 24),
      );
    },
  );

  test(
    'ChinaMoney reads both terms per segment and discards only the incomplete term',
    () async {
      final requests = <Uri>[];
      final source = ChinamoneyReferenceRateSource(
        get: (uri) async {
          requests.add(uri);
          final start = uri.queryParameters['strStartDate']!;
          final stop = uri.queryParameters['strEndDate']!;
          return _chinamoney(start, stop, [
            {
              'showDateCN': start == '2025-12-01' ? '2025-12-22' : '2026-01-20',
              '1Y': '3.00',
              '5Y': start == '2025-12-01' ? '3.50' : 'invalid',
            },
          ]);
        },
      );
      final result = await source.fetch(
        [InterestRateType.lprOneYear, InterestRateType.lprFiveYearPlus],
        from: DateTime(2025, 12),
        through: DateTime(2026, 1, 31),
      );
      expect(requests, hasLength(2));
      expect(result[InterestRateType.lprOneYear]!.map((r) => r.ratePpm), [
        30000,
        30000,
      ]);
      expect(result.containsKey(InterestRateType.lprFiveYearPlus), isFalse);
    },
  );
}

Map<String, dynamic> _eastmoney(
  List<Map<String, Object>> rows, {
  int pages = 1,
  int? count,
}) => {
  'success': true,
  'code': 0,
  'result': {'pages': pages, 'count': count ?? rows.length, 'data': rows},
};

Map<String, dynamic> _chinamoney(
  String start,
  String end,
  List<Map<String, String>> rows,
) => {
  'head': {'rep_code': '200'},
  'data': {'message': '', 'startDateCN': start, 'endDateCN': end},
  'records': rows,
};
