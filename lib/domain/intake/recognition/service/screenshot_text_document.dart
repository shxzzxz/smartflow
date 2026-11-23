import '../../../../core/money/money.dart';
import '../recognized_payment.dart';
import '../screenshot_scene_information.dart';

/// Layout utilities shared by the specialized and generic parsers.
class ScreenshotTextDocument {
  ScreenshotTextDocument(List<RecognizedTextBlock> blocks)
    : rows = _rows(blocks);
  final List<ScreenshotTextRow> rows;
  String get text => rows.map((row) => row.text).join('\n');

  List<ScreenshotTextRow> get headerRows {
    final index = rows.indexWhere((row) => _startsWithLabel(row.text));
    return index < 0 ? rows : rows.take(index).toList();
  }

  bool hasLabel(String label) =>
      rows.any((row) => row.text.replaceAll(' ', '').startsWith(label));

  ScreenshotTextValue? field(
    List<String> labels, {
    bool allowBelow = false,
    bool allowWrapped = false,
  }) {
    final orderedLabels = [...labels]
      ..sort((a, b) => b.length.compareTo(a.length));
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final compact = row.text.replaceAll(' ', '');
      for (final label in orderedLabels) {
        if (!compact.startsWith(label)) continue;
        if (_detailLabels.any(
          (longer) =>
              longer.length > label.length &&
              longer.startsWith(label) &&
              compact.startsWith(longer),
        )) {
          continue;
        }
        final end = RegExp(
          label.split('').join(r'\s*'),
        ).firstMatch(row.text)?.end;
        if (end == null) continue;
        // A category label is more specific than a prefix such as 商品.
        final categoryLabel = _categoryLabelMatch(row.text);
        if (categoryLabel != null && categoryLabel.end > end) continue;
        final value = _fieldValue(
          i,
          end,
          label: label,
          allowBelow: allowBelow,
          allowWrapped: allowWrapped,
        );
        if (value != null) return value;
      }
    }
    return null;
  }

  ScreenshotTextValue? categoryField() {
    for (var i = 0; i < rows.length; i++) {
      final match = _categoryLabelMatch(rows[i].text);
      if (match == null) continue;
      final value = _fieldValue(
        i,
        match.end,
        label: match[0]!.replaceAll(' ', ''),
        allowBelow: true,
      );
      if (value != null) return value;
    }
    return null;
  }

  ScreenshotTextValue? _fieldValue(
    int index,
    int labelEnd, {
    required String label,
    required bool allowBelow,
    bool allowWrapped = false,
  }) {
    final row = rows[index];
    final separator = RegExp(
      r'^\s*[:：]?\s*',
    ).matchAsPrefix(row.text.substring(labelEnd))!;
    final valueStart = labelEnd + separator.end;
    var value = row.text.substring(valueStart).trim();
    var confidence = row.confidence;
    var valueRowIndex = index;
    var valueLeft = _valueColumnLeft(row, valueStart);
    if (value.isEmpty && index + 1 < rows.length) {
      final next = rows[index + 1];
      final nearby =
          next.top - row.bottom < row.height * 1.5 &&
          next.top >= row.top &&
          !_startsWithLabel(next.text);
      if (nearby &&
          (next.left > row.left + row.height ||
              allowBelow && next.left >= row.left - row.height)) {
        value = next.text;
        valueRowIndex++;
        valueLeft = next.left;
        confidence = next.confidence < confidence
            ? next.confidence
            : confidence;
      }
    }
    if (allowWrapped && value.isNotEmpty) {
      while (valueRowIndex + 1 < rows.length) {
        final previous = rows[valueRowIndex];
        final next = rows[valueRowIndex + 1];
        final tolerance =
            (previous.height < next.height ? previous.height : next.height) *
            0.5;
        final aligned = valueLeft == null
            ? next.left > row.left + row.height
            : (next.left - valueLeft).abs() < tolerance;
        if (!aligned ||
            next.top < previous.top ||
            next.top - previous.bottom >= previous.height * 1.5 ||
            next.left <= row.left + row.height && _startsWithLabel(next.text)) {
          break;
        }
        value += next.text;
        confidence = next.confidence < confidence
            ? next.confidence
            : confidence;
        valueLeft ??= next.left;
        valueRowIndex++;
      }
    }
    value = value.replaceFirst(RegExp(r'\s*[>›〉]\s*$'), '').trim();
    return value.isEmpty
        ? null
        : ScreenshotTextValue(value, confidence, label: label);
  }

  ScreenshotAmount? headlineAmount() {
    final candidates = <({ScreenshotAmount value, double height})>[];
    for (final row in headerRows) {
      final compact = row.text.replaceAll(' ', '');
      final match = RegExp(
        r'^(支付成功|付款成功|支付完成|扣款成功|交易成功|收款成功|已收款)?([+-]?)[¥￥]?(\d[\d,]*\.\d{2})$',
      ).firstMatch(compact);
      if (match == null) continue;
      final amount = parseScreenshotAmount(match[3]);
      if (amount == null || amount.minorUnits <= 0) continue;
      candidates.add((
        value: ScreenshotAmount(
          amount: amount,
          text: row.text,
          confidence: row.confidence,
          direction: match[2] == '-'
              ? RecognizedPaymentDirection.expense
              : match[2] == '+'
              ? RecognizedPaymentDirection.income
              : null,
        ),
        height: row.height,
      ));
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.height.compareTo(a.height));
    if (candidates.length > 1 &&
        candidates.first.height < candidates[1].height * 1.25) {
      return null;
    }
    return candidates.first.value;
  }

  ScreenshotTextValue? headlineCounterparty(ScreenshotAmount? amount) {
    if (amount == null) return null;
    final index = rows.indexWhere((row) => row.text == amount.text);
    if (index <= 0) return null;
    final row = rows[index - 1];
    final sender = RegExp(
      r'^(?:转\s*账\s*-\s*)?来\s*自\s*(.+)$',
    ).firstMatch(row.text);
    if (sender != null) {
      return ScreenshotTextValue(sender[1]!.trim(), row.confidence);
    }
    if (RegExp(
      r'账单|详情|微信|支付宝|成功|完成|订单|优惠|立减|退款|转账|转入|转出|提现|还款|收款|到账|存入|余额|包装费|配送费|^支付$|^\d|^[+-]',
    ).hasMatch(row.text)) {
      return null;
    }
    return ScreenshotTextValue(row.text, row.confidence);
  }

  String sceneSignals({bool allowBelow = false}) => [
    ...headerRows.map((row) => row.text),
    field(const ['交易类型', '交易类别', '业务类型', '收支类型'], allowBelow: allowBelow)?.text,
    field(const ['当前状态', '交易状态', '支付状态', '状态'], allowBelow: allowBelow)?.text,
    if (hasLabel('转出金额')) '转出',
    ...rows
        .where(
          (row) => RegExp(
            r'^(支付失败|交易失败|付款失败|支付中|待支付|等待付款|已关闭|已取消|交易取消|支付成功|付款成功|支付完成|交易成功|收款成功|已收款|已到账|已存入零钱|退款成功|已全额退款|已退款|转账成功|转账到账|还款成功)$',
          ).hasMatch(_sceneMatchingText(row.text)),
        )
        .map((row) => row.text),
  ].whereType<String>().map(_sceneMatchingText).join('\n');

  DateTime? uniqueTime() {
    final dates = <DateTime>{};
    for (final row in rows) {
      if (_sceneMatchingText(row.text).contains('预计')) continue;
      for (final match in _datePattern.allMatches(_normalizeDate(row.text))) {
        final date = parseScreenshotDate(match.group(0));
        if (date != null) dates.add(date);
      }
    }
    return dates.length == 1 ? dates.single : null;
  }
}

class ScreenshotTextRow {
  ScreenshotTextRow(this.blocks);
  final List<RecognizedTextBlock> blocks;
  String get text =>
      blocks.map((block) => normalizeScreenshotText(block.text)).join(' ');
  double get left => blocks.first.left;
  double get top =>
      blocks.map((block) => block.top).reduce((a, b) => a < b ? a : b);
  double get bottom =>
      blocks.map((block) => block.bottom).reduce((a, b) => a > b ? a : b);
  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;
  double get confidence =>
      blocks.map((block) => block.confidence).reduce((a, b) => a < b ? a : b);
}

double? _valueColumnLeft(ScreenshotTextRow row, int valueStart) {
  var offset = 0;
  for (final block in row.blocks) {
    final length = normalizeScreenshotText(block.text).length;
    if (valueStart >= offset && valueStart < offset + length) {
      // A combined label/value block has no separate value-column coordinate.
      return valueStart == offset ? block.left : null;
    }
    offset += length + 1;
  }
  return null;
}

List<ScreenshotTextRow> _rows(List<RecognizedTextBlock> input) {
  final sorted =
      input
          .where((block) => block.text.trim().isNotEmpty && block.height > 0)
          .toList()
        ..sort((a, b) {
          final top = a.centerY.compareTo(b.centerY);
          return top == 0 ? a.left.compareTo(b.left) : top;
        });
  final rows = <ScreenshotTextRow>[];
  for (final block in sorted) {
    final row = rows.lastOrNull;
    if (row != null &&
        (row.centerY - block.centerY).abs() <
            (row.height < block.height ? row.height : block.height) * 0.5) {
      row.blocks.add(block);
    } else {
      rows.add(ScreenshotTextRow([block]));
    }
  }
  for (final row in rows) {
    row.blocks.sort((a, b) => a.left.compareTo(b.left));
  }
  return List.unmodifiable(rows);
}

const _detailLabels = [
  '原价',
  '优惠',
  '支付优惠',
  '订单金额',
  '商品金额',
  '立减',
  '折扣',
  '实付金额',
  '实际支付',
  '支付金额',
  '实付款',
  '实收金额',
  '实际到账',
  '到账金额',
  '扣款金额',
  '付款金额',
  '收款金额',
  '转出金额',
  '交易金额',
  '账户余额',
  '零钱余额',
  '零钱通余额',
  '当前状态',
  '交易状态',
  '支付状态',
  '状态',
  '支付时间',
  '交易时间',
  '转账时间',
  '转出时间',
  '转出资金',
  '收款时间',
  '付款时间',
  '入账时间',
  '时间',
  '商品说明',
  '商品名称',
  '商品信息',
  '商品',
  '交易说明',
  '交易备注',
  '转账说明',
  '付款方式',
  '支付方式',
  '收款方式',
  '付款账户',
  '支付账户',
  '收款账户',
  '收款账号',
  '到账银行卡',
  '支付渠道',
  '交易类型',
  '交易类别',
  '业务类型',
  '收支类型',
  '商户全称',
  '收款方全称',
  '交易对方',
  '商户名称',
  '收款方',
  '付款方',
  '商家',
  '商户',
  '交易单号',
  '转账单号',
  '商户单号',
  '订单号',
];

bool _startsWithLabel(String text) {
  final compact = text.replaceAll(' ', '');
  return _detailLabels.any(compact.startsWith) ||
      _categoryLabelMatch(text) != null;
}

final _categoryLabelPattern = RegExp(
  r'^(?:[\u3400-\u9fff]\s*)*?分\s*类(?=\s|[:：]|$)',
);

Match? _categoryLabelMatch(String text) {
  final match = _categoryLabelPattern.matchAsPrefix(text);
  if (match == null) return null;
  // The marker must belong to the label, rather than another field's value.
  for (final label in _detailLabels) {
    final other = RegExp(label.split('').join(r'\s*')).matchAsPrefix(text);
    if (other != null &&
        other.end < match.end &&
        RegExp(r'^[\s:：]').hasMatch(text.substring(other.end))) {
      return null;
    }
  }
  return match;
}

// Scene matching ignores word gaps while preserving row boundaries and raw fields.
String _sceneMatchingText(String text) =>
    text.replaceAll(RegExp(r'[^\S\r\n]+'), '');

Money? parseScreenshotAmount(String? value) {
  if (value == null) return null;
  final normalized = normalizeScreenshotText(
    value,
  ).replaceAll(RegExp(r'[¥￥,\s]'), '');
  if (!RegExp(r'^[+-]?\d+(\.\d{1,2})?$').hasMatch(normalized)) return null;
  return Money.tryParse(normalized)?.abs();
}

final _datePattern = RegExp(
  r'(\d{4})[-/年](\d{1,2})[-/月](\d{1,2})日?\s*(\d{1,2}):(\d{2})(?::(\d{2}))?',
);
String _normalizeDate(String value) => normalizeScreenshotText(
  value,
).replaceAllMapped(RegExp(r'\s*([年月日:/-])\s*'), (match) => match[1]!);

DateTime? parseScreenshotDate(String? value) {
  if (value == null) return null;
  if (_sceneMatchingText(value).contains('预计')) return null;
  final match = _datePattern.firstMatch(_normalizeDate(value));
  if (match == null) return null;
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match[i] ?? '0')];
  final date = DateTime(
    parts[0],
    parts[1],
    parts[2],
    parts[3],
    parts[4],
    parts[5],
  );
  if (date.year != parts[0] ||
      date.month != parts[1] ||
      date.day != parts[2] ||
      date.hour != parts[3] ||
      date.minute != parts[4] ||
      date.second != parts[5]) {
    return null;
  }
  return date;
}

String normalizeScreenshotText(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    buffer.writeCharCode(
      rune == 0x3000
          ? 0x20
          : rune >= 0xFF01 && rune <= 0xFF5E
          ? rune - 0xFEE0
          : rune,
    );
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[−–—]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
