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

List<TransactionDayGroup> buildImportPreviewGroups(ImportPlanReview review) {
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
        .add(_buildImportPreviewRow(review, groupReview));
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
    ImportOperationKind.openingBalance => '债务期初余额',
  };
}

String importFileRoleLabel(YimuFileRole role) {
  return switch (role) {
    YimuFileRole.bill => '账单文件',
    YimuFileRole.transfer => '转账文件',
    YimuFileRole.debt => '债务文件',
  };
}

String formatImportDateTime(DateTime value) => _dateTimeFormat.format(value);

final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
final DateFormat _taskNameFormat = DateFormat('yyyyMMddHHmmss');

TransactionRowPresentation _buildImportPreviewRow(
  ImportPlanReview review,
  ImportGroupReview groupReview,
) {
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
      if (groupReview.hasWarnings && !groupReview.isBlocked)
        const TransactionBadgePresentation(
          label: '需确认',
          tone: FinanceTone.equity,
        ),
    ],
    canQuickEdit: false,
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
    ImportOpeningBalanceDraft draft => TransactionAccountFlowPresentation(
      in_: endpoint(draft.liabilityAccount),
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
      if (target.id == targetId) return target.displayPath;
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
    ImportOperationKind.openingBalance => 'wallet-line',
    _ => null,
  };
}

final DateFormat _timeFormat = DateFormat('HH:mm');
