import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/credit/credit_command_api.dart' as credit;
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../design_system/widget/app_surface.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/bill_repayment_allocation_view_model.dart';
import '../view_model/bill_repayment_form_view_model.dart';
import '../widget/repayment_form_fields.dart';

class BillRepaymentFormPage extends ConsumerStatefulWidget {
  const BillRepaymentFormPage({required this.billId, super.key});

  final String billId;

  @override
  ConsumerState<BillRepaymentFormPage> createState() =>
      _BillRepaymentFormPageState();
}

class _BillRepaymentFormPageState extends ConsumerState<BillRepaymentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _principalController = TextEditingController();
  final _interestController = TextEditingController();
  final _feeController = TextEditingController();
  final _discountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _principalController.addListener(
      () => _setText(
        (vm, value) => vm.setPrincipalText(value),
        _principalController.text,
      ),
    );
    _interestController.addListener(
      () => _setText(
        (vm, value) => vm.setInterestText(value),
        _interestController.text,
      ),
    );
    _feeController.addListener(
      () => _setText((vm, value) => vm.setFeeText(value), _feeController.text),
    );
    _discountController.addListener(
      () => _setText(
        (vm, value) => vm.setDiscountText(value),
        _discountController.text,
      ),
    );
    _noteController.addListener(
      () =>
          _setText((vm, value) => vm.setNoteText(value), _noteController.text),
    );
  }

  @override
  void dispose() {
    _principalController.dispose();
    _interestController.dispose();
    _feeController.dispose();
    _discountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = billRepaymentFormViewModelProvider(widget.billId);
    final asyncState = ref.watch(provider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('账单还款')),
      body: switch (asyncState) {
        AsyncData(value: final state) => _buildState(provider, state),
        AsyncError() => const Center(child: Text('加载失败，请稍后重试')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildState(
    BillRepaymentFormViewModelProvider provider,
    BillRepaymentFormState state,
  ) {
    switch (state.status) {
      case BillRepaymentFormLoadStatus.notFound:
        return const Center(child: Text('账单不存在'));
      case BillRepaymentFormLoadStatus.noPending:
        return const Center(child: Text('账单已结清'));
      case BillRepaymentFormLoadStatus.loaded:
        return _buildLoaded(provider, state);
    }
  }

  Widget _buildLoaded(
    BillRepaymentFormViewModelProvider provider,
    BillRepaymentFormState state,
  ) {
    _syncControllers(state);
    final paidFromAccount = _findAccount(
      state.repaymentAccounts,
      state.paidFromAccountId,
    );
    final review = state.allocationReview;
    final warning = review?.warningMessage;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space18,
          AppSpacing.space16,
          AppSpacing.space24,
        ),
        children: [
          CreditRepaymentFormSection(
            title: '还款信息',
            children: [
              CreditRepaymentAmountFields(
                principalController: _principalController,
                interestController: _interestController,
                feeController: _feeController,
                discountController: _discountController,
              ),
              DropdownPlainFormRow<BillRepaymentAllocationMode>(
                label: '分摊方式',
                value: state.allocationMode,
                items: billRepaymentAllocationModeItems,
                onChanged:
                    (value) =>
                        ref.read(provider.notifier).setAllocationMode(value),
              ),
              CreditRepaymentTransactionFields(
                createTransaction: state.createTransaction,
                onCreateTransactionChanged:
                    (value) =>
                        ref.read(provider.notifier).setCreateTransaction(value),
                occurredAtText: _formatDateTime(state.occurredAt),
                onPickDate: () => _pickDate(provider, state.occurredAt),
                repaymentAccount: paidFromAccount,
                selectedRepaymentAccountId: state.paidFromAccountId,
                repaymentAccounts: state.repaymentAccounts,
                onPickAccount:
                    () => _pickAccount(
                      accounts: state.repaymentAccounts,
                      selectedId: state.paidFromAccountId,
                      onSelected:
                          (id) => ref
                              .read(provider.notifier)
                              .setPaidFromAccountId(id),
                    ),
              ),
              NotePlainFormRow(controller: _noteController),
            ],
          ),
          if (warning != null) ...[
            const SizedBox(height: AppSpacing.space12),
            Text(
              warning,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.space16),
          _AllocationResultSection(
            state: state,
            review: review,
            onCalculate:
                state.allocationMode == BillRepaymentAllocationMode.manual
                    ? null
                    : () => ref.read(provider.notifier).calculateAllocation(),
            onChanged: ({
              required String billItemId,
              required _AllocationAmountField field,
              required Money value,
            }) {
              final text = value.format();
              ref
                  .read(provider.notifier)
                  .setManualAllocationText(
                    billItemId: billItemId,
                    principalText:
                        field == _AllocationAmountField.principal ? text : null,
                    interestText:
                        field == _AllocationAmountField.interest ? text : null,
                    feeText: field == _AllocationAmountField.fee ? text : null,
                    discountText:
                        field == _AllocationAmountField.discount ? text : null,
                  );
            },
          ),
          const SizedBox(height: AppSpacing.space24),
          AppSubmitButton(
            label: '保存',
            loading: state.submitting,
            onPressed: () => _submit(provider),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(
    BillRepaymentFormViewModelProvider provider,
    DateTime occurredAt,
  ) async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: occurredAt,
      title: '选择还款日期',
    );
    if (picked == null || !mounted) return;
    ref.read(provider.notifier).setOccurredAt(picked);
  }

  Future<void> _pickAccount({
    required List<Account> accounts,
    required String? selectedId,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showAccountPickerSheet(
      context: context,
      title: '选择还款账户',
      accounts: accounts,
      selectedId: selectedId,
    );
    if (!mounted || selected == null) return;
    onSelected(selected);
  }

  Future<void> _submit(BillRepaymentFormViewModelProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    final outcome = await ref.read(provider.notifier).submit();
    if (!mounted) return;
    switch (outcome) {
      case SubmitSuccess():
        context.pop(true);
      case SubmitFailure(:final error):
        _showError(error.message);
    }
  }

  void _syncControllers(BillRepaymentFormState state) {
    _syncing = true;
    syncTextControllerText(_principalController, state.principalText);
    syncTextControllerText(_interestController, state.interestText);
    syncTextControllerText(_feeController, state.feeText);
    syncTextControllerText(_discountController, state.discountText);
    syncTextControllerText(_noteController, state.noteText);
    _syncing = false;
  }

  void _setText(
    void Function(BillRepaymentFormViewModel, String) setter,
    String value,
  ) {
    if (_syncing) return;
    setter(
      ref.read(billRepaymentFormViewModelProvider(widget.billId).notifier),
      value,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

const List<DropdownMenuItem<BillRepaymentAllocationMode>>
billRepaymentAllocationModeItems = [
  DropdownMenuItem(
    value: BillRepaymentAllocationMode.fifo,
    child: Text('FIFO'),
  ),
  DropdownMenuItem(value: BillRepaymentAllocationMode.equal, child: Text('均摊')),
  DropdownMenuItem(
    value: BillRepaymentAllocationMode.manual,
    child: Text('手工'),
  ),
];

typedef _ApplyAllocationAmount =
    void Function({
      required String billItemId,
      required _AllocationAmountField field,
      required Money value,
    });

enum _AllocationAmountField { principal, interest, fee, discount }

class _AllocationResultSection extends StatelessWidget {
  const _AllocationResultSection({
    required this.state,
    required this.review,
    required this.onChanged,
    this.onCalculate,
  });

  final BillRepaymentFormState state;
  final BillRepaymentAllocationReview? review;
  final VoidCallback? onCalculate;
  final _ApplyAllocationAmount onChanged;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final unallocated = review?.unallocated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space4,
            0,
            AppSpacing.space4,
            AppSpacing.space6,
          ),
          child: Row(
            children: [
              Expanded(child: Text('分摊结果', style: styles.dateSectionTitle)),
              if (onCalculate != null)
                TextButton.icon(
                  onPressed: onCalculate,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space8,
                      vertical: AppSpacing.space4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    textStyle: styles.listSupporting,
                  ),
                  icon: const Icon(Icons.calculate_outlined, size: 16),
                  label: const Text('计算分摊'),
                ),
            ],
          ),
        ),
        AppSurface(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space10,
              vertical: AppSpacing.space8,
            ),
            child: Column(
              children: [
                _AllocationHeader(),
                Divider(
                  height: 1,
                  color: colors.outlineVariant.withValues(alpha: 0.55),
                ),
                for (var i = 0; i < state.lines.length; i++) ...[
                  _AllocationResultRow(
                    line: state.lines[i],
                    breakdown: _allocationBreakdown(
                      state.manualAllocationText(state.lines[i].billItemId),
                    ),
                    onChanged: onChanged,
                  ),
                  Divider(
                    height: 1,
                    color: colors.outlineVariant.withValues(alpha: 0.35),
                  ),
                ],
                if (unallocated != null && _hasNonZeroAmount(unallocated)) ...[
                  _AllocationSummaryRow(
                    label: '未分摊',
                    breakdown: unallocated,
                    color: colors.error,
                  ),
                  Divider(
                    height: 1,
                    color: colors.outlineVariant.withValues(alpha: 0.35),
                  ),
                ],
                _AllocationSummaryRow(
                  label: '合计',
                  breakdown:
                      review?.totalAllocated ??
                      credit.RepaymentAmountBreakdown.zero,
                  emphasize: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AllocationHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final labelStyle = styles.listSupporting.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space6,
      ),
      child: Row(
        children: [
          SizedBox(
            width: _allocationLineCellWidth,
            child: Text('明细', style: labelStyle),
          ),
          Expanded(
            child: Text('本', style: labelStyle, textAlign: TextAlign.right),
          ),
          Expanded(
            child: Text('息', style: labelStyle, textAlign: TextAlign.right),
          ),
          Expanded(
            child: Text('费', style: labelStyle, textAlign: TextAlign.right),
          ),
          Expanded(
            child: Text('优', style: labelStyle, textAlign: TextAlign.right),
          ),
          SizedBox(
            width: _allocationTotalCellWidth,
            child: Text('合计', style: labelStyle, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

const double _allocationLineCellWidth = 82;
const double _allocationTotalCellWidth = 54;

class _AllocationResultRow extends StatelessWidget {
  const _AllocationResultRow({
    required this.line,
    required this.breakdown,
    required this.onChanged,
  });

  final BillRepaymentAllocationLine line;
  final credit.RepaymentAmountBreakdown breakdown;
  final _ApplyAllocationAmount onChanged;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final cellStyle = styles.listSupporting.copyWith(color: colors.onSurface);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _allocationLineCellWidth,
            child: Text(
              _lineTitle(line),
              style: cellStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: _EditableAllocationMoneyCell(
              key: ValueKey('${line.billItemId}-principal'),
              value: breakdown.principal,
              style: cellStyle,
              onCommit:
                  (value) => onChanged(
                    billItemId: line.billItemId,
                    field: _AllocationAmountField.principal,
                    value: value,
                  ),
            ),
          ),
          Expanded(
            child: _EditableAllocationMoneyCell(
              key: ValueKey('${line.billItemId}-interest'),
              value: breakdown.interest,
              style: cellStyle,
              onCommit:
                  (value) => onChanged(
                    billItemId: line.billItemId,
                    field: _AllocationAmountField.interest,
                    value: value,
                  ),
            ),
          ),
          Expanded(
            child: _EditableAllocationMoneyCell(
              key: ValueKey('${line.billItemId}-fee'),
              value: breakdown.fee,
              style: cellStyle,
              onCommit:
                  (value) => onChanged(
                    billItemId: line.billItemId,
                    field: _AllocationAmountField.fee,
                    value: value,
                  ),
            ),
          ),
          Expanded(
            child: _EditableAllocationMoneyCell(
              key: ValueKey('${line.billItemId}-discount'),
              value: breakdown.discount,
              style: cellStyle,
              onCommit:
                  (value) => onChanged(
                    billItemId: line.billItemId,
                    field: _AllocationAmountField.discount,
                    value: value,
                  ),
            ),
          ),
          SizedBox(
            width: _allocationTotalCellWidth,
            child: _AllocationTextCell(
              text: _allocationCashTotal(breakdown).format(),
              style: cellStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationSummaryRow extends StatelessWidget {
  const _AllocationSummaryRow({
    required this.label,
    required this.breakdown,
    this.color,
    this.emphasize = false,
  });

  final String label;
  final credit.RepaymentAmountBreakdown breakdown;
  final Color? color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final cellStyle = (emphasize ? styles.formLabel : styles.listSupporting)
        .copyWith(color: color ?? colors.onSurface);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space2,
      ),
      child: Row(
        children: [
          SizedBox(
            width: _allocationLineCellWidth,
            child: Text(label, style: cellStyle),
          ),
          Expanded(
            child: _AllocationTextCell(
              text: breakdown.principal.format(),
              style: cellStyle,
            ),
          ),
          Expanded(
            child: _AllocationTextCell(
              text: breakdown.interest.format(),
              style: cellStyle,
            ),
          ),
          Expanded(
            child: _AllocationTextCell(
              text: breakdown.fee.format(),
              style: cellStyle,
            ),
          ),
          Expanded(
            child: _AllocationTextCell(
              text: breakdown.discount.format(),
              style: cellStyle,
            ),
          ),
          SizedBox(
            width: _allocationTotalCellWidth,
            child: _AllocationTextCell(
              text: _allocationCashTotal(breakdown).format(),
              style: cellStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableAllocationMoneyCell extends StatefulWidget {
  const _EditableAllocationMoneyCell({
    required this.value,
    required this.style,
    required this.onCommit,
    super.key,
  });

  final Money value;
  final TextStyle style;
  final ValueChanged<Money> onCommit;

  @override
  State<_EditableAllocationMoneyCell> createState() =>
      _EditableAllocationMoneyCellState();
}

class _EditableAllocationMoneyCellState
    extends State<_EditableAllocationMoneyCell> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _commit();
    }
  }

  void _startEdit() {
    if (_isEditing) return;
    final text =
        widget.value.minorUnits == 0 ? '' : widget.value.major.toString();
    _controller.text = text;
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _commit() {
    if (!_isEditing) return;
    final text = _controller.text.trim();
    Money? next;
    if (text.isEmpty) {
      next = Money.zero();
    } else {
      final parsed = Money.tryParse(text);
      if (parsed != null && parsed.minorUnits >= 0) {
        next = parsed;
      }
    }
    setState(() => _isEditing = false);
    if (next != null && next != widget.value) {
      widget.onCommit(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_isEditing) {
      return Container(
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
        child: AppPlainTextFormField(
          controller: _controller,
          focusNode: _focusNode,
          textAlign: TextAlign.right,
          style: widget.style,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          inputFormatters: [moneyInputFormatter],
          onFieldSubmitted: (_) => _commit(),
        ),
      );
    }
    return InkWell(
      onTap: _startEdit,
      child: _AllocationTextCell(
        text: widget.value.format(),
        style: widget.style,
      ),
    );
  }
}

class _AllocationTextCell extends StatelessWidget {
  const _AllocationTextCell({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: AppSpacing.space6,
      ),
      child: Text(
        text,
        style: style,
        textAlign: TextAlign.right,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

Account? _findAccount(List<Account> accounts, String? id) {
  if (id == null) return null;
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return null;
}

String _lineTitle(BillRepaymentAllocationLine line) {
  if (line.label.isNotEmpty) return line.label;
  return line.billItemId;
}

credit.RepaymentAmountBreakdown _allocationBreakdown(
  BillRepaymentManualAllocationText text,
) {
  return credit.RepaymentAmountBreakdown(
    principal: _moneyFromAllocationText(text.principalText),
    interest: _moneyFromAllocationText(text.interestText),
    fee: _moneyFromAllocationText(text.feeText),
    discount: _moneyFromAllocationText(text.discountText),
  );
}

Money _moneyFromAllocationText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return Money.zero();
  return Money.tryParse(trimmed) ?? Money.zero();
}

Money _allocationCashTotal(credit.RepaymentAmountBreakdown value) {
  return value.principal + value.interest + value.fee - value.discount;
}

bool _hasNonZeroAmount(credit.RepaymentAmountBreakdown value) {
  return value.principal.minorUnits != 0 ||
      value.interest.minorUnits != 0 ||
      value.fee.minorUnits != 0 ||
      value.discount.minorUnits != 0;
}

String _formatDateTime(DateTime date) {
  final time =
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} $time';
}
