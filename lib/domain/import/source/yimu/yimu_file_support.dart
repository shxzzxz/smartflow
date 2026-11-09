part of 'yimu_file_handlers.dart';

DateTime? _date(
  Object? value, {
  required YimuFileType fileType,
  required List<ImportIssue> issues,
  required int rowNumber,
  required bool required,
}) {
  if (value is DateTime) return value;
  final text = _textValue(value);
  if (text == null) {
    if (required) {
      issues.add(_issue(fileType, 'date_missing', '交易日期为空。', rowNumber));
    }
    return null;
  }
  final parsed = DateTime.tryParse(text.replaceAll('/', '-'));
  if (parsed != null) return parsed;
  if (required) {
    issues.add(_issue(fileType, 'date_invalid', '无法解析交易日期：$text', rowNumber));
  }
  return null;
}

Money? _money(
  Object? value, {
  required YimuFileType fileType,
  required List<ImportIssue> issues,
  required int rowNumber,
  required String fieldName,
  required bool required,
}) {
  final text = _textValue(value);
  if (text == null) {
    if (required) {
      issues.add(
        _issue(fileType, '${fieldName}_missing', '$fieldName为空。', rowNumber),
      );
    }
    return null;
  }
  final parsed = Money.tryParse(text);
  if (parsed != null) return parsed;
  issues.add(
    _issue(fileType, '${fieldName}_invalid', '无法解析$fieldName：$text', rowNumber),
  );
  return null;
}

Money? _optionalMoney(
  Object? value, {
  required YimuFileType fileType,
  required List<ImportIssue> issues,
  required int rowNumber,
  required String fieldName,
}) {
  final text = _textValue(value);
  if (text == null) return null;
  final parsed = Money.tryParse(text);
  if (parsed == null) {
    issues.add(
      _issue(
        fileType,
        '${fieldName}_invalid',
        '无法解析$fieldName：$text',
        rowNumber,
      ),
    );
    return null;
  }
  return parsed.minorUnits == 0 ? null : parsed;
}

DateTime _postedAt(
  Map<String, Object?> row,
  DateTime occurredAt, {
  required YimuFileType fileType,
  required List<ImportIssue> issues,
  required int rowNumber,
}) {
  const candidates = ['入账时间', '入账日期', '记账时间', '记账日期', '到账时间', '到账日期'];
  for (final candidate in candidates) {
    final value = row[candidate];
    if (_textValue(value) == null) continue;
    return _date(
          value,
          fileType: fileType,
          issues: issues,
          rowNumber: rowNumber,
          required: true,
        ) ??
        occurredAt;
  }
  return occurredAt;
}

ImportIssue _issue(
  YimuFileType fileType,
  String code,
  String message,
  int? rowNumber,
) {
  return ImportIssue(
    code: code,
    message: message,
    severity: ImportIssueSeverity.blocking,
    rowNumber: rowNumber,
    fileType: fileType.descriptor,
  );
}

List<ImportIssue> _validateSheet({
  required YimuFileType fileType,
  required String fileName,
  required ImportTabularSheet sheet,
  required Set<String> requiredHeaders,
}) {
  if (sheet.headers.isEmpty ||
      sheet.rows.isEmpty ||
      sheet.rows.every(_isBlankRow)) {
    return [
      ImportIssue(
        code: 'empty_sheet',
        message: '文件 $fileName 的工作表为空。',
        severity: ImportIssueSeverity.fatal,
        fileType: fileType.descriptor,
      ),
    ];
  }
  final headers = {...sheet.headers, for (final row in sheet.rows) ...row.keys};
  if (!headers.containsAll(requiredHeaders)) {
    return [
      ImportIssue(
        code: 'unsupported_headers',
        message: '${fileType.label}文件表头不受支持。',
        severity: ImportIssueSeverity.fatal,
        fileType: fileType.descriptor,
      ),
    ];
  }
  return const [];
}

String? _text(Map<String, Object?> row, String key) => _textValue(row[key]);

String? _textValue(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String? _categoryPath(Map<String, Object?> row) {
  final first = _text(row, '类别');
  final second = _text(row, '二级分类');
  if (first == null) return null;
  return second == null ? first : '$first / $second';
}

bool _hasText(
  Map<String, Object?> row,
  String first,
  String second,
  String third,
) {
  return _text(row, first) != null ||
      _text(row, second) != null ||
      _text(row, third) != null;
}

bool _isBlankRow(Map<String, Object?> row) =>
    row.values.every((value) => _textValue(value) == null);

String? _sourceOperationKey(Map<String, Object?> row, YimuFileType role) {
  const candidates = ['交易ID', '记录ID', '流水号', '操作ID', 'operation_id'];
  for (final candidate in candidates) {
    final value = _text(row, candidate);
    if (value != null) return '${role.name}:${_normalized(value)}';
  }
  return null;
}

bool _isNone(String value) {
  final normalized = _normalized(value);
  return normalized == '无账户' || normalized == 'none' || normalized == '无';
}

String _normalized(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

final _epoch = DateTime(1970, 1, 1);

const _billRequiredHeaders = {
  '日期',
  '收支类型',
  '金额',
  '类别',
  '二级分类',
  '账户',
  '退款',
  '报销账户',
  '报销金额',
  '报销明细',
  '备注',
  '其他',
};

const _movementRequiredHeaders = {
  '日期',
  '类型',
  '转出账户',
  '转入账户',
  '金额',
  '手续费',
  '备注',
};
