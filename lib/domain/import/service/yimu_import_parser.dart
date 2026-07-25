import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/money/money.dart';
import '../import_models.dart';
import '../port/import_source_parser.dart';
import '../port/yimu_workbook_reader.dart';
import 'source_parsing_models.dart';
import 'yimu_file_handlers.dart';
import 'yimu_file_type.dart';

const yimuFingerprintVersion = 1;

/// Deterministic, side-effect-free parser for the three files exported by
/// 一木记账. Spreadsheet decoding is deliberately injected through
/// [YimuWorkbookReader], keeping BIFF/OLE concerns outside this domain.
class YimuImportParser implements ImportSourceParser {
  YimuImportParser({
    required YimuWorkbookReader reader,
    Iterable<YimuFileHandler> fileHandlers = const [
      YimuBillFileHandler(),
      YimuTransferFileHandler(),
      YimuDebtFileHandler(),
    ],
    Iterable<ParseUnit> additionalParseUnits = const [],
    ImportPlanAssembler assembler = const ImportPlanAssembler(),
  }) : _reader = reader,
       _assembler = assembler,
       _additionalParseUnits = List.unmodifiable(additionalParseUnits),
       _fileHandlers = {
         for (final handler in fileHandlers) handler.fileType: handler,
       };

  static const fingerprintVersion = yimuFingerprintVersion;

  final YimuWorkbookReader _reader;
  final ImportPlanAssembler _assembler;
  final List<ParseUnit> _additionalParseUnits;
  final Map<YimuFileType, YimuFileHandler> _fileHandlers;

  @override
  ImportSource get source => ImportSource.yimu;

  @override
  ImportParseResult parse(ImportBundle bundle) {
    final fatalIssues = <ImportIssue>[];
    final factsByType = <ImportSourceFileType, SourceFileFact>{};
    final acceptedFileIndexByRole = <YimuFileType, int>{};
    final fileResults = [
      for (var index = 0; index < bundle.files.length; index++)
        _MutableImportFileParseResult(
          fileIndex: index,
          fileName: bundle.files[index].name,
        ),
    ];

    for (var fileIndex = 0; fileIndex < bundle.files.length; fileIndex++) {
      final file = bundle.files[fileIndex];
      final fileResult = fileResults[fileIndex];

      void addFileIssue(ImportIssue issue) {
        fileResult.fatalIssues.add(issue);
      }

      final normalizedName = file.name.trim().toLowerCase();
      if (!normalizedName.endsWith('.xls')) {
        addFileIssue(
          ImportIssue(
            code: 'unsupported_file_format',
            message: '一木导入只支持传统 .xls 文件：${file.name}',
            severity: ImportIssueSeverity.fatal,
          ),
        );
        continue;
      }

      YimuWorkbook workbook;
      try {
        workbook = _reader.read(file);
      } on Exception {
        addFileIssue(
          ImportIssue(
            code: 'file_decode_failed',
            message: '无法读取一木文件 ${file.name}，请重新导出或选择有效的 .xls 文件。',
            severity: ImportIssueSeverity.fatal,
          ),
        );
        continue;
      }

      if (workbook.sheets.isEmpty) {
        addFileIssue(
          ImportIssue(
            code: 'empty_workbook',
            message: '文件 ${file.name} 不包含工作表。',
            severity: ImportIssueSeverity.fatal,
          ),
        );
        continue;
      }
      final sheet = workbook.sheets.first;
      final role = _detectRole(file.name, sheet);
      if (role == null) {
        addFileIssue(
          ImportIssue(
            code: 'unsupported_headers',
            message: '无法识别文件 ${file.name} 的一木文件角色或表头。',
            severity: ImportIssueSeverity.fatal,
          ),
        );
        continue;
      }
      fileResult.fileType = role.descriptor;
      final handler = _fileHandlers[role];
      if (handler == null) {
        addFileIssue(
          ImportIssue(
            code: 'file_handler_missing',
            message: '${_roleName(role)}文件暂不支持解析。',
            severity: ImportIssueSeverity.fatal,
            fileType: role.descriptor,
          ),
        );
        continue;
      }
      final validationIssues = handler.validate(
        fileName: file.name,
        sheet: sheet,
      );
      final emptySheetIssues = validationIssues.where(
        (issue) => issue.code == 'empty_sheet',
      );
      if (emptySheetIssues.isNotEmpty) {
        for (final issue in emptySheetIssues) {
          addFileIssue(issue);
        }
        continue;
      }
      if (factsByType.containsKey(role.descriptor)) {
        final issue = ImportIssue(
          code: 'duplicate_file_role',
          message: '一木资料包中重复选择了${_roleName(role)}文件。',
          severity: ImportIssueSeverity.fatal,
          fileType: role.descriptor,
        );
        fatalIssues.add(issue);
        fileResult.fatalIssues.add(issue);
        final acceptedIndex = acceptedFileIndexByRole[role];
        if (acceptedIndex != null) {
          fileResults[acceptedIndex].fatalIssues.add(issue);
        }
        continue;
      }
      if (validationIssues.isNotEmpty) {
        for (final issue in validationIssues) {
          addFileIssue(issue);
        }
        continue;
      }
      try {
        factsByType[role.descriptor] = handler.handle(
          fileIndex: fileIndex,
          fileName: file.name,
          sheet: sheet,
        );
        acceptedFileIndexByRole[role] = fileIndex;
      } on Exception {
        addFileIssue(
          ImportIssue(
            code: 'file_handler_failed',
            message: '无法解析一木文件 ${file.name} 的内容，请重新导出或选择有效文件。',
            severity: ImportIssueSeverity.fatal,
            fileType: role.descriptor,
          ),
        );
      }
    }

    if (factsByType.isEmpty && fatalIssues.isEmpty) {
      fatalIssues.add(
        const ImportIssue(
          code: 'no_usable_files',
          message: '资料包中没有可解析的一木记账文件。',
          severity: ImportIssueSeverity.fatal,
        ),
      );
    }

    if (fatalIssues.isNotEmpty) {
      return ImportParseResult(
        source: ImportSource.yimu,
        fileResults: fileResults.map((result) => result.freeze()),
        fatalIssues: fatalIssues,
      );
    }

    final executions = ParseUnitPlan([
      const YimuBillParseUnit(),
      const YimuTransferParseUnit(),
      const YimuDebtParseUnit(),
      ..._additionalParseUnits,
    ]).execute(factsByType);
    return _assembler.assemble(
      source: ImportSource.yimu,
      fileResults: fileResults.map((result) => result.freeze()),
      facts: factsByType.values,
      executions: executions,
    );
  }
}

void _parseBillRows(
  Iterable<YimuBillRecord> records, {
  required Map<String, ImportSourceEntity> entities,
  required List<ImportTransactionGroupDraft> groups,
  required List<ImportFilteredRecord> filtered,
}) {
  for (final record in records) {
    final rowNumber = record.rowNumber;
    final filterReason = record.filterReason;
    if (filterReason != null) {
      filtered.add(
        ImportFilteredRecord(
          reasonCode: filterReason.reasonCode,
          reason: filterReason.reason,
          fileType: YimuFileType.bill.descriptor,
          rowNumber: rowNumber,
        ),
      );
      continue;
    }

    final issues = [...record.issues];
    final kind = record.kind;
    final actualDate = record.occurredAt;
    final postedAt = record.postedAt;
    final actualAmount = record.amount;
    final path = record.categoryPath;
    final note = record.note;
    final other = record.other;
    final excludedFromStats = other?.contains('不计入收支') ?? false;
    final excludedFromBudget = other?.contains('不计入预算') ?? false;
    final operationKey = record.sourceOperationKey;
    final canonical = <String>[
      'role=bill',
      'type=${_normalized(kind)}',
      'date=${_canonicalDate(actualDate)}',
      'posted=${_canonicalDate(postedAt)}',
      'amount=${actualAmount.minorUnits}',
      'category=${_normalized(path)}',
      'account=${_normalized(record.accountName)}',
      'refund=${_normalized(record.refundSource)}',
      'receivable=${_normalized(record.reimbursementAccountName)}',
      'reimbursement=${_normalized(record.reimbursementAmountSource)}',
      'details=${_normalized(record.reimbursementDetailsSource)}',
      'note=${_normalized(note)}',
      'other=${_normalized(other)}',
    ];

    if (kind == '支出' && record.hasReimbursementFields) {
      groups.add(
        _parseReimbursement(
          record,
          rowNumber: rowNumber,
          amount: actualAmount,
          occurredAt: actualDate,
          postedAt: postedAt,
          path: path,
          note: note,
          excludedFromStats: excludedFromStats,
          excludedFromBudget: excludedFromBudget,
          issues: issues,
          entities: entities,
          operationKey: operationKey,
          canonical: canonical,
        ),
      );
      continue;
    }

    if (kind == '支出') {
      final category = _categoryReference(
        path,
        ImportCategoryKind.expense,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
      );
      final account = _accountReference(
        record.accountName,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
        allowExplicitNone: true,
        required: false,
      );
      final refund = record.refundAmount;
      if (refund != null && refund.minorUnits < 0) {
        issues.add(_blocking('refund_negative', '退款金额不能为负数。', rowNumber));
      }
      if (actualAmount.minorUnits == 0 && (refund?.minorUnits ?? 0) > 0) {
        issues.add(
          _blocking('expense_amount_zero', '退款记录缺少原始支出金额。', rowNumber),
        );
      }
      final gross = actualAmount.abs() + (refund?.abs() ?? Money.zero());
      final top = ImportExpenseDraft(
        amount: gross,
        paidFrom: account,
        category: category,
        occurredAt: actualDate,
        postedAt: postedAt,
        note: note,
        isExcludedFromStats: excludedFromStats,
        isExcludedFromBudget: excludedFromBudget,
      );
      final children = <ImportTransactionDraft>[
        if (refund != null && refund.minorUnits > 0)
          ImportRefundDraft(
            amount: refund,
            refundTo: account,
            occurredAt: actualDate,
            postedAt: postedAt,
            note: note,
          ),
      ];
      groups.add(
        _group(
          top,
          fileType: YimuFileType.bill,
          children: children,
          issues: issues,
          operationKey: operationKey,
          canonical: canonical,
        ),
      );
      continue;
    }

    if (kind == '收入') {
      final category = _categoryReference(
        path,
        ImportCategoryKind.income,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
      );
      final account = _accountReference(
        record.accountName,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
        allowExplicitNone: true,
        required: false,
      );
      if (actualAmount.minorUnits <= 0) {
        issues.add(_blocking('income_amount_invalid', '收入金额必须大于零。', rowNumber));
      }
      groups.add(
        _group(
          ImportIncomeDraft(
            amount: actualAmount.abs(),
            receiveAccount: account,
            category: category,
            occurredAt: actualDate,
            postedAt: postedAt,
            note: note,
            isExcludedFromStats: excludedFromStats,
            isExcludedFromBudget: excludedFromBudget,
          ),
          fileType: YimuFileType.bill,
          issues: issues,
          operationKey: operationKey,
          canonical: canonical,
        ),
      );
      continue;
    }

    issues.add(
      _blocking('unsupported_bill_type', '账单收支类型必须是收入或支出。', rowNumber),
    );
    groups.add(
      _group(
        ImportExpenseDraft(
          amount: actualAmount.abs(),
          paidFrom: ImportAccountReference.unresolved(),
          category: _fallbackCategory(ImportCategoryKind.expense),
          occurredAt: actualDate,
        ),
        fileType: YimuFileType.bill,
        issues: issues,
        operationKey: operationKey,
        canonical: canonical,
      ),
    );
  }
}

ImportTransactionGroupDraft _parseReimbursement(
  YimuBillRecord record, {
  required int rowNumber,
  required Money amount,
  required DateTime occurredAt,
  required DateTime postedAt,
  required String? path,
  required String? note,
  required bool excludedFromStats,
  required bool excludedFromBudget,
  required List<ImportIssue> issues,
  required Map<String, ImportSourceEntity> entities,
  required String? operationKey,
  required List<String> canonical,
}) {
  final category = _categoryReference(
    path,
    ImportCategoryKind.expense,
    entities: entities,
    issues: issues,
    rowNumber: rowNumber,
  );
  final paidFrom = _accountReference(
    record.accountName,
    entities: entities,
    issues: issues,
    rowNumber: rowNumber,
    required: true,
    fileType: YimuFileType.bill,
    fieldKey: 'account',
    fieldName: '账户',
  );
  final receivable = _accountReference(
    record.reimbursementAccountName,
    entities: entities,
    issues: issues,
    rowNumber: rowNumber,
    required: true,
    fileType: YimuFileType.bill,
    fieldKey: 'reimbursement',
    fieldName: '报销账户',
  );
  final reimbursementAmount = record.reimbursementAmount;
  final details = [
    for (final detail in record.reimbursementDetails)
      if (detail.occurredAt != null && detail.amount != null)
        _ReimbursementDetail(
          date: detail.occurredAt!,
          account: _accountReference(
            detail.accountName,
            entities: entities,
            issues: issues,
            rowNumber: rowNumber,
            required: true,
            fileType: YimuFileType.bill,
            fieldKey: 'reimbursement_detail_account',
            fieldName: '报销明细到账账户',
          ),
          amount: detail.amount!.abs(),
        ),
  ];
  if (details.isEmpty) {
    issues.add(
      _blocking('reimbursement_details_missing', '报销记录缺少有效报销明细。', rowNumber),
    );
  }
  if (reimbursementAmount != null) {
    final detailTotal = details.fold(
      Money.zero(),
      (sum, item) => sum + item.amount,
    );
    if (detailTotal != reimbursementAmount) {
      issues.add(
        _blocking(
          'reimbursement_amount_mismatch',
          '报销金额与报销明细到账合计不一致。',
          rowNumber,
        ),
      );
    }
  }

  final top = ImportReimbursementAdvanceDraft(
    amount: amount.abs(),
    receivableAccount: receivable,
    paidFrom: paidFrom,
    category: category,
    occurredAt: occurredAt,
    postedAt: postedAt,
    note: note,
    isExcludedFromStats: excludedFromStats,
    isExcludedFromBudget: excludedFromBudget,
  );
  final children = <ImportTransactionDraft>[];
  if (details.isNotEmpty) {
    for (var index = 0; index < details.length - 1; index++) {
      final detail = details[index];
      children.add(
        ImportReimbursementReceiptDraft(
          amount: detail.amount,
          receivableAccount: receivable,
          receiveAccount: detail.account,
          occurredAt: detail.date,
          note: note,
        ),
      );
    }
    final last = details.last;
    children.add(
      ImportReimbursementCloseDraft(
        actualReceivedAmount: last.amount,
        receivableAccount: receivable,
        receiveAccount: last.account,
        occurredAt: last.date,
        note: note,
      ),
    );
  } else {
    children.add(
      ImportReimbursementCloseDraft(
        actualReceivedAmount: Money.zero(),
        receivableAccount: receivable,
        receiveAccount: ImportAccountReference.unresolved(),
        occurredAt: occurredAt,
        note: note,
      ),
    );
  }
  return _group(
    top,
    fileType: YimuFileType.bill,
    children: children,
    issues: issues,
    operationKey: operationKey,
    canonical: canonical,
  );
}

void _parseTransferRows(
  Iterable<YimuAccountMovementRecord> records, {
  required YimuFileType role,
  required Map<String, ImportSourceEntity> entities,
  required List<ImportTransactionGroupDraft> groups,
}) {
  for (final record in records) {
    final rowNumber = record.rowNumber;
    final issues = [...record.issues];
    final type = record.kind;
    final actualDate = record.occurredAt;
    final postedAt = record.postedAt;
    final actualAmount = record.amount;
    final note = record.note;
    final fromValue = record.fromAccountName;
    final toValue = record.toAccountName;
    final operationKey = record.sourceOperationKey;
    final canonical = <String>[
      'role=${role.name}',
      'type=${_normalized(type)}',
      'date=${_canonicalDate(actualDate)}',
      'posted=${_canonicalDate(postedAt)}',
      'from=${_normalized(fromValue)}',
      'to=${_normalized(toValue)}',
      'amount=${actualAmount.minorUnits}',
      'fee=${_normalized(record.feeSource)}',
      'note=${_normalized(note)}',
    ];

    if (type == '转账') {
      final from = _accountReference(
        fromValue,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
        required: true,
        fileType: role,
        fieldKey: 'from',
        fieldName: '转出账户',
        allowedTargetDescriptors: const {ImportTargetDescriptor.fundAccount},
        preferredTargetDescriptor: ImportTargetDescriptor.fundAccount,
      );
      final to = _accountReference(
        toValue,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
        required: true,
        fileType: role,
        fieldKey: 'to',
        fieldName: '转入账户',
        allowedTargetDescriptors: const {ImportTargetDescriptor.fundAccount},
        preferredTargetDescriptor: ImportTargetDescriptor.fundAccount,
      );
      final fee = record.feeAmount;
      if (actualAmount.minorUnits <= 0) {
        issues.add(
          _blocking('transfer_amount_invalid', '转账金额必须大于零。', rowNumber),
        );
      }
      groups.add(
        _group(
          ImportTransferDraft(
            amount: actualAmount.abs(),
            fromAccount: from,
            toAccount: to,
            feeAmount: fee,
            occurredAt: actualDate,
            postedAt: postedAt,
            note: note,
          ),
          fileType: role,
          issues: issues,
          operationKey: operationKey,
          canonical: canonical,
        ),
      );
      continue;
    }

    if (type == '还款') {
      final paidFrom = _accountReference(
        fromValue,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
        required: true,
        fileType: role,
        fieldKey: 'from',
        fieldName: '转出账户',
        allowedTargetDescriptors: const {ImportTargetDescriptor.fundAccount},
        preferredTargetDescriptor: ImportTargetDescriptor.fundAccount,
      );
      final liability = _accountReference(
        toValue,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
        required: true,
        fileType: role,
        fieldKey: 'to',
        fieldName: '转入账户',
        allowedTargetDescriptors:
            role == YimuFileType.debt
                ? const {ImportTargetDescriptor.loanAccount}
                : const {},
        preferredTargetDescriptor:
            role == YimuFileType.debt
                ? ImportTargetDescriptor.loanAccount
                : null,
      );
      final fee = record.feeAmount;
      if (actualAmount.minorUnits == 0 && (fee?.minorUnits ?? 0) > 0) {
        groups.add(
          _group(
            ImportInterestExpenseDraft(
              amount: fee!,
              paidFrom: paidFrom,
              occurredAt: actualDate,
              postedAt: postedAt,
              note: note,
            ),
            fileType: role,
            issues: issues,
            operationKey: operationKey,
            canonical: canonical,
          ),
        );
      } else {
        if (actualAmount.minorUnits <= 0) {
          issues.add(
            _blocking('repayment_principal_invalid', '还款本金必须大于零。', rowNumber),
          );
        }
        groups.add(
          _group(
            ImportRepaymentDraft(
              principal: actualAmount.abs(),
              interest: fee,
              liabilityAccount: liability,
              paidFrom: paidFrom,
              occurredAt: actualDate,
              postedAt: postedAt,
              note: note,
            ),
            fileType: role,
            issues: issues,
            operationKey: operationKey,
            canonical: canonical,
          ),
        );
      }
      continue;
    }

    if (type == '借入' && role == YimuFileType.debt) {
      final liability = _accountReference(
        toValue,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
        required: true,
        fileType: role,
        fieldKey: 'to',
        fieldName: '转入账户',
        allowedTargetDescriptors: const {ImportTargetDescriptor.loanAccount},
        preferredTargetDescriptor: ImportTargetDescriptor.loanAccount,
      );
      final isOpening = fromValue == null || _isExplicitNone(fromValue);
      if (isOpening) {
        if (actualAmount.minorUnits <= 0) {
          issues.add(
            _blocking('opening_amount_invalid', '债务期初金额必须大于零。', rowNumber),
          );
        }
        groups.add(
          _group(
            ImportOpeningBalanceDraft(
              amount: actualAmount.abs(),
              liabilityAccount: liability,
              occurredAt: actualDate,
              postedAt: postedAt,
              note: note,
            ),
            fileType: role,
            issues: issues,
            operationKey: operationKey,
            canonical: canonical,
          ),
        );
      } else {
        final receive = _accountReference(
          fromValue,
          entities: entities,
          issues: issues,
          rowNumber: rowNumber,
          required: true,
          fileType: role,
          fieldKey: 'from',
          fieldName: '转出账户',
          allowedTargetDescriptors: const {ImportTargetDescriptor.fundAccount},
          preferredTargetDescriptor: ImportTargetDescriptor.fundAccount,
        );
        if (actualAmount.minorUnits <= 0) {
          issues.add(
            _blocking('borrowing_amount_invalid', '借入金额必须大于零。', rowNumber),
          );
        }
        groups.add(
          _group(
            ImportBorrowingDraft(
              amount: actualAmount.abs(),
              liabilityAccount: liability,
              receiveAccount: receive,
              occurredAt: actualDate,
              postedAt: postedAt,
              note: note,
            ),
            fileType: role,
            issues: issues,
            operationKey: operationKey,
            canonical: canonical,
          ),
        );
      }
      continue;
    }

    issues.add(
      _blocking(
        'unsupported_transfer_type',
        '${_roleName(role)}文件类型不受支持。',
        rowNumber,
      ),
    );
    groups.add(
      _group(
        ImportTransferDraft(
          amount: actualAmount.abs(),
          fromAccount: ImportAccountReference.unresolved(),
          toAccount: ImportAccountReference.unresolved(),
          occurredAt: actualDate,
          note: note,
        ),
        fileType: role,
        issues: issues,
        operationKey: operationKey,
        canonical: canonical,
      ),
    );
  }
}

ImportTransactionGroupDraft _group(
  ImportTransactionDraft top, {
  required YimuFileType fileType,
  Iterable<ImportTransactionDraft> children = const [],
  required Iterable<ImportIssue> issues,
  required String? operationKey,
  required Iterable<String> canonical,
}) {
  final locatedIssues = [
    for (final issue in issues)
      issue.fileType != null
          ? issue
          : ImportIssue(
            code: issue.code,
            message: issue.message,
            severity: issue.severity,
            rowNumber: issue.rowNumber,
            fileType: fileType.descriptor,
          ),
  ];
  final canonicalText = [
    ...canonical,
    'top=${_canonicalDraft(top)}',
    for (final child in children) 'child=${_canonicalDraft(child)}',
  ].join('|');
  final fingerprint = sha256.convert(utf8.encode(canonicalText)).toString();
  return ImportTransactionGroupDraft(
    topLevel: top,
    children: children,
    sourceOperationKey: operationKey,
    sourceOperationFingerprint: fingerprint,
    fingerprintVersion: yimuFingerprintVersion,
    issues: locatedIssues,
  );
}

ImportCategoryReference _categoryReference(
  String? path,
  ImportCategoryKind kind, {
  required Map<String, ImportSourceEntity> entities,
  required List<ImportIssue> issues,
  required int rowNumber,
}) {
  final display = path?.trim();
  if (display == null || display.isEmpty) {
    issues.add(_blocking('category_missing', '来源类别为空。', rowNumber));
    final key = 'review:missing:category:${kind.name}:bill:$rowNumber';
    final label = kind == ImportCategoryKind.income ? '缺失收入分类' : '缺失支出分类';
    _mergeSourceEntity(
      entities,
      ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.category,
        sourceEntityKey: key,
        displayName: '$label（账单文件第 $rowNumber 行）',
        categoryKind: kind,
        isReviewPlaceholder: true,
      ),
    );
    return ImportCategoryReference(
      sourceEntityKey: key,
      path: '<缺失分类>',
      kind: kind,
    );
  }
  final key = _categoryKey(kind, display);
  _mergeSourceEntity(
    entities,
    ImportSourceEntity(
      source: ImportSource.yimu,
      kind: ImportEntityKind.category,
      sourceEntityKey: key,
      displayName: display,
      categoryKind: kind,
    ),
  );
  return ImportCategoryReference(
    sourceEntityKey: key,
    path: display,
    kind: kind,
  );
}

ImportCategoryReference _fallbackCategory(ImportCategoryKind kind) {
  final path = '<未映射>';
  return ImportCategoryReference(
    sourceEntityKey: _categoryKey(kind, path),
    path: path,
    kind: kind,
  );
}

ImportAccountReference _accountReference(
  String? value, {
  required Map<String, ImportSourceEntity> entities,
  required List<ImportIssue> issues,
  required int rowNumber,
  required bool required,
  bool allowExplicitNone = false,
  YimuFileType? fileType,
  String fieldKey = 'account',
  String fieldName = '账户',
  Set<ImportTargetDescriptor> allowedTargetDescriptors = const {},
  ImportTargetDescriptor? preferredTargetDescriptor,
}) {
  final display = value?.trim();
  final isExplicitNone = display != null && _isExplicitNone(display);
  if (display == null || display.isEmpty || isExplicitNone) {
    if (allowExplicitNone || !required) {
      return const ImportAccountReference.explicitNone();
    }
    final role = fileType ?? YimuFileType.bill;
    final key = 'review:missing:account:${role.name}:$rowNumber:$fieldKey';
    final label =
        isExplicitNone
            ? '$fieldName明确为无账户（${_roleName(role)}文件第 $rowNumber 行）'
            : '缺失$fieldName（${_roleName(role)}文件第 $rowNumber 行）';
    _mergeSourceEntity(
      entities,
      ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.account,
        sourceEntityKey: key,
        displayName: label,
        isReviewPlaceholder: true,
        allowedTargetDescriptors: allowedTargetDescriptors,
        preferredTargetDescriptor: preferredTargetDescriptor,
      ),
    );
    issues.add(
      _blocking(
        isExplicitNone
            ? 'account_explicit_none_not_allowed'
            : 'account_missing',
        isExplicitNone ? '$fieldName不能使用无账户。' : '$fieldName为空或未提供。',
        rowNumber,
      ),
    );
    return ImportAccountReference.unresolved(
      sourceEntityKey: key,
      displayName: label,
    );
  }
  final key = _accountKey(display);
  _mergeSourceEntity(
    entities,
    ImportSourceEntity(
      source: ImportSource.yimu,
      kind: ImportEntityKind.account,
      sourceEntityKey: key,
      displayName: display,
      allowedTargetDescriptors: allowedTargetDescriptors,
      preferredTargetDescriptor: preferredTargetDescriptor,
    ),
  );
  return ImportAccountReference.source(
    sourceEntityKey: key,
    displayName: display,
  );
}

YimuFileType? _detectRole(String fileName, YimuSheet sheet) {
  final name = fileName.toLowerCase();
  if (name.contains('账单')) return YimuFileType.bill;
  if (name.contains('转账')) return YimuFileType.transfer;
  if (name.contains('债务')) return YimuFileType.debt;
  final headers = _headers(sheet);
  if (headers.contains('收支类型')) return YimuFileType.bill;
  if (headers.contains('类型') &&
      headers.contains('转出账户') &&
      headers.contains('转入账户')) {
    final types = sheet.rows.map((row) => _text(row, '类型')).whereType<String>();
    if (types.contains('借入')) return YimuFileType.debt;
    if (types.contains('转账')) return YimuFileType.transfer;
  }
  return null;
}

Set<String> _headers(YimuSheet sheet) {
  return {...sheet.headers, for (final row in sheet.rows) ...row.keys};
}

String? _text(Map<String, Object?> row, String key) => _textValue(row[key]);

String? _textValue(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool _isExplicitNone(String? value) {
  final normalized = _normalized(value);
  return normalized == '无账户' || normalized == 'none' || normalized == '无';
}

String _accountKey(String value) => 'account:${_normalized(value)}';

String _categoryKey(ImportCategoryKind kind, String path) =>
    'category:${kind.name}:${_normalized(path)}';

String _normalized(String? value) {
  if (value == null) return '';
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

String _canonicalDate(DateTime date) => date.toIso8601String();

String _canonicalDraft(ImportTransactionDraft draft) {
  return [
    'kind=${draft.operationKind.name}',
    'amount=${draft.amount.minorUnits}',
    'occurred=${_canonicalDate(draft.occurredAt)}',
    'posted=${_canonicalDate(draft.postedAt)}',
    'note=${_normalized(draft.note)}',
    'entities=${draft.sourceEntityKeys.join(',')}',
    'stats=${draft.isExcludedFromStats}',
    'budget=${draft.isExcludedFromBudget}',
    switch (draft) {
      ImportTransferDraft draft => 'fee=${draft.feeAmount?.minorUnits ?? ''}',
      ImportRepaymentDraft draft =>
        'principal=${draft.principal.minorUnits};'
            'interest=${draft.interest?.minorUnits ?? ''};'
            'fee=${draft.fee?.minorUnits ?? ''}',
      ImportReimbursementCloseDraft draft =>
        'received=${draft.actualReceivedAmount.minorUnits}',
      _ => '',
    },
  ].join(';');
}

ImportIssue _blocking(String code, String message, int? rowNumber) {
  return ImportIssue(
    code: code,
    message: message,
    severity: ImportIssueSeverity.blocking,
    rowNumber: rowNumber,
  );
}

String _roleName(YimuFileType role) => role.label;

void _mergeSourceEntity(
  Map<String, ImportSourceEntity> entities,
  ImportSourceEntity incoming,
) {
  final current = entities[incoming.sourceEntityKey];
  if (current == null) {
    entities[incoming.sourceEntityKey] = incoming;
    return;
  }
  if (current.kind != incoming.kind ||
      current.categoryKind != incoming.categoryKind) {
    // Keep the first stable display value, but retain an explicit conflict
    // marker so an empty constraint is not mistaken for "unrestricted".
    entities[incoming.sourceEntityKey] = current.copyWith(
      hasTargetDescriptorConflict: true,
    );
    return;
  }
  final allowed = switch ((
    current.allowedTargetDescriptors.isEmpty,
    incoming.allowedTargetDescriptors.isEmpty,
  )) {
    (true, true) => const <ImportTargetDescriptor>{},
    (true, false) => incoming.allowedTargetDescriptors,
    (false, true) => current.allowedTargetDescriptors,
    (false, false) => current.allowedTargetDescriptors.intersection(
      incoming.allowedTargetDescriptors,
    ),
  };
  final constraintConflict =
      current.hasTargetDescriptorConflict ||
      incoming.hasTargetDescriptorConflict ||
      (current.allowedTargetDescriptors.isNotEmpty &&
          incoming.allowedTargetDescriptors.isNotEmpty &&
          allowed.isEmpty);
  final preferred =
      current.preferredTargetDescriptor ?? incoming.preferredTargetDescriptor;
  entities[incoming.sourceEntityKey] = current.copyWith(
    isReviewPlaceholder:
        current.isReviewPlaceholder || incoming.isReviewPlaceholder,
    allowedTargetDescriptors: allowed,
    preferredTargetDescriptor: preferred,
    hasTargetDescriptorConflict: constraintConflict,
  );
}

/// Default bill ParseUnit. Additional source-semantic units can be supplied
/// to [YimuImportParser] without changing the source parser's orchestration.
class YimuBillParseUnit implements ParseUnit {
  const YimuBillParseUnit();

  @override
  String get key => 'yimu.bill';

  @override
  Set<ImportSourceFileType> get requiredFileTypes => {
    YimuFileType.bill.descriptor,
  };

  @override
  ParseUnitResult parse(Map<ImportSourceFileType, SourceFileFact> facts) {
    final entities = <String, ImportSourceEntity>{};
    final groups = <ImportTransactionGroupDraft>[];
    final filtered = <ImportFilteredRecord>[];
    _parseBillRows(
      facts[YimuFileType.bill.descriptor]!.records.whereType<YimuBillRecord>(),
      entities: entities,
      groups: groups,
      filtered: filtered,
    );
    return ParseUnitResult(
      derivedEntities: entities.values,
      groups: groups,
      filteredRecords: filtered,
    );
  }
}

/// Default transfer ParseUnit for the Yimu source.
class YimuTransferParseUnit implements ParseUnit {
  const YimuTransferParseUnit();

  @override
  String get key => 'yimu.transfer';

  @override
  Set<ImportSourceFileType> get requiredFileTypes => {
    YimuFileType.transfer.descriptor,
  };

  @override
  ParseUnitResult parse(Map<ImportSourceFileType, SourceFileFact> facts) {
    final entities = <String, ImportSourceEntity>{};
    final groups = <ImportTransactionGroupDraft>[];
    _parseTransferRows(
      facts[YimuFileType.transfer.descriptor]!.records
          .whereType<YimuTransferRecord>(),
      role: YimuFileType.transfer,
      entities: entities,
      groups: groups,
    );
    return ParseUnitResult(derivedEntities: entities.values, groups: groups);
  }
}

/// Default debt ParseUnit for the Yimu source.
class YimuDebtParseUnit implements ParseUnit {
  const YimuDebtParseUnit();

  @override
  String get key => 'yimu.debt';

  @override
  Set<ImportSourceFileType> get requiredFileTypes => {
    YimuFileType.debt.descriptor,
  };

  @override
  ParseUnitResult parse(Map<ImportSourceFileType, SourceFileFact> facts) {
    final entities = <String, ImportSourceEntity>{};
    final groups = <ImportTransactionGroupDraft>[];
    _parseTransferRows(
      facts[YimuFileType.debt.descriptor]!.records.whereType<YimuDebtRecord>(),
      role: YimuFileType.debt,
      entities: entities,
      groups: groups,
    );
    return ParseUnitResult(derivedEntities: entities.values, groups: groups);
  }
}

class _MutableImportFileParseResult {
  _MutableImportFileParseResult({
    required this.fileIndex,
    required this.fileName,
  });

  final int fileIndex;
  final String fileName;
  ImportSourceFileType? fileType;
  final List<ImportIssue> fatalIssues = [];

  ImportFileParseResult freeze() {
    return ImportFileParseResult(
      fileIndex: fileIndex,
      fileName: fileName,
      fileType: fileType,
      fatalIssues: fatalIssues,
    );
  }
}

class _ReimbursementDetail {
  const _ReimbursementDetail({
    required this.date,
    required this.account,
    required this.amount,
  });

  final DateTime date;
  final ImportAccountReference account;
  final Money amount;
}
