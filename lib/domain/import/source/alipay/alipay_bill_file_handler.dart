import '../../../../core/money/money.dart';
import '../../import_models.dart';
import '../../port/import_file_reader.dart';
import '../../service/source_parsing_models.dart';
import 'alipay_bill_record.dart';
import 'alipay_file_type.dart';

class AlipayBillFileHandler {
  const AlipayBillFileHandler();

  static const requiredHeaders = {
    '交易时间',
    '交易分类',
    '交易对方',
    '对方账号',
    '商品说明',
    '收/支',
    '金额',
    '收/付款方式',
    '交易状态',
    '交易订单号',
    '商家订单号',
    '备注',
  };

  List<ImportIssue> validate({
    required String fileName,
    required ImportTabularSheet sheet,
  }) {
    if (sheet.headers.isEmpty || sheet.rows.every(_isBlankRow)) {
      return [_fatal('alipay_empty_sheet', '支付宝文件 $fileName 不包含交易明细。')];
    }
    if (!sheet.headers.toSet().containsAll(requiredHeaders)) {
      return [_fatal('alipay_unsupported_headers', '无法识别支付宝交易明细表头，请重新导出完整账单。')];
    }
    return const [];
  }

  SourceFileFact handle({
    required int fileIndex,
    required String fileName,
    required ImportTabularSheet sheet,
  }) {
    final records = [
      for (var index = 0; index < sheet.rows.length; index++)
        ?_normalize(sheet.rows[index], index + 1),
    ];
    return SourceFileFact(
      fileIndex: fileIndex,
      fileName: fileName,
      fileType: AlipayFileType.bill.descriptor,
      records: records,
      issues: records.expand((record) => record.issues),
    );
  }

  AlipayBillRecord? _normalize(Map<String, Object?> row, int rowNumber) {
    if (_isBlankRow(row)) return null;

    final direction = _text(row, '收/支');
    final status = _text(row, '交易状态');
    final issues = <ImportIssue>[];
    final filterReason = _filterReason(
      direction: direction,
      status: status,
      rowNumber: rowNumber,
      issues: issues,
    );
    if (filterReason != null) {
      return AlipayBillRecord(
        rowNumber: rowNumber,
        direction: direction,
        status: status,
        occurredAt: null,
        amount: null,
        categoryPath: null,
        paymentMethod: null,
        note: null,
        sourceOperationKey: null,
        filterReason: filterReason,
        issues: issues,
      );
    }

    final amount = _money(row['金额'], issues, rowNumber);
    if (amount?.minorUnits == 0) {
      return AlipayBillRecord(
        rowNumber: rowNumber,
        direction: direction,
        status: status,
        occurredAt: null,
        amount: null,
        categoryPath: null,
        paymentMethod: null,
        note: null,
        sourceOperationKey: null,
        filterReason: AlipayBillFilterReason.zeroAmount,
        issues: issues,
      );
    }
    final occurredAt = _date(row['交易时间'], issues, rowNumber);
    final operationKey = _text(row, '交易订单号');
    if (operationKey == null) {
      issues.add(
        _warning(
          'alipay_source_operation_key_missing',
          '交易订单号为空，将仅通过交易组指纹提示疑似重复。',
          rowNumber,
        ),
      );
    }
    return AlipayBillRecord(
      rowNumber: rowNumber,
      direction: direction,
      status: status,
      occurredAt: occurredAt,
      amount: amount,
      categoryPath: _text(row, '交易分类'),
      paymentMethod: _accountName(row),
      note: _note(row),
      sourceOperationKey: operationKey,
      filterReason: null,
      issues: issues,
    );
  }

  AlipayBillFilterReason? _filterReason({
    required String? direction,
    required String? status,
    required int rowNumber,
    required List<ImportIssue> issues,
  }) {
    if (direction == null ||
        (direction != '支出' && direction != '收入' && direction != '不计收支')) {
      issues.add(
        _warning(
          'alipay_direction_unknown',
          '支付宝收/支为空或无法识别，已跳过该记录。',
          rowNumber,
        ),
      );
      return AlipayBillFilterReason.unknownDirection;
    }
    if (direction == '不计收支') {
      return AlipayBillFilterReason.directionNotSupported;
    }
    if (status != '交易成功') {
      return AlipayBillFilterReason.transactionStatusNotSupported;
    }
    return null;
  }

  DateTime? _date(Object? value, List<ImportIssue> issues, int rowNumber) {
    final text = _textValue(value);
    if (text == null) {
      issues.add(_blocking('alipay_date_missing', '交易时间为空。', rowNumber));
      return null;
    }
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$',
    ).firstMatch(text);
    if (match == null) {
      issues.add(
        _blocking('alipay_date_invalid', '无法解析交易时间：$text。', rowNumber),
      );
      return null;
    }
    final parts = [
      for (var index = 1; index <= 6; index++) int.parse(match.group(index)!),
    ];
    final valueAsDate = DateTime(
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
      parts[5],
    );
    if (valueAsDate.year != parts[0] ||
        valueAsDate.month != parts[1] ||
        valueAsDate.day != parts[2] ||
        valueAsDate.hour != parts[3] ||
        valueAsDate.minute != parts[4] ||
        valueAsDate.second != parts[5]) {
      issues.add(
        _blocking('alipay_date_invalid', '无法解析交易时间：$text。', rowNumber),
      );
      return null;
    }
    return valueAsDate;
  }

  Money? _money(Object? value, List<ImportIssue> issues, int rowNumber) {
    final text = _textValue(value);
    if (text == null) {
      issues.add(_blocking('alipay_amount_missing', '金额为空。', rowNumber));
      return null;
    }
    final amount = Money.tryParse(text);
    if (amount == null) {
      issues.add(
        _blocking('alipay_amount_invalid', '无法解析金额：$text。', rowNumber),
      );
      return null;
    }
    if (amount.minorUnits < 0) {
      issues.add(_blocking('alipay_amount_invalid', '金额不能为负数。', rowNumber));
      return null;
    }
    return amount;
  }

  String? _note(Map<String, Object?> row) {
    final parts = [
      if (_text(row, '交易对方') case final value?) '交易对方：$value',
      if (_text(row, '商品说明') case final value?) '商品说明：$value',
      if (_text(row, '备注') case final value?) '备注：$value',
    ];
    return parts.isEmpty ? null : parts.join('；');
  }

  String? _accountName(Map<String, Object?> row) {
    final value = _text(row, '收/付款方式');
    if (value == null) return null;
    final account = value.split('&').first.trim();
    return account.isEmpty ? null : account;
  }
}

bool _isBlankRow(Map<String, Object?> row) =>
    row.values.every((value) => _textValue(value) == null);

String? _text(Map<String, Object?> row, String key) => _textValue(row[key]);

String? _textValue(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

ImportIssue _fatal(String code, String message) {
  return ImportIssue(
    code: code,
    message: message,
    severity: ImportIssueSeverity.fatal,
    fileType: AlipayFileType.bill.descriptor,
  );
}

ImportIssue _blocking(String code, String message, int rowNumber) {
  return ImportIssue(
    code: code,
    message: message,
    severity: ImportIssueSeverity.blocking,
    rowNumber: rowNumber,
    fileType: AlipayFileType.bill.descriptor,
  );
}

ImportIssue _warning(String code, String message, int rowNumber) {
  return ImportIssue(
    code: code,
    message: message,
    severity: ImportIssueSeverity.warning,
    rowNumber: rowNumber,
    fileType: AlipayFileType.bill.descriptor,
  );
}
