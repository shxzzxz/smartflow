import '../../../core/money/money.dart';
import '../import_models.dart';
import '../port/yimu_workbook_reader.dart';
import 'source_parsing_models.dart';
import 'yimu_file_type.dart';

abstract interface class YimuFileHandler {
  YimuFileType get fileType;

  List<ImportIssue> validate({
    required String fileName,
    required YimuSheet sheet,
  });

  SourceFileFact handle({
    required int fileIndex,
    required String fileName,
    required YimuSheet sheet,
  });
}

enum YimuBillFilterReason {
  reimbursementGap,
  repaymentInterest,
  repaymentDiscount,
}

extension YimuBillFilterReasonDescription on YimuBillFilterReason {
  String get reasonCode => switch (this) {
    YimuBillFilterReason.reimbursementGap => 'reimbursement_gap_generated',
    YimuBillFilterReason.repaymentInterest => 'repayment_interest_generated',
    YimuBillFilterReason.repaymentDiscount => 'repayment_discount_generated',
  };

  String get reason => switch (this) {
    YimuBillFilterReason.reimbursementGap => '报销差额是原报销交易自动生成的结果行。',
    YimuBillFilterReason.repaymentInterest => '还款利息应由转账或债务文件中的还款记录导入。',
    YimuBillFilterReason.repaymentDiscount => '还款优惠应由转账或债务文件中的还款记录导入。',
  };
}

class YimuReimbursementDetail {
  const YimuReimbursementDetail({
    required this.occurredAt,
    required this.amount,
    required this.accountName,
  });

  final DateTime? occurredAt;
  final Money? amount;
  final String? accountName;
}

sealed class YimuSourceRecord implements SourceRecord {
  YimuSourceRecord({
    required this.rowNumber,
    required this.sourceOperationKey,
    Iterable<ImportIssue> issues = const [],
  }) : issues = List.unmodifiable(issues);

  @override
  final int rowNumber;
  final String? sourceOperationKey;
  @override
  final List<ImportIssue> issues;
}

final class YimuBillRecord extends YimuSourceRecord {
  YimuBillRecord({
    required super.rowNumber,
    required super.sourceOperationKey,
    required this.kind,
    required this.occurredAt,
    required this.postedAt,
    required this.amount,
    this.categoryPath,
    this.accountName,
    this.refundSource,
    this.refundAmount,
    this.hasReimbursementFields = false,
    this.reimbursementAccountName,
    this.reimbursementAmountSource,
    this.reimbursementAmount,
    Iterable<YimuReimbursementDetail> reimbursementDetails = const [],
    this.reimbursementDetailsSource,
    this.note,
    this.other,
    this.filterReason,
    super.issues,
  }) : reimbursementDetails = List.unmodifiable(reimbursementDetails);

  final String? kind;
  final DateTime occurredAt;
  final DateTime postedAt;
  final Money amount;
  final String? categoryPath;
  final String? accountName;
  final String? refundSource;
  final Money? refundAmount;
  final bool hasReimbursementFields;
  final String? reimbursementAccountName;
  final String? reimbursementAmountSource;
  final Money? reimbursementAmount;
  final List<YimuReimbursementDetail> reimbursementDetails;
  final String? reimbursementDetailsSource;
  final String? note;
  final String? other;
  final YimuBillFilterReason? filterReason;
}

sealed class YimuAccountMovementRecord extends YimuSourceRecord {
  YimuAccountMovementRecord({
    required super.rowNumber,
    required super.sourceOperationKey,
    required this.kind,
    required this.occurredAt,
    required this.postedAt,
    required this.amount,
    required this.fromAccountName,
    required this.toAccountName,
    required this.feeAmount,
    required this.feeSource,
    required this.note,
    super.issues,
  });

  final String? kind;
  final DateTime occurredAt;
  final DateTime postedAt;
  final Money amount;
  final String? fromAccountName;
  final String? toAccountName;
  final Money? feeAmount;
  final String? feeSource;
  final String? note;
}

final class YimuTransferRecord extends YimuAccountMovementRecord {
  YimuTransferRecord({
    required super.rowNumber,
    required super.sourceOperationKey,
    required super.kind,
    required super.occurredAt,
    required super.postedAt,
    required super.amount,
    required super.fromAccountName,
    required super.toAccountName,
    required super.feeAmount,
    required super.feeSource,
    required super.note,
    super.issues,
  });
}

final class YimuDebtRecord extends YimuAccountMovementRecord {
  YimuDebtRecord({
    required super.rowNumber,
    required super.sourceOperationKey,
    required super.kind,
    required super.occurredAt,
    required super.postedAt,
    required super.amount,
    required super.fromAccountName,
    required super.toAccountName,
    required super.feeAmount,
    required super.feeSource,
    required super.note,
    super.issues,
  });
}

class YimuBillFileHandler implements YimuFileHandler {
  const YimuBillFileHandler();

  @override
  YimuFileType get fileType => YimuFileType.bill;

  @override
  List<ImportIssue> validate({
    required String fileName,
    required YimuSheet sheet,
  }) {
    return _validateSheet(
      fileType: fileType,
      fileName: fileName,
      sheet: sheet,
      requiredHeaders: _billRequiredHeaders,
    );
  }

  @override
  SourceFileFact handle({
    required int fileIndex,
    required String fileName,
    required YimuSheet sheet,
  }) {
    final records = [
      for (var index = 0; index < sheet.rows.length; index++)
        ?_normalizeBillRecord(sheet.rows[index], index + 2),
    ];
    return SourceFileFact(
      fileIndex: fileIndex,
      fileName: fileName,
      fileType: fileType.descriptor,
      records: records,
      // Bill entities are derived only after bundle-level filters run. This
      // prevents a generated transfer-fee result row from leaving behind an
      // unnecessary account/category mapping item.
      issues: records.expand((record) => record.issues),
    );
  }

  YimuBillRecord? _normalizeBillRecord(
    Map<String, Object?> row,
    int rowNumber,
  ) {
    if (_isBlankRow(row)) return null;
    final kind = _text(row, '收支类型');
    final note = _text(row, '备注');
    final filterReason = _filterReason(note);
    final issues = <ImportIssue>[];
    final shouldNormalizeTransaction = filterReason == null;
    final occurredAt = shouldNormalizeTransaction
        ? (_date(
                row['日期'],
                fileType: fileType,
                issues: issues,
                rowNumber: rowNumber,
                required: true,
              ) ??
              _epoch)
        : _epoch;
    final postedAt = shouldNormalizeTransaction
        ? _postedAt(
            row,
            occurredAt,
            fileType: fileType,
            issues: issues,
            rowNumber: rowNumber,
          )
        : occurredAt;
    final amount = shouldNormalizeTransaction
        ? (_money(
                row['金额'],
                fileType: fileType,
                issues: issues,
                rowNumber: rowNumber,
                fieldName: '金额',
                required: true,
              ) ??
              Money.zero())
        : Money.zero();
    final hasReimbursementFields =
        kind == '支出' && _hasText(row, '报销账户', '报销金额', '报销明细');
    Money? refundAmount;
    Money? reimbursementAmount;
    var reimbursementDetails = const <YimuReimbursementDetail>[];
    if (shouldNormalizeTransaction && kind == '支出') {
      refundAmount = _money(
        row['退款'],
        fileType: fileType,
        issues: issues,
        rowNumber: rowNumber,
        fieldName: '退款',
        required: false,
      );
      if (hasReimbursementFields) {
        reimbursementAmount = _money(
          row['报销金额'],
          fileType: fileType,
          issues: issues,
          rowNumber: rowNumber,
          fieldName: '报销金额',
          required: true,
        );
        reimbursementDetails = _reimbursementDetails(
          _text(row, '报销明细'),
          rowNumber: rowNumber,
          issues: issues,
        );
      }
    }
    if (shouldNormalizeTransaction && _text(row, '多币种') != null) {
      issues.add(
        _issue(
          fileType,
          'multi_currency_unsupported',
          '第一版导入不支持多币种金额。',
          rowNumber,
        ),
      );
    }
    return YimuBillRecord(
      rowNumber: rowNumber,
      sourceOperationKey: _sourceOperationKey(row, fileType),
      kind: kind,
      occurredAt: occurredAt,
      postedAt: postedAt,
      amount: amount,
      categoryPath: _categoryPath(row),
      accountName: _text(row, '账户'),
      refundSource: _text(row, '退款'),
      refundAmount: refundAmount,
      hasReimbursementFields: hasReimbursementFields,
      reimbursementAccountName: _text(row, '报销账户'),
      reimbursementAmountSource: _text(row, '报销金额'),
      reimbursementAmount: reimbursementAmount,
      reimbursementDetails: reimbursementDetails,
      reimbursementDetailsSource: _text(row, '报销明细'),
      note: note,
      other: _text(row, '其他'),
      filterReason: filterReason,
      issues: issues,
    );
  }

  YimuBillFilterReason? _filterReason(String? note) {
    if (note?.startsWith('报销差额') == true) {
      return YimuBillFilterReason.reimbursementGap;
    }
    if (note?.contains('还款利息') == true) {
      return YimuBillFilterReason.repaymentInterest;
    }
    if (note?.contains('还款优惠') == true) {
      return YimuBillFilterReason.repaymentDiscount;
    }
    return null;
  }

  List<YimuReimbursementDetail> _reimbursementDetails(
    String? value, {
    required int rowNumber,
    required List<ImportIssue> issues,
  }) {
    if (value == null || value.trim().isEmpty) return const [];
    final details = <YimuReimbursementDetail>[];
    for (final line in value.split(RegExp(r'[\r\n]+'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = RegExp(
        r'^(\d{4}/\d{2}/\d{2})(.+?)到账\s*([+-]?\d+(?:\.\d+)?)$',
      ).firstMatch(trimmed);
      if (match == null) {
        issues.add(
          _issue(
            fileType,
            'reimbursement_detail_invalid',
            '无法解析报销明细：$trimmed',
            rowNumber,
          ),
        );
        continue;
      }
      final date = _date(
        match.group(1),
        fileType: fileType,
        issues: issues,
        rowNumber: rowNumber,
        required: true,
      );
      final amount = _money(
        match.group(3),
        fileType: fileType,
        issues: issues,
        rowNumber: rowNumber,
        fieldName: '报销明细金额',
        required: true,
      );
      details.add(
        YimuReimbursementDetail(
          occurredAt: date,
          amount: amount,
          accountName: _textValue(match.group(2)),
        ),
      );
    }
    return details;
  }
}

class YimuTransferFileHandler implements YimuFileHandler {
  const YimuTransferFileHandler();

  @override
  YimuFileType get fileType => YimuFileType.transfer;

  @override
  List<ImportIssue> validate({
    required String fileName,
    required YimuSheet sheet,
  }) {
    return _validateSheet(
      fileType: fileType,
      fileName: fileName,
      sheet: sheet,
      requiredHeaders: _movementRequiredHeaders,
    );
  }

  @override
  SourceFileFact handle({
    required int fileIndex,
    required String fileName,
    required YimuSheet sheet,
  }) {
    final records = [
      for (var index = 0; index < sheet.rows.length; index++)
        if (_normalizeMovementRecord(sheet.rows[index], index + 2)
            case final record?)
          YimuTransferRecord(
            rowNumber: record.rowNumber,
            sourceOperationKey: record.sourceOperationKey,
            kind: record.kind,
            occurredAt: record.occurredAt,
            postedAt: record.postedAt,
            amount: record.amount,
            fromAccountName: record.fromAccountName,
            toAccountName: record.toAccountName,
            feeAmount: record.feeAmount,
            feeSource: record.feeSource,
            note: record.note,
            issues: record.issues,
          ),
    ];
    return SourceFileFact(
      fileIndex: fileIndex,
      fileName: fileName,
      fileType: fileType.descriptor,
      records: records,
      localEntities: _movementEntities(records, fileType: fileType),
      issues: records.expand((record) => record.issues),
    );
  }

  YimuAccountMovementRecord? _normalizeMovementRecord(
    Map<String, Object?> row,
    int rowNumber,
  ) {
    if (_isBlankRow(row)) return null;
    return _normalizeMovement(row, rowNumber, fileType: fileType);
  }
}

class YimuDebtFileHandler implements YimuFileHandler {
  const YimuDebtFileHandler();

  @override
  YimuFileType get fileType => YimuFileType.debt;

  @override
  List<ImportIssue> validate({
    required String fileName,
    required YimuSheet sheet,
  }) {
    return _validateSheet(
      fileType: fileType,
      fileName: fileName,
      sheet: sheet,
      requiredHeaders: _movementRequiredHeaders,
    );
  }

  @override
  SourceFileFact handle({
    required int fileIndex,
    required String fileName,
    required YimuSheet sheet,
  }) {
    final records = [
      for (var index = 0; index < sheet.rows.length; index++)
        if (_normalizeMovementRecord(sheet.rows[index], index + 2)
            case final record?)
          YimuDebtRecord(
            rowNumber: record.rowNumber,
            sourceOperationKey: record.sourceOperationKey,
            kind: record.kind,
            occurredAt: record.occurredAt,
            postedAt: record.postedAt,
            amount: record.amount,
            fromAccountName: record.fromAccountName,
            toAccountName: record.toAccountName,
            feeAmount: record.feeAmount,
            feeSource: record.feeSource,
            note: record.note,
            issues: record.issues,
          ),
    ];
    return SourceFileFact(
      fileIndex: fileIndex,
      fileName: fileName,
      fileType: fileType.descriptor,
      records: records,
      localEntities: _movementEntities(records, fileType: fileType),
      issues: records.expand((record) => record.issues),
    );
  }

  YimuAccountMovementRecord? _normalizeMovementRecord(
    Map<String, Object?> row,
    int rowNumber,
  ) {
    if (_isBlankRow(row)) return null;
    return _normalizeMovement(row, rowNumber, fileType: fileType);
  }
}

YimuAccountMovementRecord _normalizeMovement(
  Map<String, Object?> row,
  int rowNumber, {
  required YimuFileType fileType,
}) {
  final kind = _text(row, '类型');
  final issues = <ImportIssue>[];
  final occurredAt =
      _date(
        row['日期'],
        fileType: fileType,
        issues: issues,
        rowNumber: rowNumber,
        required: true,
      ) ??
      _epoch;
  final postedAt = _postedAt(
    row,
    occurredAt,
    fileType: fileType,
    issues: issues,
    rowNumber: rowNumber,
  );
  final amount =
      _money(
        row['金额'],
        fileType: fileType,
        issues: issues,
        rowNumber: rowNumber,
        fieldName: '金额',
        required: true,
      ) ??
      Money.zero();
  final feeSource = _text(row, '手续费');
  final feeAmount = kind == '转账' || kind == '还款'
      ? _optionalMoney(
          row['手续费'],
          fileType: fileType,
          issues: issues,
          rowNumber: rowNumber,
          fieldName: '手续费',
        )
      : null;
  return _NormalizedMovementRecord(
    rowNumber: rowNumber,
    sourceOperationKey: _sourceOperationKey(row, fileType),
    kind: kind,
    occurredAt: occurredAt,
    postedAt: postedAt,
    amount: amount,
    fromAccountName: _text(row, '转出账户'),
    toAccountName: _text(row, '转入账户'),
    feeAmount: feeAmount,
    feeSource: feeSource,
    note: _text(row, '备注'),
    issues: issues,
  );
}

final class _NormalizedMovementRecord extends YimuAccountMovementRecord {
  _NormalizedMovementRecord({
    required super.rowNumber,
    required super.sourceOperationKey,
    required super.kind,
    required super.occurredAt,
    required super.postedAt,
    required super.amount,
    required super.fromAccountName,
    required super.toAccountName,
    required super.feeAmount,
    required super.feeSource,
    required super.note,
    super.issues,
  });
}

Iterable<ImportSourceEntity> _movementEntities(
  Iterable<YimuAccountMovementRecord> records, {
  required YimuFileType fileType,
}) sync* {
  for (final record in records) {
    final kind = record.kind;
    final from = record.fromAccountName;
    final to = record.toAccountName;
    if (kind == '转账') {
      if (from != null && !_isNone(from)) {
        yield _accountEntity(
          from,
          allowed: const {ImportTargetDescriptor.fundAccount},
          preferred: ImportTargetDescriptor.fundAccount,
        );
      }
      if (to != null && !_isNone(to)) {
        yield _accountEntity(
          to,
          allowed: const {ImportTargetDescriptor.fundAccount},
          preferred: ImportTargetDescriptor.fundAccount,
        );
      }
      continue;
    }
    if (kind == '还款' || kind == '借入') {
      if (from != null && !_isNone(from)) {
        yield _accountEntity(
          from,
          allowed: const {ImportTargetDescriptor.fundAccount},
          preferred: ImportTargetDescriptor.fundAccount,
        );
      }
      if (to != null && !_isNone(to)) {
        final allowed = fileType == YimuFileType.transfer
            ? const {
                ImportTargetDescriptor.payableAccount,
                ImportTargetDescriptor.creditAccount,
                ImportTargetDescriptor.loanAccount,
              }
            : const {
                ImportTargetDescriptor.payableAccount,
                ImportTargetDescriptor.loanAccount,
              };
        yield _accountEntity(
          to,
          allowed: allowed,
          preferred: fileType == YimuFileType.transfer
              ? ImportTargetDescriptor.creditAccount
              : ImportTargetDescriptor.payableAccount,
        );
      }
      continue;
    }
    if (fileType == YimuFileType.debt && (kind == '借出' || kind == '收款')) {
      if (from != null && !_isNone(from)) {
        yield _accountEntity(
          from,
          allowed: const {ImportTargetDescriptor.fundAccount},
          preferred: ImportTargetDescriptor.fundAccount,
        );
      }
      if (to != null && !_isNone(to)) {
        yield _accountEntity(
          to,
          allowed: const {ImportTargetDescriptor.receivableAccount},
          preferred: ImportTargetDescriptor.receivableAccount,
        );
      }
    }
  }
}

ImportSourceEntity _accountEntity(
  String name, {
  Set<ImportTargetDescriptor> allowed = const {},
  ImportTargetDescriptor? preferred,
}) {
  return ImportSourceEntity(
    source: ImportSource.yimu,
    kind: ImportEntityKind.account,
    sourceEntityKey: 'account:${_normalized(name)}',
    displayName: name.trim(),
    allowedTargetDescriptors: allowed,
    preferredTargetDescriptor: preferred,
  );
}

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
  required YimuSheet sheet,
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
