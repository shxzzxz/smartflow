import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../../core/money/money.dart';
import '../../import_models.dart';
import '../../service/source_parsing_models.dart';
import 'alipay_bill_record.dart';
import 'alipay_file_type.dart';

const alipayFingerprintVersion = 1;

class AlipayBillParseUnit implements ParseUnit {
  const AlipayBillParseUnit();

  @override
  String get key => 'alipay.bill';

  @override
  Set<ImportSourceFileType> get requiredFileTypes => {
    AlipayFileType.bill.descriptor,
  };

  @override
  ParseUnitResult parse(Map<ImportSourceFileType, SourceFileFact> facts) {
    final fact = facts[AlipayFileType.bill.descriptor]!;
    final entities = <String, ImportSourceEntity>{};
    final groups = <ImportTransactionGroupDraft>[];
    final filtered = <ImportFilteredRecord>[];
    final issues = <ImportIssue>[];

    for (final record in fact.records.whereType<AlipayBillRecord>()) {
      final filterReason = record.filterReason;
      if (filterReason != null) {
        filtered.add(
          ImportFilteredRecord(
            reasonCode: filterReason.reasonCode,
            reason: filterReason.reason,
            fileType: AlipayFileType.bill.descriptor,
            rowNumber: record.rowNumber,
          ),
        );
        if (filterReason == AlipayBillFilterReason.unknownDirection) {
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
        rowNumber: record.rowNumber,
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
        'source=alipay',
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
          fingerprintVersion: alipayFingerprintVersion,
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
        message: '支付宝交易分类为空。',
        severity: ImportIssueSeverity.blocking,
        rowNumber: rowNumber,
        fileType: AlipayFileType.bill.descriptor,
      ),
    );
    final key = 'review:missing:category:${kind.name}:$rowNumber';
    final label = kind == ImportCategoryKind.income ? '缺失收入分类' : '缺失支出分类';
    entities.putIfAbsent(
      key,
      () => ImportSourceEntity(
        source: ImportSource.alipay,
        kind: ImportEntityKind.category,
        sourceEntityKey: key,
        displayName: '$label（支付宝数据第 $rowNumber 行）',
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
      source: ImportSource.alipay,
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
  required int rowNumber,
}) {
  final display = value?.trim();
  if (display == null || display.isEmpty) {
    return const ImportAccountReference.explicitNone();
  }

  final key = 'account:${_normalized(display)}';
  final normalized = display.toLowerCase();
  final isCredit = normalized.contains('花呗') || normalized.contains('信用卡');
  final isFundOnly =
      normalized.contains('储蓄卡') ||
      normalized.contains('账户余额') ||
      normalized.contains('余额宝') ||
      normalized.contains('骑行卡');
  final allowed = isCredit
      ? const {ImportTargetDescriptor.creditAccount}
      : isFundOnly
      ? const {ImportTargetDescriptor.fundAccount}
      : const {
          ImportTargetDescriptor.fundAccount,
          ImportTargetDescriptor.creditAccount,
        };
  final preferred = isCredit
      ? ImportTargetDescriptor.creditAccount
      : ImportTargetDescriptor.fundAccount;
  entities.putIfAbsent(
    key,
    () => ImportSourceEntity(
      source: ImportSource.alipay,
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
