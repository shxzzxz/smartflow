import 'package:intl/intl.dart';

import '../../../application/import/import_api.dart';
import '../../../core/money/money_formatter.dart';
import '../../../widget/business/finance/finance_tone.dart';
import '../../shared/presentation/transaction_list_presentation.dart';

enum ImportEntrySource { yimu, wechat, alipay, unionPay, generic }

extension ImportEntrySourcePresentation on ImportEntrySource {
  String get routeValue => switch (this) {
    ImportEntrySource.yimu => 'yimu',
    ImportEntrySource.wechat => 'wechat',
    ImportEntrySource.alipay => 'alipay',
    ImportEntrySource.unionPay => 'union-pay',
    ImportEntrySource.generic => 'generic',
  };

  String get label => switch (this) {
    ImportEntrySource.yimu => '一木记账',
    ImportEntrySource.wechat => '微信账单',
    ImportEntrySource.alipay => '支付宝账单',
    ImportEntrySource.unionPay => '云闪付账单',
    ImportEntrySource.generic => '其他格式',
  };

  String get description => switch (this) {
    ImportEntrySource.yimu => '从一木记账备份文件导入',
    ImportEntrySource.wechat => '导入微信支付交易记录',
    ImportEntrySource.alipay => '导入支付宝交易记录',
    ImportEntrySource.unionPay => '导入云闪付交易记录',
    ImportEntrySource.generic => '支持 CSV、Excel 等格式文件',
  };

  bool get isAvailable => this == ImportEntrySource.yimu;
}

ImportEntrySource importEntrySourceFromRoute(String? value) {
  return switch (value) {
    'wechat' => ImportEntrySource.wechat,
    'alipay' => ImportEntrySource.alipay,
    'union-pay' => ImportEntrySource.unionPay,
    'generic' => ImportEntrySource.generic,
    _ => ImportEntrySource.yimu,
  };
}

String importSourceLabel(ImportSource source) {
  return switch (source) {
    ImportSource.yimu => ImportEntrySource.yimu.label,
  };
}

String formatImportTaskName(ImportBatch batch) {
  return '${importSourceLabel(batch.source)}_${_taskNameFormat.format(batch.importedAt)}';
}

List<TransactionDayGroup> buildImportPreviewGroups(
  ImportPlanReview review, {
  Set<int> selectedGroupIndexes = const {},
  bool showSelectionControls = false,
}) {
  final rowsByDate = <DateTime, List<TransactionRowPresentation>>{};
  final incomeByDate = <DateTime, int>{};
  final expenseByDate = <DateTime, int>{};

  for (final groupReview in review.groups) {
    final draft = groupReview.group.topLevel;
    final date = DateTime(
      draft.occurredAt.year,
      draft.occurredAt.month,
      draft.occurredAt.day,
    );
    rowsByDate
        .putIfAbsent(date, () => [])
        .add(
          _buildImportPreviewRow(
            review,
            groupReview,
            selectedGroupIndexes,
            showSelectionControls: showSelectionControls,
          ),
        );
    if (_isIncomeDraft(draft)) {
      incomeByDate.update(
        date,
        (value) => value + draft.amount.minorUnits,
        ifAbsent: () => draft.amount.minorUnits,
      );
    } else if (_isExpenseDraft(draft)) {
      expenseByDate.update(
        date,
        (value) => value + draft.amount.minorUnits,
        ifAbsent: () => draft.amount.minorUnits,
      );
    }
  }

  final dates = rowsByDate.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final date in dates)
      TransactionDayGroup(
        date: date,
        rows: rowsByDate[date]!,
        incomeMinor: incomeByDate[date] ?? 0,
        expenseMinor: expenseByDate[date] ?? 0,
      ),
  ];
}

List<TransactionDayGroup> takeImportPreviewRows(
  List<TransactionDayGroup> groups,
  int limit,
) {
  var remaining = limit;
  final result = <TransactionDayGroup>[];
  for (final group in groups) {
    if (remaining == 0) break;
    final rows = group.rows.take(remaining).toList(growable: false);
    if (rows.isEmpty) continue;
    result.add(
      TransactionDayGroup(
        date: group.date,
        rows: rows,
        incomeMinor: group.incomeMinor,
        expenseMinor: group.expenseMinor,
      ),
    );
    remaining -= rows.length;
  }
  return result;
}

String formatImportFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
}

String importEntityKindLabel(ImportSourceEntity entity) {
  if (entity.kind == ImportEntityKind.account) return '来源账户';
  return entity.categoryKind == ImportCategoryKind.income ? '来源收入分类' : '来源支出分类';
}

String importSourceKindLabel(ImportSourceEntity entity) {
  if (entity.kind == ImportEntityKind.account) return '账户';
  return entity.categoryKind == ImportCategoryKind.income ? '收入分类' : '支出分类';
}

class ImportMappingAnalysisSummary {
  const ImportMappingAnalysisSummary({
    required this.mapped,
    required this.pending,
    required this.unmapped,
  });

  final int mapped;
  final int pending;
  final int unmapped;

  int get total => mapped + pending + unmapped;
}

String importMappingAnalysisDescription(ImportMappingAnalysisSummary summary) {
  if (summary.unmapped > 0) {
    return '有 ${summary.unmapped} 项来源账户或分类尚未完成映射，请查看全部处理。';
  }
  if (summary.pending > 0) {
    return '有 ${summary.pending} 项将在导入时新建，请确认配置后继续。';
  }
  if (summary.total == 0) return '解析结果中没有需要配置的账户或分类。';
  return '映射配置已准备就绪，可确认配置后继续。';
}

ImportMappingAnalysisSummary summarizeImportMappings(ImportPlanReview review) {
  var mapped = 0;
  var pending = 0;
  var unmapped = 0;
  for (final item in review.mappingItems) {
    if (item.action == ImportMappingAction.create) {
      pending++;
      continue;
    }
    if (item.action == ImportMappingAction.unresolved) {
      unmapped++;
      continue;
    }
    final targetId = item.targetId ?? review.effectiveMappings[item.key];
    final target =
        review.targets
            .where((candidate) => candidate.id == targetId)
            .firstOrNull;
    if (target == null || target.isArchived) {
      unmapped++;
    } else {
      mapped++;
    }
  }
  return ImportMappingAnalysisSummary(
    mapped: mapped,
    pending: pending,
    unmapped: unmapped,
  );
}

class ImportPreviewAnalysisSummary {
  const ImportPreviewAnalysisSummary({
    required this.parsed,
    required this.pending,
    required this.unparsed,
    required this.skipped,
    this.filtered = 0,
  });

  final int parsed;
  final int pending;
  final int unparsed;
  final int skipped;
  final int filtered;

  int get total => parsed + pending + unparsed + skipped;
}

String importPreviewAnalysisDescription(ImportPreviewAnalysisSummary summary) {
  if (summary.unparsed > 0) {
    return '有 ${summary.unparsed} 条交易无法解析，请查看全部检查详情。';
  }
  if (summary.pending > 0) {
    return '有 ${summary.pending} 条交易需要确认后才能导入。';
  }
  if (summary.skipped > 0) {
    return '有 ${summary.skipped} 条来源记录已按规则跳过，可查看全部导入预览。';
  }
  if (summary.total == 0) return '资料包没有产生可预览的交易。';
  return '解析结果已准备，可查看全部交易预览。';
}

ImportPreviewAnalysisSummary summarizeImportPreview(
  ImportPlanReview review, {
  Set<int> confirmedExactDuplicateIndexes = const {},
  Set<int> confirmedSuspectedDuplicateIndexes = const {},
  Set<int> confirmedWarningIndexes = const {},
}) {
  var parsed = 0;
  var pending = 0;
  var unparsed = 0;
  final filtered = review.plan.filteredRecords.length;
  for (final group in review.groups) {
    if (group.isBlocked) {
      unparsed++;
    } else if (group.isExactDuplicate) {
      if (confirmedExactDuplicateIndexes.contains(group.index)) {
        parsed++;
      } else {
        pending++;
      }
    } else if (group.isSuspectedDuplicate) {
      if (confirmedSuspectedDuplicateIndexes.contains(group.index)) {
        parsed++;
      } else {
        pending++;
      }
    } else if (group.hasWarnings) {
      if (confirmedWarningIndexes.contains(group.index)) {
        parsed++;
      } else {
        pending++;
      }
    } else {
      parsed++;
    }
  }
  return ImportPreviewAnalysisSummary(
    parsed: parsed,
    pending: pending,
    unparsed: unparsed,
    skipped: filtered,
    filtered: filtered,
  );
}

List<ImportSourceEntity> importGroupEntities(
  ImportTransactionGroupDraft group,
  List<ImportSourceEntity> sourceEntities,
) {
  final keys =
      group.transactions.expand((draft) => draft.sourceEntityKeys).toSet();
  return sourceEntities
      .where((entity) => keys.contains(entity.sourceEntityKey))
      .toList(growable: false);
}

String importOperationLabel(ImportOperationKind kind) {
  return switch (kind) {
    ImportOperationKind.expense => '普通支出',
    ImportOperationKind.income => '普通收入',
    ImportOperationKind.transfer => '转账',
    ImportOperationKind.refund => '退款',
    ImportOperationKind.reimbursementAdvance => '报销垫付',
    ImportOperationKind.reimbursementReceipt => '报销到账',
    ImportOperationKind.reimbursementClose => '结束报销',
    ImportOperationKind.repayment => '还款',
    ImportOperationKind.interestExpense => '利息支出',
    ImportOperationKind.borrowing => '借入',
    ImportOperationKind.lending => '借出',
    ImportOperationKind.receivableCollection => '收回',
    ImportOperationKind.openingBalance => '债务期初余额',
  };
}

String importFileTypeLabel(ImportSourceFileType fileType) =>
    '${fileType.label}文件';

String formatImportDateTime(DateTime value) => _dateTimeFormat.format(value);

final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
final DateFormat _taskNameFormat = DateFormat('yyyyMMddHHmmss');

TransactionRowPresentation _buildImportPreviewRow(
  ImportPlanReview review,
  ImportGroupReview groupReview,
  Set<int> selectedGroupIndexes, {
  bool showSelectionControls = false,
}) {
  final draft = groupReview.group.topLevel;
  final amountPrefix =
      _isIncomeDraft(draft)
          ? '+'
          : _isExpenseDraft(draft)
          ? '-'
          : '';
  final amount = formatMoney(draft.amount.abs());
  final compactAmount = formatMoney(
    draft.amount.abs(),
    style: MoneyFormatStyle.compact,
  );
  return TransactionRowPresentation(
    transactionId: 'import-group-${groupReview.index}',
    iconKey: _previewIconKey(draft),
    title: _previewTitle(review, groupReview, draft),
    subtitle: _timeFormat.format(draft.occurredAt),
    amountText: '$amountPrefix$amount',
    compactAmountText: '$amountPrefix$compactAmount',
    amountTone:
        _isIncomeDraft(draft)
            ? FinanceTone.income
            : _isExpenseDraft(draft)
            ? FinanceTone.expense
            : FinanceTone.neutral,
    accountFlow: _previewAccountFlow(review, groupReview, draft),
    badges: [
      if (groupReview.group.children.isNotEmpty)
        TransactionBadgePresentation(
          label: '${groupReview.group.children.length} 条子交易',
          tone: FinanceTone.info,
        ),
      if (groupReview.isExactDuplicate)
        const TransactionBadgePresentation(
          label: '已导入',
          tone: FinanceTone.info,
        ),
      if (groupReview.isBlocked)
        const TransactionBadgePresentation(
          label: '需处理',
          tone: FinanceTone.equity,
        ),
      if (groupReview.isSuspectedDuplicate && !groupReview.isBlocked)
        const TransactionBadgePresentation(
          label: '疑似重复',
          tone: FinanceTone.equity,
        ),
      if (groupReview.hasWarnings &&
          !groupReview.isSuspectedDuplicate &&
          !groupReview.isBlocked)
        const TransactionBadgePresentation(
          label: '需确认',
          tone: FinanceTone.equity,
        ),
    ],
    canQuickEdit: false,
    selectable: showSelectionControls && groupReview.canSelect,
    selected: selectedGroupIndexes.contains(groupReview.index),
    dimmed: !selectedGroupIndexes.contains(groupReview.index),
  );
}

String _previewTitle(
  ImportPlanReview review,
  ImportGroupReview groupReview,
  ImportTransactionDraft draft,
) {
  return switch (draft) {
    ImportExpenseDraft draft => _categoryLabel(
      review,
      groupReview,
      draft.category,
    ),
    ImportIncomeDraft draft => _categoryLabel(
      review,
      groupReview,
      draft.category,
    ),
    ImportReimbursementAdvanceDraft draft => _categoryLabel(
      review,
      groupReview,
      draft.category,
    ),
    _ => importOperationLabel(draft.operationKind),
  };
}

TransactionAccountFlowPresentation _previewAccountFlow(
  ImportPlanReview review,
  ImportGroupReview groupReview,
  ImportTransactionDraft draft,
) {
  AccountEndpointPresentation? endpoint(ImportAccountReference reference) {
    if (reference.isExplicitNone) {
      return const AccountEndpointPresentation(label: '无账户');
    }
    final key = reference.sourceEntityKey;
    if (key == null) {
      final label = reference.displayName?.trim();
      return AccountEndpointPresentation(
        label: label == null || label.isEmpty ? '未映射账户' : label,
      );
    }
    return AccountEndpointPresentation(
      label: _mappingLabel(review, groupReview, key),
    );
  }

  return switch (draft) {
    ImportExpenseDraft draft => TransactionAccountFlowPresentation(
      out: endpoint(draft.paidFrom),
    ),
    ImportIncomeDraft draft => TransactionAccountFlowPresentation(
      in_: endpoint(draft.receiveAccount),
    ),
    ImportRefundDraft draft => TransactionAccountFlowPresentation(
      in_: endpoint(draft.refundTo),
    ),
    ImportReimbursementAdvanceDraft draft => TransactionAccountFlowPresentation(
      out: endpoint(draft.paidFrom),
      in_: endpoint(draft.receivableAccount),
      separator: '|',
    ),
    ImportReimbursementReceiptDraft draft => TransactionAccountFlowPresentation(
      out: endpoint(draft.receivableAccount),
      in_: endpoint(draft.receiveAccount),
    ),
    ImportReimbursementCloseDraft draft => TransactionAccountFlowPresentation(
      out: endpoint(draft.receivableAccount),
      in_: endpoint(draft.receiveAccount),
    ),
    ImportTransferDraft draft => TransactionAccountFlowPresentation(
      out: endpoint(draft.fromAccount),
      in_: endpoint(draft.toAccount),
    ),
    ImportRepaymentDraft draft => TransactionAccountFlowPresentation(
      out: endpoint(draft.paidFrom),
      in_: endpoint(draft.liabilityAccount),
    ),
    ImportInterestExpenseDraft draft => TransactionAccountFlowPresentation(
      out: endpoint(draft.paidFrom),
    ),
    ImportBorrowingDraft draft => TransactionAccountFlowPresentation(
      out: endpoint(draft.liabilityAccount),
      in_: endpoint(draft.receiveAccount),
    ),
    ImportLendingDraft draft => TransactionAccountFlowPresentation(
      out: endpoint(draft.paidFrom),
      in_: endpoint(draft.receivableAccount),
    ),
    ImportReceivableCollectionDraft draft => TransactionAccountFlowPresentation(
      out: endpoint(draft.receivableAccount),
      in_: endpoint(draft.receiveAccount),
    ),
    ImportOpeningBalanceDraft draft => TransactionAccountFlowPresentation(
      in_: endpoint(draft.account),
    ),
  };
}

String _categoryLabel(
  ImportPlanReview review,
  ImportGroupReview groupReview,
  ImportCategoryReference category,
) {
  return _mappingLabel(
    review,
    groupReview,
    category.sourceEntityKey,
    fallback: category.path,
  );
}

String _mappingLabel(
  ImportPlanReview review,
  ImportGroupReview groupReview,
  String sourceEntityKey, {
  String? fallback,
}) {
  ImportSourceEntity? entity;
  for (final candidate in review.plan.sourceEntities) {
    if (candidate.sourceEntityKey == sourceEntityKey) {
      entity = candidate;
      break;
    }
  }
  if (entity == null) return fallback ?? sourceEntityKey;
  final key = ImportMappingKey.fromEntity(entity);
  final targetId =
      groupReview.effectiveMappings[key] ?? review.effectiveMappings[key];
  if (targetId != null) {
    for (final target in review.targets) {
      if (target.id == targetId) {
        return target.effectiveDescriptor == ImportTargetDescriptor.ghostAccount
            ? '无账户'
            : target.displayPath;
      }
    }
  }
  return fallback ?? entity.displayName;
}

bool _isIncomeDraft(ImportTransactionDraft draft) {
  return draft is ImportIncomeDraft ||
      draft is ImportRefundDraft ||
      draft is ImportReimbursementReceiptDraft;
}

bool _isExpenseDraft(ImportTransactionDraft draft) {
  return draft is ImportExpenseDraft || draft is ImportInterestExpenseDraft;
}

String? _previewIconKey(ImportTransactionDraft draft) {
  return switch (draft.operationKind) {
    ImportOperationKind.transfer => 'transfer',
    ImportOperationKind.repayment => 'loan',
    ImportOperationKind.borrowing => 'hand-coin-line',
    ImportOperationKind.lending => 'logout-box-r-line',
    ImportOperationKind.receivableCollection => 'login-box-r-line',
    ImportOperationKind.openingBalance => 'wallet-line',
    _ => null,
  };
}

final DateFormat _timeFormat = DateFormat('HH:mm');
