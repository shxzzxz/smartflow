import '../../../../core/money/money.dart';
import '../../import_models.dart';
import '../../port/import_file_reader.dart';
import '../../service/source_parsing_models.dart';
import 'wechat_bill_record.dart';
import 'wechat_file_type.dart';

class WechatBillFileHandler {
  const WechatBillFileHandler();

  static const requiredHeaders = {
    '交易时间',
    '交易类型',
    '交易对方',
    '商品',
    '收/支',
    '金额(元)',
    '支付方式',
    '当前状态',
    '交易单号',
    '商户单号',
    '备注',
  };

  List<ImportIssue> validate({
    required String fileName,
    required ImportTabularSheet sheet,
  }) {
    if (sheet.headers.isEmpty || sheet.rows.every(_isBlankRow)) {
      return [_fatal('wechat_empty_sheet', '微信文件 $fileName 不包含交易明细。')];
    }
    if (!sheet.headers.toSet().containsAll(requiredHeaders)) {
      return [_fatal('wechat_unsupported_headers', '无法识别微信支付账单表头，请重新导出完整账单。')];
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
      fileType: WechatFileType.bill.descriptor,
      records: records,
      issues: records.expand((record) => record.issues),
    );
  }

  WechatBillRecord? _normalize(Map<String, Object?> row, int rowNumber) {
    if (_isBlankRow(row)) return null;

    final direction = _text(row, '收/支');
    final issues = <ImportIssue>[];
    final filterReason = _filterReason(
      direction: direction,
      rowNumber: rowNumber,
      issues: issues,
    );
    if (filterReason != null) {
      return WechatBillRecord(
        rowNumber: rowNumber,
        direction: direction,
        transactionType: _text(row, '交易类型'),
        counterparty: _text(row, '交易对方'),
        product: _content(row, '商品'),
        status: _text(row, '当前状态'),
        paymentMethod: _accountName(row),
        transactionId: _content(row, '交易单号'),
        merchantOrderId: _content(row, '商户单号'),
        occurredAt: null,
        amount: null,
        filterReason: filterReason,
        issues: issues,
      );
    }

    final amount = _money(row['金额(元)'], issues, rowNumber);
    if (amount?.minorUnits == 0) {
      return WechatBillRecord(
        rowNumber: rowNumber,
        direction: direction,
        transactionType: _text(row, '交易类型'),
        counterparty: _text(row, '交易对方'),
        product: _content(row, '商品'),
        status: _text(row, '当前状态'),
        paymentMethod: _accountName(row),
        transactionId: _content(row, '交易单号'),
        merchantOrderId: _content(row, '商户单号'),
        occurredAt: null,
        amount: null,
        filterReason: WechatBillFilterReason.zeroAmount,
        issues: issues,
      );
    }

    final occurredAt = _date(row['交易时间'], issues, rowNumber);
    final transactionId = _content(row, '交易单号');
    if (transactionId == null) {
      issues.add(
        _warning(
          'wechat_source_operation_key_missing',
          '交易单号为空，将仅通过交易组指纹提示疑似重复。',
          rowNumber,
        ),
      );
    }
    return WechatBillRecord(
      rowNumber: rowNumber,
      direction: direction,
      transactionType: _text(row, '交易类型'),
      counterparty: _text(row, '交易对方'),
      product: _content(row, '商品'),
      status: _text(row, '当前状态'),
      paymentMethod: _accountName(row),
      transactionId: transactionId,
      merchantOrderId: _content(row, '商户单号'),
      occurredAt: occurredAt,
      amount: amount,
      filterReason: null,
      issues: issues,
    );
  }

  WechatBillFilterReason? _filterReason({
    required String? direction,
    required int rowNumber,
    required List<ImportIssue> issues,
  }) {
    if (direction == '/') return WechatBillFilterReason.neutralDirection;
    if (direction != '收入' && direction != '支出') {
      issues.add(
        _warning('wechat_direction_unknown', '微信收/支为空或无法识别，已跳过该记录。', rowNumber),
      );
      return WechatBillFilterReason.unknownDirection;
    }
    return null;
  }

  DateTime? _date(Object? value, List<ImportIssue> issues, int rowNumber) {
    if (value is DateTime) return value;
    final text = _textValue(value);
    if (text == null) {
      issues.add(_blocking('wechat_date_missing', '交易时间为空。', rowNumber));
      return null;
    }
    final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
    if (parsed == null) {
      issues.add(
        _blocking('wechat_date_invalid', '无法解析交易时间：$text。', rowNumber),
      );
      return null;
    }
    return parsed;
  }

  Money? _money(Object? value, List<ImportIssue> issues, int rowNumber) {
    final text = _textValue(value);
    if (text == null) {
      issues.add(_blocking('wechat_amount_missing', '金额为空。', rowNumber));
      return null;
    }
    final amount = Money.tryParse(text.replaceAll(',', ''));
    if (amount == null) {
      issues.add(
        _blocking('wechat_amount_invalid', '无法解析金额：$text。', rowNumber),
      );
      return null;
    }
    if (amount.minorUnits < 0) {
      issues.add(_blocking('wechat_amount_invalid', '金额不能为负数。', rowNumber));
      return null;
    }
    return amount;
  }

  String? _accountName(Map<String, Object?> row) => _content(row, '支付方式');
}

bool _isBlankRow(Map<String, Object?> row) =>
    row.values.every((value) => _textValue(value) == null);

String? _text(Map<String, Object?> row, String key) => _textValue(row[key]);

String? _content(Map<String, Object?> row, String key) {
  final value = _text(row, key);
  return value == '/' ? null : value;
}

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
    fileType: WechatFileType.bill.descriptor,
  );
}

ImportIssue _blocking(String code, String message, int rowNumber) {
  return ImportIssue(
    code: code,
    message: message,
    severity: ImportIssueSeverity.blocking,
    rowNumber: rowNumber,
    fileType: WechatFileType.bill.descriptor,
  );
}

ImportIssue _warning(String code, String message, int rowNumber) {
  return ImportIssue(
    code: code,
    message: message,
    severity: ImportIssueSeverity.warning,
    rowNumber: rowNumber,
    fileType: WechatFileType.bill.descriptor,
  );
}
