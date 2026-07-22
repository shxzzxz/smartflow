import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/money/money.dart';
import '../import_models.dart';
import '../port/yimu_workbook_reader.dart';

/// Deterministic, side-effect-free parser for the three files exported by
/// 一木记账. Spreadsheet decoding is deliberately injected through
/// [YimuWorkbookReader], keeping BIFF/OLE concerns outside this domain.
class YimuImportParser {
  const YimuImportParser({required YimuWorkbookReader reader})
    : _reader = reader;

  static const fingerprintVersion = 1;

  final YimuWorkbookReader _reader;

  ImportParseResult parse(ImportBundle bundle) {
    final fatalIssues = <ImportIssue>[];
    final sheetsByRole = <YimuFileRole, YimuSheet>{};

    for (final file in bundle.files) {
      final normalizedName = file.name.trim().toLowerCase();
      if (!normalizedName.endsWith('.xls')) {
        fatalIssues.add(
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
      } catch (_) {
        fatalIssues.add(
          ImportIssue(
            code: 'file_decode_failed',
            message: '无法读取一木文件 ${file.name}，请重新导出或选择有效的 .xls 文件。',
            severity: ImportIssueSeverity.fatal,
          ),
        );
        continue;
      }

      if (workbook.sheets.isEmpty) {
        fatalIssues.add(
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
        fatalIssues.add(
          ImportIssue(
            code: 'unsupported_headers',
            message: '无法识别文件 ${file.name} 的一木文件角色或表头。',
            severity: ImportIssueSeverity.fatal,
          ),
        );
        continue;
      }
      if (_hasNoRowsOrHeaders(sheet)) {
        fatalIssues.add(
          ImportIssue(
            code: 'empty_sheet',
            message: '文件 ${file.name} 的工作表为空。',
            severity: ImportIssueSeverity.fatal,
            fileRole: role,
          ),
        );
        continue;
      }
      if (sheetsByRole.containsKey(role)) {
        fatalIssues.add(
          ImportIssue(
            code: 'duplicate_file_role',
            message: '一木资料包中重复选择了${_roleName(role)}文件。',
            severity: ImportIssueSeverity.fatal,
            fileRole: role,
          ),
        );
        continue;
      }
      if (!_hasSupportedHeaders(role, sheet)) {
        fatalIssues.add(
          ImportIssue(
            code: 'unsupported_headers',
            message: '${_roleName(role)}文件表头不受支持。',
            severity: ImportIssueSeverity.fatal,
            fileRole: role,
          ),
        );
        continue;
      }
      sheetsByRole[role] = sheet;
    }

    for (final role in YimuFileRole.values) {
      if (!sheetsByRole.containsKey(role)) {
        fatalIssues.add(
          ImportIssue(
            code: 'missing_file_role',
            message: '资料包缺少${_roleName(role)}文件。',
            severity: ImportIssueSeverity.fatal,
            fileRole: role,
          ),
        );
      }
    }

    if (fatalIssues.isNotEmpty) {
      return ImportParseResult(
        source: ImportSource.yimu,
        fatalIssues: fatalIssues,
      );
    }

    final entities = <String, ImportSourceEntity>{};
    final groups = <ImportTransactionGroupDraft>[];
    final filtered = <ImportFilteredRecord>[];

    _parseBillRows(
      sheetsByRole[YimuFileRole.bill]!,
      entities: entities,
      groups: groups,
      filtered: filtered,
    );
    _parseTransferRows(
      sheetsByRole[YimuFileRole.transfer]!,
      role: YimuFileRole.transfer,
      entities: entities,
      groups: groups,
    );
    _parseTransferRows(
      sheetsByRole[YimuFileRole.debt]!,
      role: YimuFileRole.debt,
      entities: entities,
      groups: groups,
    );
    _markDuplicateOperationKeys(groups);

    return ImportParseResult(
      source: ImportSource.yimu,
      sourceEntities: entities.values,
      groups: groups,
      filteredRecords: filtered,
    );
  }

  void _parseBillRows(
    YimuSheet sheet, {
    required Map<String, ImportSourceEntity> entities,
    required List<ImportTransactionGroupDraft> groups,
    required List<ImportFilteredRecord> filtered,
  }) {
    for (var index = 0; index < sheet.rows.length; index++) {
      final row = sheet.rows[index];
      final rowNumber = index + 2;
      if (_isBlankRow(row)) continue;
      final note = _text(row, '备注');
      if (note != null && note.startsWith('报销差额')) {
        filtered.add(
          ImportFilteredRecord(
            reasonCode: 'reimbursement_gap_generated',
            reason: '报销差额是原报销交易自动生成的结果行。',
            fileRole: YimuFileRole.bill,
            rowNumber: rowNumber,
          ),
        );
        continue;
      }
      if (note != null && note.contains('还款利息')) {
        filtered.add(
          ImportFilteredRecord(
            reasonCode: 'repayment_interest_generated',
            reason: '还款利息应由转账或债务文件中的还款记录导入。',
            fileRole: YimuFileRole.bill,
            rowNumber: rowNumber,
          ),
        );
        continue;
      }

      final issues = <ImportIssue>[];
      final kind = _text(row, '收支类型');
      final occurredAt = _date(
        row['日期'],
        issues: issues,
        rowNumber: rowNumber,
        required: true,
      );
      final postedAt = _postedAt(
        row,
        occurredAt,
        issues: issues,
        rowNumber: rowNumber,
      );
      final amount = _money(
        row['金额'],
        issues: issues,
        rowNumber: rowNumber,
        fieldName: '金额',
        required: true,
      );
      final actualDate = occurredAt ?? DateTime(1970, 1, 1);
      final actualAmount = amount ?? Money.zero();
      final path = _categoryPath(row);
      final other = _text(row, '其他');
      final excludedFromStats = other?.contains('不计入收支') ?? false;
      final excludedFromBudget = other?.contains('不计入预算') ?? false;
      if (_text(row, '多币种') != null) {
        issues.add(
          _blocking('multi_currency_unsupported', '第一版导入不支持多币种金额。', rowNumber),
        );
      }
      final operationKey = _sourceOperationKey(row, YimuFileRole.bill);
      final canonical = <String>[
        'role=bill',
        'type=${_normalized(kind)}',
        'date=${_canonicalDate(actualDate)}',
        'posted=${_canonicalDate(postedAt)}',
        'amount=${actualAmount.minorUnits}',
        'category=${_normalized(path)}',
        'account=${_normalized(_text(row, '账户'))}',
        'refund=${_normalized(_text(row, '退款'))}',
        'receivable=${_normalized(_text(row, '报销账户'))}',
        'reimbursement=${_normalized(_text(row, '报销金额'))}',
        'details=${_normalized(_text(row, '报销明细'))}',
        'note=${_normalized(note)}',
        'other=${_normalized(other)}',
      ];

      if (kind == '支出' && _hasText(row, '报销账户', '报销金额', '报销明细')) {
        final group = _parseReimbursement(
          row,
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
        );
        groups.add(group);
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
          _text(row, '账户'),
          entities: entities,
          issues: issues,
          rowNumber: rowNumber,
          allowExplicitNone: true,
          required: false,
        );
        final refund = _money(
          row['退款'],
          issues: issues,
          rowNumber: rowNumber,
          fieldName: '退款',
          required: false,
        );
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
          _text(row, '账户'),
          entities: entities,
          issues: issues,
          rowNumber: rowNumber,
          allowExplicitNone: true,
          required: false,
        );
        if (actualAmount.minorUnits <= 0) {
          issues.add(
            _blocking('income_amount_invalid', '收入金额必须大于零。', rowNumber),
          );
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
          issues: issues,
          operationKey: operationKey,
          canonical: canonical,
        ),
      );
    }
  }

  ImportTransactionGroupDraft _parseReimbursement(
    Map<String, Object?> row, {
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
      _text(row, '账户'),
      entities: entities,
      issues: issues,
      rowNumber: rowNumber,
      required: true,
      fileRole: YimuFileRole.bill,
      fieldKey: 'account',
      fieldName: '账户',
    );
    final receivable = _accountReference(
      _text(row, '报销账户'),
      entities: entities,
      issues: issues,
      rowNumber: rowNumber,
      required: true,
      fileRole: YimuFileRole.bill,
      fieldKey: 'reimbursement',
      fieldName: '报销账户',
    );
    final reimbursementAmount = _money(
      row['报销金额'],
      issues: issues,
      rowNumber: rowNumber,
      fieldName: '报销金额',
      required: true,
    );
    final details = _parseReimbursementDetails(
      _text(row, '报销明细'),
      rowNumber: rowNumber,
      issues: issues,
      entities: entities,
    );
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
      children: children,
      issues: issues,
      operationKey: operationKey,
      canonical: canonical,
    );
  }

  void _parseTransferRows(
    YimuSheet sheet, {
    required YimuFileRole role,
    required Map<String, ImportSourceEntity> entities,
    required List<ImportTransactionGroupDraft> groups,
  }) {
    for (var index = 0; index < sheet.rows.length; index++) {
      final row = sheet.rows[index];
      final rowNumber = index + 2;
      if (_isBlankRow(row)) continue;
      final issues = <ImportIssue>[];
      final type = _text(row, '类型');
      final occurredAt = _date(
        row['日期'],
        issues: issues,
        rowNumber: rowNumber,
        required: true,
      );
      final postedAt = _postedAt(
        row,
        occurredAt,
        issues: issues,
        rowNumber: rowNumber,
      );
      final actualDate = occurredAt ?? DateTime(1970, 1, 1);
      final amount = _money(
        row['金额'],
        issues: issues,
        rowNumber: rowNumber,
        fieldName: '金额',
        required: true,
      );
      final actualAmount = amount ?? Money.zero();
      final note = _text(row, '备注');
      final fromValue = _text(row, '转出账户');
      final toValue = _text(row, '转入账户');
      final operationKey = _sourceOperationKey(row, role);
      final canonical = <String>[
        'role=${role.name}',
        'type=${_normalized(type)}',
        'date=${_canonicalDate(actualDate)}',
        'posted=${_canonicalDate(postedAt)}',
        'from=${_normalized(fromValue)}',
        'to=${_normalized(toValue)}',
        'amount=${actualAmount.minorUnits}',
        'fee=${_normalized(_text(row, '手续费'))}',
        'note=${_normalized(note)}',
      ];

      if (type == '转账') {
        final from = _accountReference(
          fromValue,
          entities: entities,
          issues: issues,
          rowNumber: rowNumber,
          required: true,
          fileRole: role,
          fieldKey: 'from',
          fieldName: '转出账户',
        );
        final to = _accountReference(
          toValue,
          entities: entities,
          issues: issues,
          rowNumber: rowNumber,
          required: true,
          fileRole: role,
          fieldKey: 'to',
          fieldName: '转入账户',
        );
        final fee = _optionalMoney(
          row['手续费'],
          issues: issues,
          rowNumber: rowNumber,
          fieldName: '手续费',
        );
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
          fileRole: role,
          fieldKey: 'from',
          fieldName: '转出账户',
        );
        final liability = _accountReference(
          toValue,
          entities: entities,
          issues: issues,
          rowNumber: rowNumber,
          required: true,
          fileRole: role,
          fieldKey: 'to',
          fieldName: '转入账户',
        );
        final fee = _optionalMoney(
          row['手续费'],
          issues: issues,
          rowNumber: rowNumber,
          fieldName: '手续费',
        );
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
              issues: issues,
              operationKey: operationKey,
              canonical: canonical,
            ),
          );
        }
        continue;
      }

      if (type == '借入' && role == YimuFileRole.debt) {
        final liability = _accountReference(
          toValue,
          entities: entities,
          issues: issues,
          rowNumber: rowNumber,
          required: true,
          fileRole: role,
          fieldKey: 'to',
          fieldName: '转入账户',
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
            fileRole: role,
            fieldKey: 'from',
            fieldName: '转出账户',
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
          issues: issues,
          operationKey: operationKey,
          canonical: canonical,
        ),
      );
    }
  }

  List<_ReimbursementDetail> _parseReimbursementDetails(
    String? value, {
    required int rowNumber,
    required List<ImportIssue> issues,
    required Map<String, ImportSourceEntity> entities,
  }) {
    if (value == null || value.trim().isEmpty) return const [];
    final details = <_ReimbursementDetail>[];
    for (final line in value.split(RegExp(r'[\r\n]+'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = RegExp(
        r'^(\d{4}/\d{2}/\d{2})(.+?)到账\s*([+-]?\d+(?:\.\d+)?)$',
      ).firstMatch(trimmed);
      if (match == null) {
        issues.add(
          _blocking(
            'reimbursement_detail_invalid',
            '无法解析报销明细：$trimmed',
            rowNumber,
          ),
        );
        continue;
      }
      final detailIssues = <ImportIssue>[];
      final date = _date(
        match.group(1),
        issues: detailIssues,
        rowNumber: rowNumber,
        required: true,
      );
      final amount = _money(
        match.group(3),
        issues: detailIssues,
        rowNumber: rowNumber,
        fieldName: '报销明细金额',
        required: true,
      );
      final account = _accountReference(
        match.group(2),
        entities: entities,
        issues: detailIssues,
        rowNumber: rowNumber,
        required: true,
        fileRole: YimuFileRole.bill,
        fieldKey: 'reimbursement_detail_account',
        fieldName: '报销明细到账账户',
      );
      issues.addAll(detailIssues);
      if (date != null && amount != null) {
        details.add(
          _ReimbursementDetail(
            date: date,
            account: account,
            amount: amount.abs(),
          ),
        );
      }
    }
    return details;
  }

  ImportTransactionGroupDraft _group(
    ImportTransactionDraft top, {
    Iterable<ImportTransactionDraft> children = const [],
    required Iterable<ImportIssue> issues,
    required String? operationKey,
    required Iterable<String> canonical,
  }) {
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
      fingerprintVersion: fingerprintVersion,
      issues: issues,
    );
  }

  void _markDuplicateOperationKeys(List<ImportTransactionGroupDraft> groups) {
    final firstByKey = <String, int>{};
    for (var index = 0; index < groups.length; index++) {
      final key = groups[index].sourceOperationKey;
      if (key == null) continue;
      final first = firstByKey[key];
      if (first == null) {
        firstByKey[key] = index;
        continue;
      }
      final issue = _blocking(
        'duplicate_source_operation_key',
        '资料包内重复的来源操作键：$key',
        null,
      );
      groups[index] = _copyGroupWithIssue(groups[index], issue);
      groups[first] = _copyGroupWithIssue(groups[first], issue);
    }
  }

  ImportTransactionGroupDraft _copyGroupWithIssue(
    ImportTransactionGroupDraft group,
    ImportIssue issue,
  ) {
    return ImportTransactionGroupDraft(
      topLevel: group.topLevel,
      children: group.children,
      sourceOperationKey: group.sourceOperationKey,
      sourceOperationFingerprint: group.sourceOperationFingerprint,
      fingerprintVersion: group.fingerprintVersion,
      issues: [...group.issues, issue],
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
      entities.putIfAbsent(
        key,
        () => ImportSourceEntity(
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
    entities.putIfAbsent(
      key,
      () => ImportSourceEntity(
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
    YimuFileRole? fileRole,
    String fieldKey = 'account',
    String fieldName = '账户',
  }) {
    final display = value?.trim();
    final isExplicitNone = display != null && _isExplicitNone(display);
    if (display == null || display.isEmpty || isExplicitNone) {
      if (allowExplicitNone || !required) {
        return const ImportAccountReference.explicitNone();
      }
      final role = fileRole ?? YimuFileRole.bill;
      final key = 'review:missing:account:${role.name}:$rowNumber:$fieldKey';
      final label =
          isExplicitNone
              ? '$fieldName明确为无账户（${_roleName(role)}文件第 $rowNumber 行）'
              : '缺失$fieldName（${_roleName(role)}文件第 $rowNumber 行）';
      entities.putIfAbsent(
        key,
        () => ImportSourceEntity(
          source: ImportSource.yimu,
          kind: ImportEntityKind.account,
          sourceEntityKey: key,
          displayName: label,
          isReviewPlaceholder: true,
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
    entities.putIfAbsent(
      key,
      () => ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.account,
        sourceEntityKey: key,
        displayName: display,
      ),
    );
    return ImportAccountReference.source(
      sourceEntityKey: key,
      displayName: display,
    );
  }

  DateTime? _date(
    Object? value, {
    required List<ImportIssue> issues,
    required int rowNumber,
    required bool required,
  }) {
    if (value is DateTime) return value;
    final text = _textValue(value);
    if (text == null) {
      if (required) issues.add(_blocking('date_missing', '交易日期为空。', rowNumber));
      return null;
    }
    final normalized = text.replaceAll('/', '-');
    final parsed = DateTime.tryParse(normalized);
    if (parsed != null) return parsed;
    if (required) {
      issues.add(_blocking('date_invalid', '无法解析交易日期：$text', rowNumber));
    }
    return null;
  }

  Money? _money(
    Object? value, {
    required List<ImportIssue> issues,
    required int rowNumber,
    required String fieldName,
    required bool required,
  }) {
    final text = _textValue(value);
    if (text == null) {
      if (required) {
        issues.add(
          _blocking('${fieldName}_missing', '$fieldName为空。', rowNumber),
        );
      }
      return null;
    }
    final parsed = Money.tryParse(text);
    if (parsed != null) return parsed;
    issues.add(
      _blocking('${fieldName}_invalid', '无法解析$fieldName：$text', rowNumber),
    );
    return null;
  }

  Money? _optionalMoney(
    Object? value, {
    required List<ImportIssue> issues,
    required int rowNumber,
    required String fieldName,
  }) {
    final text = _textValue(value);
    if (text == null) return null;
    final parsed = Money.tryParse(text);
    if (parsed == null) {
      issues.add(
        _blocking('${fieldName}_invalid', '无法解析$fieldName：$text', rowNumber),
      );
      return null;
    }
    if (parsed.minorUnits < 0) {
      issues.add(
        _blocking('${fieldName}_negative', '$fieldName不能为负数。', rowNumber),
      );
    }
    return parsed.minorUnits == 0 ? null : parsed;
  }

  YimuFileRole? _detectRole(String fileName, YimuSheet sheet) {
    final name = fileName.toLowerCase();
    if (name.contains('账单')) return YimuFileRole.bill;
    if (name.contains('转账')) return YimuFileRole.transfer;
    if (name.contains('债务')) return YimuFileRole.debt;
    final headers = _headers(sheet);
    if (headers.contains('收支类型')) return YimuFileRole.bill;
    if (headers.contains('类型') &&
        headers.contains('转出账户') &&
        headers.contains('转入账户')) {
      final types =
          sheet.rows.map((row) => _text(row, '类型')).whereType<String>();
      if (types.contains('借入')) return YimuFileRole.debt;
      if (types.contains('转账')) return YimuFileRole.transfer;
    }
    return null;
  }

  bool _hasSupportedHeaders(YimuFileRole role, YimuSheet sheet) {
    final headers = _headers(sheet);
    if (role == YimuFileRole.bill) {
      return headers.containsAll(const [
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
      ]);
    }
    return headers.containsAll(const [
      '日期',
      '类型',
      '转出账户',
      '转入账户',
      '金额',
      '手续费',
      '备注',
    ]);
  }

  bool _hasNoRowsOrHeaders(YimuSheet sheet) =>
      sheet.headers.isEmpty ||
      sheet.rows.isEmpty ||
      sheet.rows.every(_isBlankRow);

  DateTime _postedAt(
    Map<String, Object?> row,
    DateTime? occurredAt, {
    required List<ImportIssue> issues,
    required int rowNumber,
  }) {
    final fallback = occurredAt ?? DateTime(1970, 1, 1);
    const candidates = ['入账时间', '入账日期', '记账时间', '记账日期', '到账时间', '到账日期'];
    for (final candidate in candidates) {
      final value = row[candidate];
      if (_textValue(value) == null) continue;
      return _date(
            value,
            issues: issues,
            rowNumber: rowNumber,
            required: true,
          ) ??
          fallback;
    }
    return fallback;
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

  String? _sourceOperationKey(Map<String, Object?> row, YimuFileRole role) {
    const candidates = ['交易ID', '记录ID', '流水号', '操作ID', 'operation_id'];
    for (final candidate in candidates) {
      final value = _text(row, candidate);
      if (value != null) return '${role.name}:${_normalized(value)}';
    }
    return null;
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

  String _roleName(YimuFileRole role) {
    return switch (role) {
      YimuFileRole.bill => '账单',
      YimuFileRole.transfer => '转账',
      YimuFileRole.debt => '债务',
    };
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
