part of 'yimu_file_handlers.dart';

class YimuTransferFileHandler implements YimuFileHandler {
  const YimuTransferFileHandler();

  @override
  YimuFileType get fileType => YimuFileType.transfer;

  @override
  List<ImportIssue> validate({
    required String fileName,
    required ImportTabularSheet sheet,
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
    required ImportTabularSheet sheet,
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
    required ImportTabularSheet sheet,
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
    required ImportTabularSheet sheet,
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
