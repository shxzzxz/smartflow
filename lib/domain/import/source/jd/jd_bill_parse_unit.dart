import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../../core/money/money.dart';
import '../../import_models.dart';
import '../../service/source_parsing_models.dart';
import 'jd_bill_record.dart';
import 'jd_file_type.dart';

const jdFingerprintVersion = 1;

class JdBillParseUnit implements ParseUnit {
  const JdBillParseUnit();

  @override
  String get key => 'jd.bill';

  @override
  Set<ImportSourceFileType> get requiredFileTypes => {
    JdFileType.bill.descriptor,
  };

  @override
  ParseUnitResult parse(Map<ImportSourceFileType, SourceFileFact> facts) {
    final fact = facts[JdFileType.bill.descriptor]!;
    final entities = <String, ImportSourceEntity>{};
    final groups = <ImportTransactionGroupDraft>[];
    final filtered = <ImportFilteredRecord>[];
    final issues = <ImportIssue>[];

    for (final record in fact.records.whereType<JdBillRecord>()) {
      final filterReason = record.filterReason;
      if (filterReason != null) {
        filtered.add(
          ImportFilteredRecord(
            reasonCode: filterReason.reasonCode,
            reason: filterReason.reason,
            fileType: JdFileType.bill.descriptor,
            rowNumber: record.rowNumber,
          ),
        );
        if (filterReason == JdBillFilterReason.unknownDirection) {
          issues.addAll(record.issues);
        }
        continue;
      }

      final recordIssues = [...record.issues];
      final kind = record.direction == '收入'
          ? ImportCategoryKind.income
          : ImportCategoryKind.expense;
      final category = _categoryReference(
        record.categoryPath,
        kind,
        entities: entities,
        issues: recordIssues,
        rowNumber: record.rowNumber,
      );
      final account = _accountReference(
        record.paymentMethod,
        entities: entities,
      );
      final occurredAt = record.occurredAt ?? DateTime(1970);
      final amount = record.amount ?? Money.zero();
      final topLevel = kind == ImportCategoryKind.income
          ? ImportIncomeDraft(
              amount: amount,
              receiveAccount: account,
              category: category,
              occurredAt: occurredAt,
              note: record.note,
            )
          : ImportExpenseDraft(
              amount: amount,
              paidFrom: account,
              category: category,
              occurredAt: occurredAt,
              note: record.note,
            );
      final canonical = [
        'source=jd',
        'direction=${record.direction}',
        'occurred=${occurredAt.toIso8601String()}',
        'amount=${amount.minorUnits}',
        'category=${category.sourceEntityKey}',
        'account=${account.isExplicitNone ? 'none' : account.sourceEntityKey}',
        'note=${_normalized(record.note)}',
      ].join('|');
      groups.add(
        ImportTransactionGroupDraft(
          topLevel: topLevel,
          sourceOperationKey: record.sourceOperationKey,
          sourceOperationFingerprint: sha256
              .convert(utf8.encode(canonical))
              .toString(),
          fingerprintVersion: jdFingerprintVersion,
          issues: recordIssues,
        ),
      );
    }

    return ParseUnitResult(
      derivedEntities: entities.values,
      groups: groups,
      filteredRecords: filtered,
      issues: issues,
    );
  }
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
    issues.add(
      ImportIssue(
        code: 'category_missing',
        message: '京东交易分类为空。',
        severity: ImportIssueSeverity.blocking,
        rowNumber: rowNumber,
        fileType: JdFileType.bill.descriptor,
      ),
    );
    final key = 'review:missing:category:${kind.name}:$rowNumber';
    final label = kind == ImportCategoryKind.income ? '缺失收入分类' : '缺失支出分类';
    entities.putIfAbsent(
      key,
      () => ImportSourceEntity(
        source: ImportSource.jd,
        kind: ImportEntityKind.category,
        sourceEntityKey: key,
        displayName: '$label（京东数据第 $rowNumber 行）',
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
  final key = 'category:${kind.name}:${_normalized(display)}';
  entities.putIfAbsent(
    key,
    () => ImportSourceEntity(
      source: ImportSource.jd,
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

ImportAccountReference _accountReference(
  String? value, {
  required Map<String, ImportSourceEntity> entities,
}) {
  final display = value?.trim();
  if (display == null || display.isEmpty) {
    return const ImportAccountReference.explicitNone();
  }

  final key = 'account:${_normalized(display)}';
  final normalized = display.toLowerCase();
  final isPayable = normalized.contains('先享后付');
  final isCredit = !isPayable && normalized.contains('信用卡');
  final isFundOnly =
      normalized.contains('京东小金库') ||
      normalized.contains('余额') ||
      normalized.contains('数字人民币') ||
      normalized.contains('储蓄卡') ||
      normalized.contains('银行');
  final allowed = isPayable
      ? const {ImportTargetDescriptor.payableAccount}
      : isCredit
      ? const {ImportTargetDescriptor.creditAccount}
      : isFundOnly
      ? const {ImportTargetDescriptor.fundAccount}
      : const {
          ImportTargetDescriptor.fundAccount,
          ImportTargetDescriptor.payableAccount,
          ImportTargetDescriptor.creditAccount,
        };
  final preferred = isPayable
      ? ImportTargetDescriptor.payableAccount
      : isCredit
      ? ImportTargetDescriptor.creditAccount
      : ImportTargetDescriptor.fundAccount;
  entities.putIfAbsent(
    key,
    () => ImportSourceEntity(
      source: ImportSource.jd,
      kind: ImportEntityKind.account,
      sourceEntityKey: key,
      displayName: display,
      allowedTargetDescriptors: allowed,
      preferredTargetDescriptor: preferred,
    ),
  );
  return ImportAccountReference.source(
    sourceEntityKey: key,
    displayName: display,
  );
}

String _normalized(String? value) {
  if (value == null) return '';
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
