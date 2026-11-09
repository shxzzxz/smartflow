import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../../core/money/money.dart';
import '../../import_models.dart';
import '../../service/source_parsing_models.dart';
import 'wechat_bill_record.dart';
import 'wechat_category_lexicon.dart';
import 'wechat_file_type.dart';

const wechatFingerprintVersion = 1;

class WechatBillParseUnit implements ParseUnit {
  const WechatBillParseUnit({required this.lexicon});

  final WechatCategoryLexicon lexicon;

  @override
  String get key => 'wechat.bill';

  @override
  Set<ImportSourceFileType> get requiredFileTypes => {
    WechatFileType.bill.descriptor,
  };

  @override
  ParseUnitResult parse(Map<ImportSourceFileType, SourceFileFact> facts) {
    final fact = facts[WechatFileType.bill.descriptor]!;
    final entities = <String, ImportSourceEntity>{};
    final groups = <ImportTransactionGroupDraft>[];
    final filtered = <ImportFilteredRecord>[];
    final issues = <ImportIssue>[];

    for (final record in fact.records.whereType<WechatBillRecord>()) {
      final filterReason = record.filterReason;
      if (filterReason != null) {
        filtered.add(
          ImportFilteredRecord(
            reasonCode: filterReason.reasonCode,
            reason: filterReason.reason,
            fileType: WechatFileType.bill.descriptor,
            rowNumber: record.rowNumber,
          ),
        );
        if (filterReason == WechatBillFilterReason.unknownDirection) {
          issues.addAll(record.issues);
        }
        continue;
      }

      final recordIssues = [...record.issues];
      final direction = record.direction == '收入'
          ? ImportCategoryKind.income
          : ImportCategoryKind.expense;
      final categoryMatch = lexicon.match(
        direction: direction,
        transactionType: record.transactionType,
        counterparty: record.counterparty,
        product: record.product,
        status: record.status,
      );
      if (categoryMatch == null) {
        recordIssues.add(
          ImportIssue(
            code: 'category_missing',
            message: '微信交易无法推断分类。',
            severity: ImportIssueSeverity.blocking,
            rowNumber: record.rowNumber,
            fileType: WechatFileType.bill.descriptor,
          ),
        );
      } else if (categoryMatch.isFallback) {
        recordIssues.add(
          ImportIssue(
            code: 'category_fallback',
            message: '微信交易未命中分类关键词，已预填分类“其他”。',
            severity: ImportIssueSeverity.warning,
            rowNumber: record.rowNumber,
            fileType: WechatFileType.bill.descriptor,
          ),
        );
      }
      final categoryPath = categoryMatch?.path ?? const ['其他'];
      final category = _categoryReference(
        categoryPath,
        direction,
        entities: entities,
      );
      final account = _accountReference(
        record.paymentMethod,
        direction: direction,
        status: record.status,
        entities: entities,
      );
      final occurredAt = record.occurredAt ?? DateTime(1970);
      final amount = record.amount ?? Money.zero();
      final topLevel = direction == ImportCategoryKind.income
          ? ImportIncomeDraft(
              amount: amount,
              receiveAccount: account,
              category: category,
              occurredAt: occurredAt,
              note: record.product,
            )
          : ImportExpenseDraft(
              amount: amount,
              paidFrom: account,
              category: category,
              occurredAt: occurredAt,
              note: record.product,
            );
      final canonical = [
        'source=wechat',
        'direction=${record.direction}',
        'occurred=${occurredAt.toIso8601String()}',
        'amount=${amount.minorUnits}',
        'transactionType=${_normalized(record.transactionType)}',
        'counterparty=${_normalized(record.counterparty)}',
        'product=${_normalized(record.product)}',
        'account=${account.isExplicitNone ? 'none' : account.sourceEntityKey}',
        'status=${_normalized(record.status)}',
      ].join('|');
      groups.add(
        ImportTransactionGroupDraft(
          topLevel: topLevel,
          sourceOperationKey: record.transactionId,
          sourceOperationFingerprint: sha256
              .convert(utf8.encode(canonical))
              .toString(),
          fingerprintVersion: wechatFingerprintVersion,
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
  List<String> path,
  ImportCategoryKind direction, {
  required Map<String, ImportSourceEntity> entities,
}) {
  final display = path.join(' / ');
  final key = 'category:${direction.name}:${_normalized(display)}';
  entities.putIfAbsent(
    key,
    () => ImportSourceEntity(
      source: ImportSource.wechat,
      kind: ImportEntityKind.category,
      sourceEntityKey: key,
      displayName: display,
      categoryKind: direction,
    ),
  );
  return ImportCategoryReference(
    sourceEntityKey: key,
    path: display,
    kind: direction,
  );
}

ImportAccountReference _accountReference(
  String? value, {
  required ImportCategoryKind direction,
  required String? status,
  required Map<String, ImportSourceEntity> entities,
}) {
  var display = value?.trim();
  if (direction == ImportCategoryKind.income && status == '已存入零钱') {
    display = '零钱';
  }
  if (display == null || display.isEmpty || display == '/') {
    return const ImportAccountReference.explicitNone();
  }
  final accountName = display;
  final key = 'account:${_normalized(accountName)}';
  final normalized = accountName.toLowerCase();
  final isCredit = normalized.contains('信用卡') || normalized.contains('分付');
  final isFund =
      normalized.contains('零钱') ||
      normalized.contains('银行') ||
      normalized.contains('储蓄卡');
  final allowed = isCredit
      ? const {ImportTargetDescriptor.creditAccount}
      : isFund
      ? const {ImportTargetDescriptor.fundAccount}
      : const {
          ImportTargetDescriptor.fundAccount,
          ImportTargetDescriptor.creditAccount,
        };
  entities.putIfAbsent(
    key,
    () => ImportSourceEntity(
      source: ImportSource.wechat,
      kind: ImportEntityKind.account,
      sourceEntityKey: key,
      displayName: accountName,
      allowedTargetDescriptors: allowed,
      preferredTargetDescriptor: isCredit
          ? ImportTargetDescriptor.creditAccount
          : ImportTargetDescriptor.fundAccount,
    ),
  );
  return ImportAccountReference.source(
    sourceEntityKey: key,
    displayName: accountName,
  );
}

String _normalized(String? value) {
  if (value == null) return '';
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
