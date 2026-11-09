part of 'yimu_import_parser.dart';

bool _isGeneratedTransferFee(YimuBillRecord bill) {
  final note = bill.note;
  return bill.kind == '支出' && note != null && note.endsWith(' 转账手续费');
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
    final label = isExplicitNone
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

YimuFileType? _detectRole(String fileName, ImportTabularSheet sheet) {
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

Set<String> _headers(ImportTabularSheet sheet) {
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
    'kind=${_canonicalOperationKind(draft.operationKind)}',
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
            'fee=${draft.fee?.minorUnits ?? ''};'
            'discount=${draft.discount?.minorUnits ?? ''}',
      ImportAdvanceSettlementDraft draft =>
        'received=${draft.actualReceivedAmount.minorUnits}',
      _ => '',
    },
  ].join(';');
}

String _canonicalOperationKind(ImportOperationKind kind) {
  return switch (kind) {
    ImportOperationKind.advance => 'reimbursementAdvance',
    ImportOperationKind.advanceCollection => 'reimbursementReceipt',
    ImportOperationKind.advanceSettlement => 'reimbursementClose',
    _ => kind.name,
  };
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
