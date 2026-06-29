import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/credit/credit_query_api.dart' show BillPeriod;
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/bill_repayment_allocation_view_model.dart';
import '../view_model/bill_repayment_form_view_model.dart';

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
        AsyncError(:final error) => Center(child: Text('加载失败：$error')),
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
    final summary = state.summary!;
    final paidFromAccount = _findAccount(
      state.repaymentAccounts,
      state.paidFromAccountId,
    );
    final warning = state.allocationReview?.warningMessage;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space28,
          AppSpacing.space18,
          AppSpacing.space28,
          AppSpacing.space24,
        ),
        children: [
          AppPlainFormSection(
            children: [
              AppPlainValueRow(
                label: '账单',
                value: _periodLabel(summary.period),
              ),
              AppPlainValueRow(
                label: '剩余本金',
                value: state.pendingBreakdown.principal.format(),
              ),
              MoneyPlainFormRow(
                label: '本金',
                controller: _principalController,
                hintText: '请输入还款本金',
                validator: validatePositiveMoneyText,
              ),
              MoneyPlainFormRow(
                label: '利息',
                controller: _interestController,
                hintText: '请输入利息（可选）',
                validator: validateOptionalNonNegativeMoneyText,
              ),
              MoneyPlainFormRow(
                label: '手续费',
                controller: _feeController,
                hintText: '请输入手续费（可选）',
                validator: validateOptionalNonNegativeMoneyText,
              ),
              MoneyPlainFormRow(
                label: '优惠',
                controller: _discountController,
                hintText: '请输入优惠（可选）',
                validator: validateOptionalNonNegativeMoneyText,
              ),
              AppPlainValueRow(
                label: '实付',
                value: _cashPaidText(state.cashPaid),
              ),
              DropdownPlainFormRow<BillRepaymentAllocationMode>(
                label: '分摊方式',
                value: state.allocationMode,
                items: billRepaymentAllocationModeItems,
                onChanged:
                    (value) =>
                        ref.read(provider.notifier).setAllocationMode(value),
              ),
              AppPlainSwitchRow(
                label: '生成流水',
                value: state.createTransaction,
                onChanged:
                    (value) =>
                        ref.read(provider.notifier).setCreateTransaction(value),
              ),
              if (state.createTransaction) ...[
                DateTimePlainFormRow(
                  label: '还款日期',
                  value: _formatDateTime(state.occurredAt),
                  onTap: () => _pickDate(provider, state.occurredAt),
                ),
                AccountPlainFormRow(
                  label: '还款账户',
                  account: paidFromAccount,
                  selectedId: state.paidFromAccountId,
                  placeholder: '请选择还款账户',
                  onTap:
                      state.repaymentAccounts.isEmpty
                          ? null
                          : () => _pickAccount(
                            accounts: state.repaymentAccounts,
                            selectedId: state.paidFromAccountId,
                            onSelected:
                                (id) => ref
                                    .read(provider.notifier)
                                    .setPaidFromAccountId(id),
                          ),
                  validator: (value) => value == null ? '请选择还款账户' : null,
                ),
              ],
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
          if (state.allocationMode == BillRepaymentAllocationMode.manual) ...[
            const SizedBox(height: AppSpacing.space16),
            _ManualAllocationSection(
              state: state,
              onChanged:
                  ({
                    required String billItemId,
                    String? principalText,
                    String? interestText,
                    String? feeText,
                    String? discountText,
                  }) => ref
                      .read(provider.notifier)
                      .setManualAllocationText(
                        billItemId: billItemId,
                        principalText: principalText,
                        interestText: interestText,
                        feeText: feeText,
                        discountText: discountText,
                      ),
            ),
          ],
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

class _ManualAllocationSection extends StatelessWidget {
  const _ManualAllocationSection({
    required this.state,
    required this.onChanged,
  });

  final BillRepaymentFormState state;
  final void Function({
    required String billItemId,
    String? principalText,
    String? interestText,
    String? feeText,
    String? discountText,
  })
  onChanged;

  @override
  Widget build(BuildContext context) {
    return AppPlainFormSection(
      children: [
        for (final line in state.lines) ...[
          AppPlainValueRow(label: '明细', value: _lineTitle(line)),
          _ManualMoneyRow(
            fieldKey: '${line.billItemId}-principal',
            label: '本金',
            initialValue:
                state.manualAllocationText(line.billItemId).principalText,
            onChanged:
                (value) => onChanged(
                  billItemId: line.billItemId,
                  principalText: value,
                ),
          ),
          _ManualMoneyRow(
            fieldKey: '${line.billItemId}-interest',
            label: '利息',
            initialValue:
                state.manualAllocationText(line.billItemId).interestText,
            onChanged:
                (value) =>
                    onChanged(billItemId: line.billItemId, interestText: value),
          ),
          _ManualMoneyRow(
            fieldKey: '${line.billItemId}-fee',
            label: '手续费',
            initialValue: state.manualAllocationText(line.billItemId).feeText,
            onChanged:
                (value) =>
                    onChanged(billItemId: line.billItemId, feeText: value),
          ),
          _ManualMoneyRow(
            fieldKey: '${line.billItemId}-discount',
            label: '优惠',
            initialValue:
                state.manualAllocationText(line.billItemId).discountText,
            onChanged:
                (value) =>
                    onChanged(billItemId: line.billItemId, discountText: value),
          ),
        ],
      ],
    );
  }
}

class _ManualMoneyRow extends StatelessWidget {
  const _ManualMoneyRow({
    required this.fieldKey,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  final String fieldKey;
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppPlainFormRow(
      label: label,
      child: TextFormField(
        key: ValueKey(fieldKey),
        initialValue: initialValue,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [moneyInputFormatter],
        decoration: const InputDecoration(
          hintText: '0.00',
          isDense: true,
          border: InputBorder.none,
        ),
        validator: validateOptionalNonNegativeMoneyText,
        onChanged: onChanged,
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

String _periodLabel(BillPeriod period) {
  return '${period.year}年${period.month.toString().padLeft(2, '0')}月账单';
}

String _cashPaidText(Money? value) {
  return value == null ? '-' : value.format();
}

String _lineTitle(BillRepaymentAllocationLine line) {
  if (line.label.isNotEmpty) return line.label;
  return line.billItemId;
}

String _formatDateTime(DateTime date) {
  final time =
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} $time';
}
