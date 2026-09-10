import '../../../domain/credit/port/reference_rate_source.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import 'reference_rate_http.dart';

class EastmoneyReferenceRateSource implements ReferenceRateSource {
  EastmoneyReferenceRateSource({ReferenceRateJsonGet? get})
    : _get = get ?? fetchReferenceRateJson;
  final ReferenceRateJsonGet _get;
  @override
  String get key => 'eastmoney';
  @override
  int get order => 100;
  @override
  Set<ReferenceRateType> get supportedTypes => ReferenceRateType.values.toSet();

  @override
  Future<Map<ReferenceRateType, List<ReferenceRate>>> fetch(
    List<ReferenceRateType> types, {
    required DateTime from,
    required DateTime through,
  }) async {
    final start = referenceDate(from);
    final end = referenceDate(through);
    if (start.isAfter(end)) throw ArgumentError('Invalid reference rate range');
    // Benchmark values are repeated on LPR observation dates. Read predecessors
    // before filtering the range so only actual benchmark changes become records.
    final columns = {
      for (final type in types)
        type: switch (type) {
          ReferenceRateType.lprOneYear => 'LPR1Y',
          ReferenceRateType.lprFiveYearPlus => 'LPR5Y',
          ReferenceRateType.loanBenchmarkShortTerm => 'RATE_1',
          ReferenceRateType.loanBenchmarkLongTerm => 'RATE_2',
        },
    };
    if (columns.isEmpty) return const {};
    final fetchStart = types.any((type) => !type.isLpr)
        ? ReferenceRateType.loanBenchmarkShortTerm.historyStart
        : start.isBefore(ReferenceRateType.lprOneYear.historyStart)
        ? ReferenceRateType.lprOneYear.historyStart
        : start;
    final rows = {for (final type in columns.keys) type: <ReferenceRate>[]};
    if (fetchStart.isAfter(end)) return rows;
    final seen = <DateTime>{};
    int? count;
    var pages = 1;
    for (var page = 1; page <= pages; page++) {
      final json = rateObject(
        await _get(
          Uri.https('datacenter-web.eastmoney.com', '/api/data/v1/get', {
            'reportName': 'RPTA_WEB_RATE',
            'columns': 'TRADE_DATE,${columns.values.join(',')}',
            'filter':
                "(TRADE_DATE>='${referenceRateDateText(fetchStart)}')(TRADE_DATE<='${referenceRateDateText(end)}')",
            'sortColumns': 'TRADE_DATE',
            'sortTypes': '1',
            'pageNumber': '$page',
            'pageSize': '500',
          }),
        ),
      );
      if (json['success'] != true || json['code'] != 0) {
        throw const FormatException('Eastmoney reference rate request failed.');
      }
      final result = rateObject(json['result']);
      final total = result['count'];
      final totalPages = result['pages'];
      final data = result['data'];
      if (total is! int ||
          total < 0 ||
          totalPages is! int ||
          totalPages < 1 ||
          totalPages > 100 ||
          data is! List ||
          (count != null && (total != count || totalPages != pages))) {
        throw const FormatException('Invalid Eastmoney pagination.');
      }
      count = total;
      pages = totalPages;
      for (final raw in data) {
        final row = rateObject(raw);
        final date = parseReferenceRateDate(row['TRADE_DATE']);
        if (date.isBefore(fetchStart) || date.isAfter(end) || !seen.add(date)) {
          throw const FormatException('Duplicate or out-of-range rate date.');
        }
        for (final type in rows.keys.toList()) {
          if (date.isBefore(type.historyStart)) continue;
          try {
            rows[type]!.add(
              ReferenceRate(
                type: type,
                date: date,
                ratePpm: ratePercentToPpm(row[columns[type]]),
                source: key,
              ),
            );
          } on FormatException {
            rows.remove(type);
          }
        }
      }
    }
    if (seen.length != count) {
      throw const FormatException('Incomplete Eastmoney reference rate pages.');
    }
    final rates = <ReferenceRateType, List<ReferenceRate>>{};
    for (final entry in rows.entries) {
      entry.value.sort((a, b) => a.date.compareTo(b.date));
      final history = rates[entry.key] = [];
      int? previous;
      for (final row in entry.value) {
        if (entry.key.isLpr || row.ratePpm != previous) {
          if (!row.date.isBefore(start)) history.add(row);
        }
        previous = row.ratePpm;
      }
    }
    return rates;
  }
}
