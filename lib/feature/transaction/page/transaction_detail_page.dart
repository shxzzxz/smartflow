import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/provider.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../action_policy/transaction_action_policy.dart';
import '../provider/transaction_action_policy_provider.dart';
import '../../../widget/business/account_endpoint_view.dart';
import '../../../widget/business/account_lookup.dart';
import '../../../widget/business/business_icon.dart';
import '../../../widget/business/business_icon_bubble.dart';
import '../../../widget/business/finance_labels.dart';
import '../../../widget/business/money_text.dart';
import '../../../widget/business/plain_transaction_fields.dart';

class TransactionDetailPage extends ConsumerWidget {
  const TransactionDetailPage({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(transactionDetailProvider(transactionId));
    final detailValue = detailAsync.value;
    final policy =
        detailValue == null
            ? null
            : ref.watch(
              transactionActionPolicyProvider(detailValue.transaction),
            );

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('交易详情'),
        actions: [
          if (policy != null)
            IconButton(
              onPressed: () => _confirmDelete(context, policy),
              icon: const Icon(RemixIcons.more_2_line),
              tooltip: '更多',
            ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('交易不存在'));
          }
          return _DetailBody(detail: detail, policy: policy!);
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TransactionActionPolicy policy,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('删除交易'),
            content: const Text('删除后会写入冲销记录，历史链路仍可追溯。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    final result = await policy.delete();
    if (!context.mounted) return;
    result.when(
      success: (_) => context.pop(),
      failure:
          (failure) => ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('删除失败：${failure.message}'))),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail, required this.policy});

  final TransactionDetail detail;
  final TransactionActionPolicy policy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = detail.transaction;
    final purpose = transaction.businessPurpose;
    final semantic = _semanticForPurpose(purpose);
    final accountsById =
        ref.watch(accountsByIdProvider).value ?? const <String, Account>{};
    final accountRows = _resolveAccountRows(detail, accountsById);
    final settlementAccounts =
        ref.watch(accountsForUsageProvider(AccountUsage.settlement)).value ??
        const <Account>[];
    final reimbursementAccounts =
        ref.watch(accountsForUsageProvider(AccountUsage.reimbursement)).value ??
        const <Account>[];

    final showRefund = purpose == BusinessPurpose.dailyExpense;
    final showReimbursement = purpose == BusinessPurpose.reimbursementAdvance;
    final banner = policy.displayBanner();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space16,
              AppSpacing.space12,
              AppSpacing.space16,
              AppSpacing.space24,
            ),
            children: [
              _HeroCard(detail: detail, semantic: semantic),
              if (banner != null) ...[
                const SizedBox(height: AppSpacing.space12),
                _HandlerBanner(text: banner),
              ],
              if (showRefund || showReimbursement) ...[
                const SizedBox(height: AppSpacing.space12),
                _RefundReimbursementCard(
                  detail: detail,
                  showRefund: showRefund,
                  showReimbursement: showReimbursement,
                ),
              ],
              const SizedBox(height: AppSpacing.space12),
              _PrimaryMetaCard(
                detail: detail,
                accountRows: accountRows,
                onOccurredAtTap: _resolveTap(
                  context,
                  EditableField.occurredAt,
                  () => _editOccurredAt(context),
                ),
                onAccountTap:
                    (row) => _handleAccountTap(
                      context,
                      ref,
                      row,
                      settlementAccounts: settlementAccounts,
                      reimbursementAccounts: reimbursementAccounts,
                    ),
                onNoteTap: _resolveTap(
                  context,
                  EditableField.note,
                  () => _editNote(context),
                ),
              ),
              if (detail.history.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space12),
                _HistoryCard(detail: detail),
              ],
              if (_showsExclusionCard(detail)) ...[
                const SizedBox(height: AppSpacing.space12),
                _ExclusionCard(detail: detail),
              ],
            ],
          ),
        ),
        _ActionBar(detail: detail, policy: policy),
      ],
    );
  }

  VoidCallback _resolveTap(
    BuildContext context,
    EditableField field,
    Future<void> Function() editor,
  ) {
    final permission = policy.canEdit(field);
    if (permission.isAllowed) {
      return () => editor();
    }
    return () => _showDenied(context, permission.deniedReason);
  }

  void _handleAccountTap(
    BuildContext context,
    WidgetRef ref,
    _AccountRowInfo row, {
    required List<Account> settlementAccounts,
    required List<Account> reimbursementAccounts,
  }) {
    if (row.editKind == _AccountEditKind.settlement) {
      final permission = policy.canEdit(EditableField.settlementAccount);
      if (!permission.isAllowed) {
        _showDenied(context, permission.deniedReason);
        return;
      }
    }
    _editAccount(
      context,
      ref,
      row,
      settlementAccounts: settlementAccounts,
      reimbursementAccounts: reimbursementAccounts,
    );
  }

  void _showDenied(BuildContext context, String? reason) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(reason ?? '此字段在当前上下文不可编辑')));
  }

  Future<void> _editNote(BuildContext context) async {
    final current = detail.transaction.note ?? '';
    final controller = TextEditingController(text: current);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('编辑备注'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '为这笔交易写点备注',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    await WidgetsBinding.instance.endOfFrame;
    controller.dispose();
    if (!context.mounted) return;
    if (updated == null) return;
    if (updated == current) return;

    final result = await policy.changeNote(updated.isEmpty ? null : updated);
    if (!context.mounted) return;
    _showResultSnackBar(context, result, success: '备注已更新');
  }

  Future<void> _editOccurredAt(BuildContext context) async {
    final current = detail.transaction.occurredAt;
    final updated = await showAppDateTimePicker(
      context: context,
      initialDateTime: current,
      title: '选择交易时间',
    );
    if (updated == null || !context.mounted) return;
    if (updated == current) return;
    final result = await policy.changeOccurredAt(updated);
    if (!context.mounted) return;
    _showResultSnackBar(context, result, success: '交易时间已更新');
  }

  Future<void> _editAccount(
    BuildContext context,
    WidgetRef ref,
    _AccountRowInfo row, {
    required List<Account> settlementAccounts,
    required List<Account> reimbursementAccounts,
  }) async {
    final options =
        row.editKind == _AccountEditKind.reimbursement
            ? reimbursementAccounts
            : settlementAccounts;
    final selectedId = await showAccountPickerSheet(
      context: context,
      title: '选择${row.label}',
      accounts: options,
      selectedId: row.accountId,
    );
    if (selectedId == null || selectedId == row.accountId) return;
    final Result<dynamic> result;
    if (row.editKind == _AccountEditKind.settlement) {
      result = await policy.changeSettlementAccount(selectedId);
    } else {
      // reimbursement 账户变更属 reimbursementAdvance 流图原语自身的字段，
      result = await ref
          .read(transactionCorrectionAppServiceProvider)
          .correctReimbursementAdvance(
            CorrectReimbursementAdvanceCommand(
              transactionId: detail.transaction.id,
              receivableAccountId: selectedId,
            ),
          );
    }
    if (!context.mounted) return;
    _showResultSnackBar(context, result, success: '${row.label}已更新');
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.detail, required this.semantic});

  final TransactionDetail detail;
  final MoneySemantic semantic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = detail.transaction;
    final textStyles = context.appTextStyles;
    final accountsById =
        ref.watch(accountsByIdProvider).value ?? const <String, Account>{};
    final categoryName = _resolveCategoryName(detail, accountsById);
    final iconKey = _resolveCategoryIconKey(detail, accountsById);
    final subtitle = _resolveHeroSubtitle(detail);

    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Row(
          children: [
            BusinessIconBubble(child: BusinessIcon(iconKey: iconKey, size: 28)),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryName ??
                        transactionPurposeLabel(transaction.businessPurpose),
                    style: textStyles.subsectionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.space4),
                    Text(
                      subtitle,
                      style: textStyles.listSupporting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space12),
            MoneyText(
              money: _signedAmount(transaction.primaryAmount, semantic),
              showSign: semantic == MoneySemantic.income,
              semantic: semantic,
              style: textStyles.amountPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _RefundReimbursementCard extends StatelessWidget {
  const _RefundReimbursementCard({
    required this.detail,
    required this.showRefund,
    required this.showReimbursement,
  });

  final TransactionDetail detail;
  final bool showRefund;
  final bool showReimbursement;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (showRefund) {
      final refunded = detail.refundedTotal;
      final hasRefund = refunded != null && refunded.minorUnits > 0;
      rows.add(
        AppPlainValueRow(
          label: '退款金额',
          value: hasRefund ? null : '无退款',
          enabled: hasRefund,
          onTap:
              hasRefund
                  ? () => _showRefundList(context, detail.children)
                  : null,
          child:
              hasRefund
                  ? MoneyText(
                    money: refunded,
                    semantic: MoneySemantic.income,
                    style: context.appTextStyles.formPlainValue,
                  )
                  : null,
        ),
      );
    }
    if (showReimbursement) {
      final summary = detail.reimbursementSummary;
      final hasActivity =
          summary != null && summary.receivedAmount.minorUnits > 0;
      final value =
          summary == null
              ? '未报销'
              : summary.isClosed
              ? '已结束 · 实收 ${summary.receivedAmount.format()}'
              : hasActivity
              ? '已收 ${summary.receivedAmount.format()} / 应收 ${summary.advanceAmount.format()}'
              : '未报销';
      rows.add(
        AppPlainValueRow(
          label: '报销详情',
          value: value,
          enabled: hasActivity,
          onTap:
              hasActivity
                  ? () => _showReimbursementList(context, detail.children)
                  : null,
        ),
      );
    }

    return _RowCard(rows: rows);
  }

  void _showRefundList(
    BuildContext context,
    List<TransactionListItem> children,
  ) {
    final refunds =
        children
            .where((c) => c.businessPurpose == BusinessPurpose.refund)
            .map(_listItemToSheet)
            .toList();
    _showChildrenSheet(context, title: '退款记录', items: refunds);
  }

  void _showReimbursementList(
    BuildContext context,
    List<TransactionListItem> children,
  ) {
    final receipts =
        children
            .where(
              (c) =>
                  c.businessPurpose == BusinessPurpose.reimbursementReceipt ||
                  c.businessPurpose == BusinessPurpose.reimbursementClose,
            )
            .map(_listItemToSheet)
            .toList();
    _showChildrenSheet(context, title: '报销记录', items: receipts);
  }

  _SheetItem _listItemToSheet(TransactionListItem c) => _SheetItem(
    id: c.id,
    purpose: c.businessPurpose,
    occurredAt: c.occurredAt,
    primaryAmount: c.primaryAmount,
  );
}

class _PrimaryMetaCard extends StatelessWidget {
  const _PrimaryMetaCard({
    required this.detail,
    required this.accountRows,
    required this.onOccurredAtTap,
    required this.onAccountTap,
    required this.onNoteTap,
  });

  final TransactionDetail detail;
  final List<_AccountRowInfo> accountRows;
  final VoidCallback onOccurredAtTap;
  final ValueChanged<_AccountRowInfo> onAccountTap;
  final VoidCallback onNoteTap;

  @override
  Widget build(BuildContext context) {
    final transaction = detail.transaction;
    final note = transaction.note;
    final hasNote = note != null && note.isNotEmpty;
    final colors = Theme.of(context).colorScheme;

    final rows = <Widget>[
      AppPlainValueRow(
        label: '交易时间',
        value: _formatDateTime(transaction.occurredAt),
        onTap: onOccurredAtTap,
      ),
      AppPlainValueRow(label: '创建时间', value: _formatDateTime(detail.createdAt)),
      for (final accountRow in accountRows)
        AppPlainValueRow(
          label: accountRow.label,
          onTap:
              accountRow.editKind == null
                  ? null
                  : () => onAccountTap(accountRow),
          child: AccountEndpointView(
            endpoint: accountRow.endpoint,
            style: context.appTextStyles.formPlainValue,
          ),
        ),
      AppPlainValueRow(
        label: '备注',
        value: hasNote ? note : '点击添加备注',
        valueColor: hasNote ? null : colors.onSurfaceVariant,
        onTap: onNoteTap,
      ),
    ];

    return _RowCard(rows: rows);
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.detail});

  final TransactionDetail detail;

  @override
  Widget build(BuildContext context) {
    return _RowCard(
      rows: [
        AppPlainValueRow(
          label: '历史链路',
          value: '${detail.history.length} 条记录',
          onTap:
              () => _showChildrenSheet(
                context,
                title: '历史链路',
                items: [
                  for (final h in detail.history)
                    _SheetItem(
                      id: h.id,
                      purpose: h.businessPurpose,
                      occurredAt: h.occurredAt,
                      primaryAmount: h.primaryAmount,
                    ),
                ],
              ),
        ),
      ],
    );
  }
}

class _ExclusionCard extends ConsumerWidget {
  const _ExclusionCard({required this.detail});

  final TransactionDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = detail.transaction;
    final rows = <Widget>[
      if (transaction.businessPurpose == BusinessPurpose.dailyExpense ||
          transaction.businessPurpose == BusinessPurpose.dailyIncome)
        AppPlainSwitchRow(
          label: '不计入收支',
          value: transaction.isExcludedFromStats,
          onChanged: (next) => _toggleExcludeStats(context, ref, next),
        ),
      if (transaction.businessPurpose == BusinessPurpose.dailyExpense)
        AppPlainSwitchRow(
          label: '不计入预算',
          value: transaction.isExcludedFromBudget,
          onChanged: (next) => _toggleExcludeBudget(context, ref, next),
        ),
    ];
    return _RowCard(rows: rows);
  }

  Future<void> _toggleExcludeStats(
    BuildContext context,
    WidgetRef ref,
    bool next,
  ) async {
    final result = await ref
        .read(transactionUpdateAppServiceProvider)
        .updateReportingFlag(
          UpdateTransactionReportingFlagCommand(
            transactionId: detail.transaction.id,
            isExcludedFromStats: next,
          ),
        );
    if (!context.mounted) return;
    _showResultSnackBar(context, result, success: null);
  }

  Future<void> _toggleExcludeBudget(
    BuildContext context,
    WidgetRef ref,
    bool next,
  ) async {
    final result = await ref
        .read(transactionUpdateAppServiceProvider)
        .updateReportingFlag(
          UpdateTransactionReportingFlagCommand(
            transactionId: detail.transaction.id,
            isExcludedFromBudget: next,
          ),
        );
    if (!context.mounted) return;
    _showResultSnackBar(context, result, success: null);
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space6,
        ),
        child: AppPlainFormSection(children: rows),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.detail, required this.policy});

  final TransactionDetail detail;
  final TransactionActionPolicy policy;

  @override
  Widget build(BuildContext context) {
    final transaction = detail.transaction;
    final purpose = transaction.businessPurpose;
    final closed = detail.reimbursementSummary?.isClosed ?? false;

    final actions = <Widget>[];
    switch (purpose) {
      case BusinessPurpose.dailyExpense:
        actions.add(
          _SecondaryAction(
            label: '退款',
            onPressed:
                () => context.push('/transaction/${transaction.id}/refund'),
          ),
        );
      case BusinessPurpose.reimbursementAdvance:
        if (!closed) {
          actions.add(
            _SecondaryAction(
              label: '退款',
              onPressed:
                  () => context.push('/transaction/${transaction.id}/refund'),
            ),
          );
        }
        actions.add(
          _SecondaryAction(
            label: '报销',
            onPressed:
                closed
                    ? () => _showReimbursementClosed(context)
                    : () => _showReimbursementDialog(context, detail),
          ),
        );
      default:
        break;
    }
    final editPath = policy.editRoutePath();
    actions.add(
      _PrimaryAction(
        label: '编辑',
        onPressed: editPath.isEmpty ? null : () => _openEdit(context, editPath),
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space12,
          AppSpacing.space16,
          AppSpacing.space12,
        ),
        child: Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.space12),
              Expanded(child: actions[i]),
            ],
          ],
        ),
      ),
    );
  }

  void _showReimbursementClosed(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('报销已结束')));
  }

  Future<void> _openEdit(BuildContext context, String editPath) async {
    final result = await context.push<String>(editPath);
    if (!context.mounted || result == null) {
      return;
    }
    context.replace('/transaction/$result');
  }

  void _showReimbursementDialog(
    BuildContext context,
    TransactionDetail detail,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _ReimbursementDialog(detail: detail),
    );
  }
}

class _ReimbursementDialog extends ConsumerStatefulWidget {
  const _ReimbursementDialog({required this.detail});

  final TransactionDetail detail;

  @override
  ConsumerState<_ReimbursementDialog> createState() =>
      _ReimbursementDialogState();
}

class _ReimbursementDialogState extends ConsumerState<_ReimbursementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _closeReimbursement = true;
  bool _submitting = false;
  String? _receiveAccountId;
  late DateTime _occurredAt;

  @override
  void initState() {
    super.initState();
    _occurredAt = DateTime.now();
    final outstanding = widget.detail.reimbursementSummary?.outstanding;
    if (outstanding != null) {
      _amountController.text = outstanding.format();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final receiveAccounts =
        ref.watch(accountsForUsageProvider(AccountUsage.settlement)).value ??
        const <Account>[];
    final selectedAccountId = _effectiveAccountId(
      _receiveAccountId,
      receiveAccounts,
    );
    final selectedAccount = _findAccount(selectedAccountId, receiveAccounts);
    final summary = widget.detail.reimbursementSummary;
    final outstanding = summary?.outstanding;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusXl),
      ),
      title: const Text('报销'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DialogRowCard(
                  rows: [
                    if (outstanding != null)
                      _DialogValueRow(
                        label: '剩余应收',
                        child: Text(
                          outstanding.format(),
                          textAlign: TextAlign.right,
                          style: context.appTextStyles.detailValue,
                        ),
                      ),
                    FormField<String>(
                      initialValue: selectedAccountId,
                      validator: (_) {
                        final amount = _parseAmountOrNull();
                        if (amount != null &&
                            amount.minorUnits > 0 &&
                            selectedAccountId == null) {
                          return '请选择到账账户';
                        }
                        return null;
                      },
                      builder: (field) {
                        return _DialogValueRow(
                          label: '到账账户',
                          onTap: () => _pickReceiveAccount(receiveAccounts),
                          errorText: field.errorText,
                          child:
                              selectedAccount == null
                                  ? Text(
                                    '请选择账户',
                                    textAlign: TextAlign.right,
                                    style: context.appTextStyles.detailValue
                                        .copyWith(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                        ),
                                  )
                                  : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      BusinessIcon(
                                        iconKey: selectedAccount.iconKey,
                                        size: 20,
                                      ),
                                      const SizedBox(width: AppSpacing.space8),
                                      Flexible(
                                        child: Text(
                                          selectedAccount.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              context.appTextStyles.detailValue,
                                        ),
                                      ),
                                    ],
                                  ),
                        );
                      },
                    ),
                    _DialogValueRow(
                      label: '报销金额',
                      child: TextFormField(
                        controller: _amountController,
                        decoration: _dialogInlineInputDecoration(context),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        validator: _validateAmount,
                        textAlign: TextAlign.right,
                        style: context.appTextStyles.detailValue,
                      ),
                    ),
                    _DialogValueRow(
                      label: '备注',
                      alignTop: true,
                      child: TextFormField(
                        controller: _noteController,
                        decoration: _dialogInlineInputDecoration(
                          context,
                          hintText: '点击填写备注',
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.right,
                        style: context.appTextStyles.detailValue,
                      ),
                    ),
                    _DialogValueRow(
                      label: '报销时间',
                      onTap: _pickOccurredAt,
                      child: Text(
                        _formatDateTime(_occurredAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: context.appTextStyles.detailValue,
                      ),
                    ),
                    _DialogValueRow(
                      label: '结束报销',
                      child: Switch(
                        value: _closeReimbursement,
                        onChanged:
                            (value) =>
                                setState(() => _closeReimbursement = value),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : () => _submit(selectedAccountId),
          child:
              _submitting
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('保存'),
        ),
      ],
    );
  }

  Money? _parseAmountOrNull() {
    try {
      return Money.parse(_amountController.text);
    } on FormatException {
      return null;
    }
  }

  Future<void> _pickReceiveAccount(List<Account> accounts) async {
    final picked = await showAccountPickerSheet(
      context: context,
      title: '报销到账账户',
      accounts: accounts,
      selectedId: _effectiveAccountId(_receiveAccountId, accounts),
    );
    if (picked == null || !mounted) return;
    setState(() => _receiveAccountId = picked);
  }

  String? _validateAmount(String? value) {
    final amount = _parseAmountOrNull();
    if (amount == null) {
      return '请输入有效金额';
    }
    if (_closeReimbursement) {
      return amount.minorUnits >= 0 ? null : '金额不能小于 0';
    }
    if (amount.minorUnits <= 0) {
      return '金额必须大于 0';
    }
    final outstanding = widget.detail.reimbursementSummary?.outstanding;
    if (outstanding != null && amount.minorUnits > outstanding.minorUnits) {
      return '到账金额不能超过剩余应收';
    }
    return null;
  }

  Future<void> _pickOccurredAt() async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: _occurredAt,
      title: '选择报销时间',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _occurredAt = picked;
    });
  }

  Future<void> _submit(String? selectedAccountId) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final accountsById =
        ref.read(accountsByIdProvider).value ?? const <String, Account>{};
    final receivableAccountId = _resolveReceivableAccountId(
      widget.detail,
      accountsById,
    );
    if (receivableAccountId == null) {
      _showFailure('无法定位报销账户');
      return;
    }
    final amount = Money.parse(_amountController.text);
    final receiveAccountId = selectedAccountId ?? receivableAccountId;
    setState(() => _submitting = true);
    final service = ref.read(transactionPostingAppServiceProvider);
    final note = _blankToNull(_noteController.text);
    final Result<PostedTransactionResult> result =
        _closeReimbursement
            ? await service.closeReimbursement(
              CloseReimbursementCommand(
                actualReceivedAmount: amount,
                advanceTransactionId: widget.detail.transaction.id,
                receivableAccountId: receivableAccountId,
                receiveAccountId: receiveAccountId,
                occurredAt: _occurredAt,
                note: note,
              ),
            )
            : await service.createReimbursementReceipt(
              CreateReimbursementReceiptCommand(
                amount: amount,
                advanceTransactionId: widget.detail.transaction.id,
                receivableAccountId: receivableAccountId,
                receiveAccountId: receiveAccountId,
                occurredAt: _occurredAt,
                note: note,
              ),
            );
    if (!mounted) return;
    setState(() => _submitting = false);
    result.when(
      success: (_) => Navigator.of(context).pop(),
      failure: (failure) => _showFailure(failure.message),
    );
  }

  void _showFailure(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.space48,
      child: FilledButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.space48,
      child: OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

class _HandlerBanner extends StatelessWidget {
  const _HandlerBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = context.appTextStyles;
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space12),
        child: Row(
          children: [
            Icon(
              RemixIcons.information_2_line,
              color: colors.primary,
              size: AppSpacing.space20,
            ),
            const SizedBox(width: AppSpacing.space8),
            Expanded(
              child: Text(
                text,
                style: styles.listSupporting.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogRowCard extends StatelessWidget {
  const _DialogRowCard({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.space4),
          rows[i],
        ],
      ],
    );
  }
}

class _DialogValueRow extends StatelessWidget {
  const _DialogValueRow({
    required this.label,
    required this.child,
    this.onTap,
    this.errorText,
    this.alignTop = false,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final String? errorText;
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment:
                alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: context.appTextStyles.detailLabel.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.space16),
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: child),
              ),
            ],
          ),
          if (errorText != null) ...[
            const SizedBox(height: AppSpacing.space4),
            Text(
              errorText!,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return row;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.radiusLg),
      child: row,
    );
  }
}

class _AccountRowInfo {
  const _AccountRowInfo({
    required this.label,
    required this.accountId,
    required this.endpoint,
    this.editKind,
  });

  final String label;
  final String accountId;
  final AccountEndpoint endpoint;
  final _AccountEditKind? editKind;
}

enum _AccountEditKind { settlement, reimbursement }

List<_AccountRowInfo> _resolveAccountRows(
  TransactionDetail detail,
  Map<String, Account> accountsById,
) {
  final purpose = detail.transaction.businessPurpose;
  final entries = detail.entries;
  final asset =
      entries.where((e) {
        final type = accountsById[e.accountId]?.type;
        return type == AccountType.asset || type == AccountType.liability;
      }).toList();

  _AccountRowInfo info(
    String label,
    Entry entry, {
    _AccountEditKind? editKind,
  }) {
    return _AccountRowInfo(
      label: label,
      accountId: entry.accountId,
      endpoint: _endpointFromEntry(entry, accountsById),
      editKind: editKind,
    );
  }

  _AccountRowInfo placeholderRow(String label, {_AccountEditKind? editKind}) {
    return _AccountRowInfo(
      label: label,
      accountId: '',
      endpoint: const AccountEndpoint(label: '—', iconKey: null),
      editKind: editKind,
    );
  }

  switch (purpose) {
    case BusinessPurpose.transfer:
      if (asset.isEmpty) {
        return [placeholderRow('转出账户'), placeholderRow('转入账户')];
      }
      final from = asset.firstWhere(
        (e) => e.direction == EntryDirection.credit,
        orElse: () => asset.first,
      );
      final to = asset.firstWhere(
        (e) => e.direction == EntryDirection.debit,
        orElse: () => asset.first,
      );
      return [info('转出账户', from), info('转入账户', to)];
    case BusinessPurpose.dailyIncome:
    case BusinessPurpose.refund:
    case BusinessPurpose.reimbursementReceipt:
    case BusinessPurpose.reimbursementClose:
    case BusinessPurpose.borrowing:
      final editKind =
          purpose == BusinessPurpose.dailyIncome ||
                  purpose == BusinessPurpose.borrowing
              ? _AccountEditKind.settlement
              : null;
      if (asset.isEmpty) {
        return [placeholderRow('收支账户', editKind: editKind)];
      }
      final inAccount = asset.firstWhere(
        (e) => e.direction == EntryDirection.debit,
        orElse: () => asset.first,
      );
      return [info('收支账户', inAccount, editKind: editKind)];
    case BusinessPurpose.dailyExpense:
    case BusinessPurpose.debtRepayment:
      final label = purpose == BusinessPurpose.debtRepayment ? '还款账户' : '收支账户';
      if (asset.isEmpty) {
        return [placeholderRow(label, editKind: _AccountEditKind.settlement)];
      }
      final outAccount = asset.firstWhere(
        (e) => e.direction == EntryDirection.credit,
        orElse: () => asset.first,
      );
      return [info(label, outAccount, editKind: _AccountEditKind.settlement)];
    case BusinessPurpose.reimbursementAdvance:
      if (asset.isEmpty) {
        return [
          placeholderRow('收支账户', editKind: _AccountEditKind.settlement),
          placeholderRow('报销账户', editKind: _AccountEditKind.reimbursement),
        ];
      }
      final receivable = asset.firstWhere(
        (e) =>
            e.direction == EntryDirection.debit &&
            accountsById[e.accountId]?.type == AccountType.asset,
        orElse: () => asset.first,
      );
      final paidFrom = asset.firstWhere(
        (e) => e.direction == EntryDirection.credit,
        orElse: () => asset.first,
      );
      return [
        info('收支账户', paidFrom, editKind: _AccountEditKind.settlement),
        info('报销账户', receivable, editKind: _AccountEditKind.reimbursement),
      ];
    case BusinessPurpose.openingBalance:
    case BusinessPurpose.balanceAdjustment:
      if (asset.isEmpty) {
        return [placeholderRow('账户')];
      }
      return [info('账户', asset.first)];
  }
}

AccountEndpoint _endpointFromEntry(
  Entry entry,
  Map<String, Account> accountsById,
) {
  final account = accountsById[entry.accountId];
  return AccountEndpoint(
    label: account?.name ?? '—',
    iconKey: account?.iconKey,
  );
}

String? _resolveReceivableAccountId(
  TransactionDetail detail,
  Map<String, Account> accountsById,
) {
  for (final entry in detail.entries) {
    if (accountsById[entry.accountId]?.type == AccountType.asset &&
        entry.direction == EntryDirection.debit) {
      return entry.accountId;
    }
  }
  return null;
}

String? _effectiveAccountId(String? selectedId, List<Account> options) {
  if (selectedId != null &&
      options.any((account) => account.id == selectedId)) {
    return selectedId;
  }
  return options.isEmpty ? null : options.first.id;
}

Account? _findAccount(String? accountId, List<Account> accounts) {
  if (accountId == null) return null;
  for (final account in accounts) {
    if (account.id == accountId) return account;
  }
  return null;
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

InputDecoration _dialogInlineInputDecoration(
  BuildContext context, {
  String? hintText,
}) {
  final colors = Theme.of(context).colorScheme;
  return InputDecoration(
    isDense: true,
    hintText: hintText,
    hintStyle: context.appTextStyles.detailValue.copyWith(
      color: colors.onSurfaceVariant,
    ),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
  );
}

String? _resolveCategoryName(
  TransactionDetail detail,
  Map<String, Account> accountsById,
) {
  final purpose = detail.transaction.businessPurpose;
  Account? categoryAccount;
  if (purpose == BusinessPurpose.dailyExpense ||
      purpose == BusinessPurpose.refund) {
    final entry = firstEntryByType(
      detail.entries,
      accountsById: accountsById,
      accountType: AccountType.expense,
    );
    categoryAccount = entry?.resolveAccount(accountsById);
  } else if (purpose == BusinessPurpose.dailyIncome) {
    final entry = firstEntryByType(
      detail.entries,
      accountsById: accountsById,
      accountType: AccountType.income,
    );
    categoryAccount = entry?.resolveAccount(accountsById);
  } else if (purpose == BusinessPurpose.reimbursementAdvance) {
    final expenseId = detail.transaction.reimbursementExpenseAccountId;
    if (expenseId != null) {
      categoryAccount = accountsById[expenseId];
    }
  }
  return categoryAccount?.name;
}

String? _resolveCategoryIconKey(
  TransactionDetail detail,
  Map<String, Account> accountsById,
) {
  final purpose = detail.transaction.businessPurpose;
  Account? categoryAccount;
  if (purpose == BusinessPurpose.dailyExpense ||
      purpose == BusinessPurpose.refund) {
    final entry = firstEntryByType(
      detail.entries,
      accountsById: accountsById,
      accountType: AccountType.expense,
    );
    categoryAccount = entry?.resolveAccount(accountsById);
  } else if (purpose == BusinessPurpose.dailyIncome) {
    final entry = firstEntryByType(
      detail.entries,
      accountsById: accountsById,
      accountType: AccountType.income,
    );
    categoryAccount = entry?.resolveAccount(accountsById);
  } else if (purpose == BusinessPurpose.reimbursementAdvance) {
    final expenseId = detail.transaction.reimbursementExpenseAccountId;
    if (expenseId != null) {
      categoryAccount = accountsById[expenseId];
    }
  }
  if (categoryAccount?.iconKey != null &&
      categoryAccount!.iconKey!.isNotEmpty) {
    return categoryAccount.iconKey;
  }
  final name = categoryAccount?.name;
  return switch (name) {
    '茶叶' || '咖啡' => 'coffee',
    '早餐' => 'breakfast',
    '午餐' => 'lunch',
    '晚餐' => 'dinner',
    '饮料酒水' => 'drink',
    '休闲零食' => 'snack',
    '生鲜食品' => 'seafood',
    '粮油调味' => 'seasoning',
    '购物消费' || '日用品' || '衣物' => 'shopping',
    '地铁' || '公交' || '出行交通' => 'metro',
    '打车' => 'taxi',
    '文化教育' || '书籍' => 'book',
    '休闲娱乐' || '电影' => 'movie',
    '工资' || '兼职' => 'salary',
    '家里' || '居家生活' || '房租' || '水电' || '物业' => 'home',
    '人情社交' => 'social',
    '送礼人情' => 'gift',
    '健康医疗' => 'health',
    _ => null,
  };
}

String? _resolveHeroSubtitle(TransactionDetail detail) {
  final transaction = detail.transaction;
  final counterparty = transaction.counterpartyName;
  if (counterparty != null && counterparty.isNotEmpty) {
    return counterparty;
  }
  return null;
}

MoneySemantic _semanticForPurpose(BusinessPurpose purpose) {
  return switch (purpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.reimbursementAdvance ||
    BusinessPurpose.debtRepayment => MoneySemantic.expense,
    BusinessPurpose.dailyIncome ||
    BusinessPurpose.refund ||
    BusinessPurpose.reimbursementReceipt ||
    BusinessPurpose.reimbursementClose ||
    BusinessPurpose.borrowing => MoneySemantic.income,
    BusinessPurpose.transfer => MoneySemantic.neutral,
    BusinessPurpose.openingBalance ||
    BusinessPurpose.balanceAdjustment => MoneySemantic.neutral,
  };
}

Money _signedAmount(Money money, MoneySemantic semantic) {
  if (semantic == MoneySemantic.expense) {
    return Money(minorUnits: -money.minorUnits);
  }
  return money;
}

bool _showsExclusionCard(TransactionDetail detail) {
  return detail.transaction.businessPurpose == BusinessPurpose.dailyExpense ||
      detail.transaction.businessPurpose == BusinessPurpose.dailyIncome;
}

String _formatDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}年${two(dt.month)}月${two(dt.day)}日 '
      '${two(dt.hour)}:${two(dt.minute)}';
}

class _SheetItem {
  const _SheetItem({
    required this.id,
    required this.purpose,
    required this.occurredAt,
    required this.primaryAmount,
  });

  final String id;
  final BusinessPurpose purpose;
  final DateTime occurredAt;
  final Money primaryAmount;
}

void _showChildrenSheet(
  BuildContext context, {
  required String title,
  required List<_SheetItem> items,
}) {
  if (items.isEmpty) return;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space16,
            0,
            AppSpacing.space16,
            AppSpacing.space12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.space8,
                ),
                child: Text(title, style: ctx.appTextStyles.subsectionTitle),
              ),
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(transactionPurposeLabel(item.purpose)),
                  subtitle: Text(_formatDateTime(item.occurredAt)),
                  trailing: MoneyText(
                    money: _signedAmount(
                      item.primaryAmount,
                      _semanticForPurpose(item.purpose),
                    ),
                    semantic: _semanticForPurpose(item.purpose),
                    showSign:
                        _semanticForPurpose(item.purpose) ==
                        MoneySemantic.income,
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/transaction/${item.id}');
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

void _showResultSnackBar<T>(
  BuildContext context,
  Result<T> result, {
  String? success,
}) {
  final messenger = ScaffoldMessenger.of(context);
  result.when(
    success: (_) {
      if (success != null) {
        messenger.showSnackBar(SnackBar(content: Text(success)));
      }
    },
    failure: (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text('操作失败：${failure.message}')),
      );
    },
  );
}
