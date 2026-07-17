import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import 'package:smartflow/widget/business/account/account_endpoint.dart';
import 'package:smartflow/widget/business/account/account_endpoint_view.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';
import 'package:smartflow/widget/business/icon/business_icon_bubble.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/transaction_detail_presentation.dart';
import '../view_model/transaction_detail_state.dart';
import '../view_model/transaction_detail_view_model.dart';

class TransactionDetailPage extends ConsumerWidget {
  const TransactionDetailPage({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(
      transactionDetailViewModelProvider(transactionId),
    );
    final loaded = stateAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('交易详情'),
        actions: [
          if (loaded is TransactionDetailLoaded)
            IconButton(
              onPressed:
                  loaded.submitting ? null : () => _confirmDelete(context, ref),
              icon: const Icon(RemixIcons.more_2_line),
              tooltip: '更多',
            ),
        ],
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
        data: (state) {
          return switch (state) {
            TransactionDetailNotFound() => const Center(child: Text('交易不存在')),
            TransactionDetailLoaded() => _DetailBody(state: state),
          };
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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
    final outcome =
        await ref
            .read(transactionDetailViewModelProvider(transactionId).notifier)
            .delete();
    if (!context.mounted) return;
    _handleActionOutcome(context, outcome, success: () => context.pop());
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.state});

  final TransactionDetailLoaded state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              _HeroCard(hero: state.hero),
              if (state.behavior.bannerText != null) ...[
                const SizedBox(height: AppSpacing.space12),
                _HandlerBanner(text: state.behavior.bannerText!),
              ],
              if (state.refund != null || state.reimbursement != null) ...[
                const SizedBox(height: AppSpacing.space12),
                _RefundReimbursementCard(
                  refund: state.refund,
                  reimbursement: state.reimbursement,
                ),
              ],
              const SizedBox(height: AppSpacing.space12),
              _PrimaryMetaCard(
                state: state,
                onOccurredAtTap: () => _editOccurredAt(context, ref),
                onPostedAtTap: () => _editPostedAt(context, ref),
                onAccountTap: (row) => _handleAccountTap(context, ref, row),
                onNoteTap: () => _editNote(context, ref),
              ),
              if (state.showExcludeStats || state.showExcludeBudget) ...[
                const SizedBox(height: AppSpacing.space12),
                _ExclusionCard(state: state),
              ],
            ],
          ),
        ),
        _ActionBar(state: state),
      ],
    );
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    switch (state.behavior.canEditNote) {
      case DetailEditDenied(:final reason):
        _showMessage(context, reason);
        return;
      case DetailEditAllowed():
        break;
    }
    final current = state.noteText ?? '';
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
    if (!context.mounted || updated == null || updated == current) return;
    final outcome = await ref
        .read(transactionDetailViewModelProvider(state.transactionId).notifier)
        .changeNote(updated.isEmpty ? null : updated);
    if (!context.mounted) return;
    _handleActionOutcome(context, outcome, successMessage: '备注已更新');
  }

  Future<void> _editOccurredAt(BuildContext context, WidgetRef ref) async {
    switch (state.behavior.canEditOccurredAt) {
      case DetailEditDenied(:final reason):
        _showMessage(context, reason);
        return;
      case DetailEditAllowed():
        break;
    }
    final current = state.detail.transaction.occurredAt;
    final updated = await showAppDateTimePicker(
      context: context,
      initialDateTime: current,
      title: '选择交易时间',
    );
    if (updated == null || !context.mounted || updated == current) return;
    final outcome = await ref
        .read(transactionDetailViewModelProvider(state.transactionId).notifier)
        .changeOccurredAt(updated);
    if (!context.mounted) return;
    _handleActionOutcome(context, outcome, successMessage: '交易时间已更新');
  }

  Future<void> _editPostedAt(BuildContext context, WidgetRef ref) async {
    switch (state.behavior.canEditPostedAt) {
      case DetailEditDenied(:final reason):
        _showMessage(context, reason);
        return;
      case DetailEditAllowed():
        break;
    }
    final current = state.detail.transaction.postedAt;
    final updated = await showAppDateTimePicker(
      context: context,
      initialDateTime: current,
      title: '选择入账时间',
    );
    if (updated == null || !context.mounted || updated == current) return;
    final outcome = await ref
        .read(transactionDetailViewModelProvider(state.transactionId).notifier)
        .changePostedAt(updated);
    if (!context.mounted) return;
    _handleActionOutcome(context, outcome, successMessage: '入账时间已更新');
  }

  Future<void> _handleAccountTap(
    BuildContext context,
    WidgetRef ref,
    DetailAccountRow row,
  ) async {
    final editPurpose = row.editPurpose;
    if (editPurpose == null) return;
    switch (row.permission) {
      case DetailEditDenied(:final reason):
        _showMessage(context, reason);
        return;
      case DetailEditAllowed():
        break;
    }
    final viewModel = ref.read(
      transactionDetailViewModelProvider(state.transactionId).notifier,
    );
    final accounts = await viewModel.accountOptions(editPurpose);
    if (!context.mounted) return;
    final selectedId = await showAccountPickerSheet(
      context: context,
      title: '选择${row.label}',
      accounts: accounts,
      selectedId: row.accountId,
    );
    if (selectedId == null || selectedId == row.accountId) return;
    final outcome = await viewModel.changeAccount(editPurpose, selectedId);
    if (!context.mounted) return;
    _handleActionOutcome(context, outcome, successMessage: '${row.label}已更新');
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.hero});

  final DetailHero hero;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.appTextStyles;
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Row(
          children: [
            BusinessIconBubble(
              child: BusinessIcon(iconKey: hero.iconKey, size: 28),
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hero.title,
                    style: textStyles.subsectionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hero.subtitle != null) ...[
                    const SizedBox(height: AppSpacing.space4),
                    Text(
                      hero.subtitle!,
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
              money: hero.amount,
              showSign: hero.showSign,
              semantic: hero.semantic,
              style: textStyles.amountPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _RefundReimbursementCard extends StatelessWidget {
  const _RefundReimbursementCard({this.refund, this.reimbursement});

  final DetailRefund? refund;
  final DetailReimbursement? reimbursement;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    final refund = this.refund;
    if (refund != null) {
      rows.add(
        AppPlainValueRow(
          label: '退款金额',
          value: refund.hasRefund ? null : '无退款',
          enabled: refund.hasRefund,
          onTap:
              refund.hasRefund
                  ? () => _showChildrenSheet(
                    context,
                    title: '退款记录',
                    items: refund.items,
                  )
                  : null,
          child:
              refund.hasRefund
                  ? MoneyText(
                    money: refund.refundedTotal!,
                    semantic: MoneySemantic.income,
                    style: context.appTextStyles.formPlainValue,
                  )
                  : null,
        ),
      );
    }
    final reimbursement = this.reimbursement;
    if (reimbursement != null) {
      rows.add(
        AppPlainValueRow(
          label: '报销详情',
          value: reimbursement.summaryText,
          enabled: reimbursement.hasActivity,
          onTap:
              reimbursement.hasActivity
                  ? () => _showChildrenSheet(
                    context,
                    title: '报销记录',
                    items: reimbursement.items,
                  )
                  : null,
        ),
      );
    }
    return _RowCard(rows: rows);
  }
}

class _PrimaryMetaCard extends StatelessWidget {
  const _PrimaryMetaCard({
    required this.state,
    required this.onOccurredAtTap,
    required this.onPostedAtTap,
    required this.onAccountTap,
    required this.onNoteTap,
  });

  final TransactionDetailLoaded state;
  final VoidCallback onOccurredAtTap;
  final VoidCallback onPostedAtTap;
  final ValueChanged<DetailAccountRow> onAccountTap;
  final VoidCallback onNoteTap;

  @override
  Widget build(BuildContext context) {
    final note = state.noteText;
    final hasNote = note != null && note.isNotEmpty;
    final colors = Theme.of(context).colorScheme;
    return _RowCard(
      rows: [
        AppPlainValueRow(
          label: '交易时间',
          value: state.occurredAtText,
          onTap: onOccurredAtTap,
        ),
        AppPlainValueRow(
          label: '入账时间',
          value: state.postedAtText,
          onTap: onPostedAtTap,
        ),
        AppPlainValueRow(label: '创建时间', value: state.createdAtText),
        for (final row in state.accountRows)
          AppPlainValueRow(
            label: row.label,
            onTap: row.editPurpose == null ? null : () => onAccountTap(row),
            child: AccountEndpointView(
              endpoint: AccountEndpoint(
                label: row.endpoint.label,
                iconKey: row.endpoint.iconKey,
              ),
              style: context.appTextStyles.formPlainValue,
            ),
          ),
        AppPlainValueRow(
          label: '备注',
          value: hasNote ? note : '点击添加备注',
          valueColor: hasNote ? null : colors.onSurfaceVariant,
          onTap: onNoteTap,
        ),
      ],
    );
  }
}

class _ExclusionCard extends ConsumerWidget {
  const _ExclusionCard({required this.state});

  final TransactionDetailLoaded state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _RowCard(
      rows: [
        if (state.showExcludeStats)
          AppPlainSwitchRow(
            label: '不计入收支',
            value: state.excludeStats,
            onChanged: (next) => _toggleExcludeStats(context, ref, next),
          ),
        if (state.showExcludeBudget)
          AppPlainSwitchRow(
            label: '不计入预算',
            value: state.excludeBudget,
            onChanged: (next) => _toggleExcludeBudget(context, ref, next),
          ),
      ],
    );
  }

  Future<void> _toggleExcludeStats(
    BuildContext context,
    WidgetRef ref,
    bool next,
  ) async {
    final outcome = await ref
        .read(transactionDetailViewModelProvider(state.transactionId).notifier)
        .toggleExcludeStats(next);
    if (!context.mounted) return;
    _handleActionOutcome(context, outcome);
  }

  Future<void> _toggleExcludeBudget(
    BuildContext context,
    WidgetRef ref,
    bool next,
  ) async {
    final outcome = await ref
        .read(transactionDetailViewModelProvider(state.transactionId).notifier)
        .toggleExcludeBudget(next);
    if (!context.mounted) return;
    _handleActionOutcome(context, outcome);
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
  const _ActionBar({required this.state});

  final TransactionDetailLoaded state;

  @override
  Widget build(BuildContext context) {
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
            for (var i = 0; i < state.actionButtons.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.space12),
              Expanded(
                child: _ActionButton(
                  state: state.actionButtons[i],
                  detailState: state,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.state, required this.detailState});

  final DetailActionButton state;
  final TransactionDetailLoaded detailState;

  @override
  Widget build(BuildContext context) {
    final onPressed =
        detailState.submitting ? null : () => _handlePressed(context);
    if (state.primary) {
      return _PrimaryAction(label: state.label, onPressed: onPressed);
    }
    return _SecondaryAction(label: state.label, onPressed: onPressed);
  }

  Future<void> _handlePressed(BuildContext context) async {
    if (!state.enabled) {
      _showMessage(context, state.deniedReason ?? '当前不可操作');
      return;
    }
    switch (state.kind) {
      case DetailActionKind.refund:
        final route = state.route;
        if (route != null) {
          context.push(route);
        }
      case DetailActionKind.reimbursement:
        showDialog<void>(
          context: context,
          builder: (_) => _ReimbursementDialog(state: detailState),
        );
      case DetailActionKind.edit:
        final route = state.route;
        if (route == null) return;
        final result = await context.push<String>(route);
        if (!context.mounted || result == null) {
          return;
        }
        context.replace('/transaction/$result');
    }
  }
}

class _ReimbursementDialog extends ConsumerStatefulWidget {
  const _ReimbursementDialog({required this.state});

  final TransactionDetailLoaded state;

  @override
  ConsumerState<_ReimbursementDialog> createState() =>
      _ReimbursementDialogState();
}

class _ReimbursementDialogState extends ConsumerState<_ReimbursementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _closeReimbursement = true;
  String? _receiveAccountId;
  late DateTime _occurredAt;
  late Future<List<Account>> _receiveAccountsFuture;

  TransactionDetailLoaded get _state => widget.state;

  @override
  void initState() {
    super.initState();
    _occurredAt = DateTime.now();
    _receiveAccountsFuture = ref
        .read(transactionDetailViewModelProvider(_state.transactionId).notifier)
        .accountOptions(AccountSelectionPurpose.settlement);
    final outstanding = _state.reimbursement?.outstanding;
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
    final outstanding = _state.reimbursement?.outstanding;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusXl),
      ),
      title: const Text('报销'),
      content: SizedBox(
        width: 360,
        child: FutureBuilder<List<Account>>(
          future: _receiveAccountsFuture,
          builder: (context, snapshot) {
            final receiveAccounts = snapshot.data ?? const <Account>[];
            final selectedAccountId = _effectiveAccountId(
              _receiveAccountId,
              receiveAccounts,
            );
            final selectedAccount = _findAccount(
              selectedAccountId,
              receiveAccounts,
            );
            return Form(
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
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                      )
                                      : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          BusinessIcon(
                                            iconKey: selectedAccount.iconKey,
                                            size: 20,
                                          ),
                                          const SizedBox(
                                            width: AppSpacing.space8,
                                          ),
                                          Flexible(
                                            child: Text(
                                              selectedAccount.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  context
                                                      .appTextStyles
                                                      .detailValue,
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
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
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
                            formatTransactionDetailDateTime(_occurredAt),
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
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _state.submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _state.submitting ? null : _submit,
          child:
              _state.submitting
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
    final outstanding = _state.reimbursement?.outstanding;
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final receiveAccounts = await _receiveAccountsFuture;
    final selectedAccountId = _effectiveAccountId(
      _receiveAccountId,
      receiveAccounts,
    );
    final amount = Money.parse(_amountController.text);
    final outcome = await ref
        .read(transactionDetailViewModelProvider(_state.transactionId).notifier)
        .submitReimbursement(
          ReimbursementSubmitInput(
            amount: amount,
            receiveAccountId: selectedAccountId,
            occurredAt: _occurredAt,
            closeReimbursement: _closeReimbursement,
            noteText: _noteController.text,
          ),
        );
    if (!mounted) return;
    _handleActionOutcome(
      context,
      outcome,
      success: () => Navigator.of(context).pop(),
    );
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

void _showChildrenSheet(
  BuildContext context, {
  required String title,
  required List<DetailSheetItem> items,
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
                  title: Text(item.title),
                  subtitle: Text(item.occurredAtText),
                  trailing: MoneyText(
                    money: item.amount,
                    semantic: item.semantic,
                    showSign: item.showSign,
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

void _handleActionOutcome(
  BuildContext context,
  UiActionOutcome<void> outcome, {
  VoidCallback? success,
  String? successMessage,
}) {
  switch (outcome) {
    case UiActionSuccess<void>():
      success?.call();
      if (successMessage != null) {
        _showMessage(context, successMessage);
      }
    case UiActionFailure<void>(:final error):
      _showMessage(context, '操作失败：${error.message}');
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
