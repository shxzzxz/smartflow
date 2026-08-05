import 'dart:math' as math;

class AppChartScale {
  const AppChartScale._(this.min, this.max, this.interval);

  factory AppChartScale.fromValues(
    List<double> values, {
    bool includeZero = false,
  }) {
    if (values.isEmpty) {
      throw ArgumentError.value(values, 'values', 'must not be empty');
    }
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    if (includeZero) {
      lo = math.min(lo, 0);
      hi = math.max(hi, 0);
    }
    if (lo == hi) {
      final pad = math.max(1.0, lo.abs() * .16);
      if (lo >= 0 && includeZero) {
        hi = lo + pad;
        lo = 0;
      } else {
        lo -= pad;
        hi += pad;
      }
    }
    final interval = _niceInterval(hi - lo);
    final niceLo = (lo / interval).floorToDouble() * interval;
    var niceHi = (hi / interval).ceilToDouble() * interval;
    if (niceHi == niceLo) niceHi = niceLo + interval;
    return AppChartScale._(niceLo, niceHi, interval);
  }

  final double min;
  final double max;
  final double interval;

  static double _niceInterval(double span) {
    final raw = span / 3;
    final magnitude =
        math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final fraction = raw / magnitude;
    final step =
        fraction <= 1
            ? 1.0
            : fraction <= 2
            ? 2.0
            : fraction <= 5
            ? 5.0
            : 10.0;
    return step * magnitude;
  }
}

String appChartAxisLabel(double value) {
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  if (abs >= 100000000) {
    return '$sign${_compactNumber(abs / 100000000)}亿';
  }
  if (abs >= 10000) {
    return '$sign${_compactNumber(abs / 10000)}万';
  }
  return '$sign${_compactNumber(abs)}';
}

String _compactNumber(double value) {
  var text = value.toStringAsFixed(2);
  while (text.contains('.') && (text.endsWith('0') || text.endsWith('.'))) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}
