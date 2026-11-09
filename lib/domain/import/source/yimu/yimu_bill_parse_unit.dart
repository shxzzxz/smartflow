part of 'yimu_import_parser.dart';

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
    if (_isGeneratedTransferFee(record)) {
      filtered.add(
        ImportFilteredRecord(
          reasonCode: 'transfer_fee_generated',
          reason: '转账手续费是一木自动生成的结果行。',
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
      'receivable=${_normalized(record.advanceAccountName)}',
      'reimbursement=${_normalized(record.advanceAmountSource)}',
      'details=${_normalized(record.advanceDetailsSource)}',
      'note=${_normalized(note)}',
      'other=${_normalized(other)}',
    ];

    if (kind == '支出' && record.hasAdvanceFields) {
      groups.add(
        _parseAdvance(
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
      final gross = actualAmount.abs() + (refund?.abs() ?? Money.zero());
      if (gross.minorUnits == 0) {
        issues.add(
          _blocking('expense_amount_invalid', '支出金额必须大于零。', rowNumber),
        );
      }
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

ImportTransactionGroupDraft _parseAdvance(
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
    allowExplicitNone: true,
    required: false,
  );
  final receivable = _accountReference(
    record.advanceAccountName,
    entities: entities,
    issues: issues,
    rowNumber: rowNumber,
    required: true,
    fileType: YimuFileType.bill,
    fieldKey: 'advance',
    fieldName: '报销账户',
  );
  final advanceAmount = record.advanceAmount;
  final refund = record.refundAmount;
  if (refund != null && refund.minorUnits < 0) {
    issues.add(_blocking('refund_negative', '退款金额不能为负数。', rowNumber));
  }
  final grossAdvance = amount.abs() + (refund?.abs() ?? Money.zero());
  if (grossAdvance.minorUnits == 0) {
    issues.add(_blocking('expense_amount_invalid', '支出金额必须大于零。', rowNumber));
  }
  final details = [
    for (final detail in record.advanceDetails)
      if (detail.occurredAt != null && detail.amount != null)
        _AdvanceDetail(
          date: detail.occurredAt!,
          account: _accountReference(
            detail.accountName,
            entities: entities,
            issues: issues,
            rowNumber: rowNumber,
            required: true,
            fileType: YimuFileType.bill,
            fieldKey: 'advance_detail_account',
            fieldName: '报销明细到账账户',
          ),
          amount: detail.amount!.abs(),
        ),
  ];
  if (details.isEmpty) {
    issues.add(
      _blocking('advance_details_missing', '报销记录缺少有效报销明细。', rowNumber),
    );
  }
  if (advanceAmount != null) {
    final detailTotal = details.fold(
      Money.zero(),
      (sum, item) => sum + item.amount,
    );
    if (detailTotal != advanceAmount) {
      issues.add(
        _blocking('advance_amount_mismatch', '报销金额与报销明细到账合计不一致。', rowNumber),
      );
    }
  }

  final top = ImportAdvanceDraft(
    amount: grossAdvance,
    receivableAccount: receivable,
    paidFrom: paidFrom,
    category: category,
    occurredAt: occurredAt,
    postedAt: postedAt,
    note: note,
    isExcludedFromStats: excludedFromStats,
    isExcludedFromBudget: excludedFromBudget,
  );
  final children = <ImportTransactionDraft>[
    if (refund != null && refund.minorUnits > 0)
      ImportRefundDraft(
        amount: refund,
        refundTo: paidFrom,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
      ),
  ];
  if (details.isNotEmpty) {
    for (var index = 0; index < details.length - 1; index++) {
      final detail = details[index];
      children.add(
        ImportAdvanceCollectionDraft(
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
      ImportAdvanceSettlementDraft(
        actualReceivedAmount: last.amount,
        receivableAccount: receivable,
        receiveAccount: last.account,
        occurredAt: last.date,
        note: note,
      ),
    );
  } else {
    children.add(
      ImportAdvanceSettlementDraft(
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
