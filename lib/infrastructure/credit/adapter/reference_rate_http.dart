import 'dart:convert';
import 'dart:io';

typedef ReferenceRateJsonGet = Future<Object?> Function(Uri uri);

Future<Object?> fetchReferenceRateJson(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    return await (() async {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'SmartFlow');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Reference rate HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      final chunks = <int>[];
      await for (final chunk in response) {
        chunks.addAll(chunk);
        if (chunks.length > 4 * 1024 * 1024) {
          throw const FormatException('Reference rate response is too large.');
        }
      }
      return jsonDecode(utf8.decode(chunks));
    })().timeout(const Duration(seconds: 15));
  } finally {
    client.close(force: true);
  }
}

Map<String, dynamic> rateObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid reference rate object.');
  }
  return value;
}

int ratePercentToPpm(Object? value) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,4}))?$').firstMatch('$value');
  if (match == null) throw const FormatException('Invalid rate percentage.');
  return int.parse(match[1]!) * 10000 +
      int.parse((match[2] ?? '').padRight(4, '0'));
}

DateTime parseReferenceRateDate(Object? value) {
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}(?: 00:00:00)?$').hasMatch(value)) {
    throw const FormatException('Invalid reference rate date.');
  }
  final parts = value.substring(0, 10).split('-').map(int.parse).toList();
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    throw const FormatException('Invalid reference rate date.');
  }
  return date;
}

String referenceRateDateText(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
