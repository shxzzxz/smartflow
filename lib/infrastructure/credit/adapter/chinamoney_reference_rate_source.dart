import '../../../domain/credit/port/reference_rate_source.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import 'reference_rate_http.dart';

class ChinamoneyReferenceRateSource implements ReferenceRateSource {
  ChinamoneyReferenceRateSource({ReferenceRateJsonGet? get})
    : _get = get ?? fetchReferenceRateJson;
  final ReferenceRateJsonGet _get;
  @override
  String get key => 'chinamoney';
  @override
  int get order => 200;
  @override
  Set<ReferenceRateType> get supportedTypes => const {
    ReferenceRateType.lprOneYear,
    ReferenceRateType.lprFiveYearPlus,
  };

  @override
  Future<Map<ReferenceRateType, List<ReferenceRate>>> fetch(
    List<ReferenceRateType> types, {
    required DateTime from,
    required DateTime through,
  }) async {
    if (types.any((type) => !supportedTypes.contains(type))) {
      throw ArgumentError('Unsupported rate type');
    }
    var start = referenceDate(from);
    final end = referenceDate(through);
    if (start.isAfter(end)) throw ArgumentError('Invalid reference rate range');
    final rates = {for (final type in types) type: <ReferenceRate>[]};
    if (rates.isEmpty) return rates;
    final historyStart = ReferenceRateType.lprOneYear.historyStart;
    if (start.isBefore(historyStart)) start = historyStart;
    final dates = <DateTime>{};
    while (!start.isAfter(end)) {
      final yearEnd = DateTime.utc(start.year, 12, 31);
      final stop = yearEnd.isBefore(end) ? yearEnd : end;
      final json = rateObject(
        await _get(
          Uri.https(
            'www.chinamoney.com.cn',
            '/ags/ms/cm-u-bk-currency/LprHis',
            {
              'lang': 'CN',
              'strStartDate': referenceRateDateText(start),
              'strEndDate': referenceRateDateText(stop),
            },
          ),
        ),
      );
      final head = rateObject(json['head']);
      final data = rateObject(json['data']);
      final rows = json['records'];
      if (head['rep_code'] != '200' ||
          (data['message'] ?? '') != '' ||
          data['startDateCN'] != referenceRateDateText(start) ||
          data['endDateCN'] != referenceRateDateText(stop) ||
          rows is! List) {
        throw const FormatException(
          'Invalid ChinaMoney reference rate response.',
        );
      }
      for (final raw in rows) {
        final row = rateObject(raw);
        final date = parseReferenceRateDate(row['showDateCN']);
        if (date.isBefore(start) || date.isAfter(stop) || !dates.add(date)) {
          throw const FormatException('Duplicate or out-of-range rate date.');
        }
        for (final type in rates.keys.toList()) {
          try {
            rates[type]!.add(
              ReferenceRate(
                type: type,
                date: date,
                ratePpm: ratePercentToPpm(
                  row[type == ReferenceRateType.lprOneYear ? '1Y' : '5Y'],
                ),
                source: key,
              ),
            );
          } on FormatException {
            // Never retain earlier segments of an incomplete type history.
            rates.remove(type);
          }
        }
      }
      start = DateTime.utc(stop.year, stop.month, stop.day + 1);
    }
    for (final rows in rates.values) {
      rows.sort((a, b) => a.date.compareTo(b.date));
    }
    return rates;
  }
}
