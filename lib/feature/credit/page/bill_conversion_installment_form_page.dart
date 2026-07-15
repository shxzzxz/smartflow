import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/bill_conversion_installment_form_view_model.dart';
import '../view_model/bill_repayment_allocation_view_model.dart';
import '../widget/installment_field_options.dart';

class BillConversionInstallmentFormPage extends ConsumerStatefulWidget {
  const BillConversionInstallmentFormPage({required this.billId, super.key});

  final String billId;

  @override
  ConsumerState<BillConversionInstallmentFormPage> createState() =>
      _BillConversionInstallmentFormPageState();
}

class _BillConversionInstallmentFormPageState
    extends ConsumerState<BillConversionInstallmentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _principalController = TextEditingController();
  final _totalPeriodsController = TextEditingController();
  final _rateController = TextEditingController();
  final _totalFeeController = TextEditingController();
  final _overrideInstallmentController = TextEditingController();
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
    _totalPeriodsController.addListener(
      () => _setText(
        (vm, value) => vm.setTotalPeriodsText(value),
        _totalPeriodsController.text,
      ),
    );
    _rateController.addListener(
      () =>
          _setText((vm, value) => vm.setRateText(value), _rateController.text),
    );
    _totalFeeController.addListener(
      () => _setText(
        (vm, value) => vm.setTotalFeeText(value),
        _totalFeeController.text,
      ),
    );
    _overrideInstallmentController.addListener(
      () => _setText(
        (vm, value) => vm.setOverrideInstallmentText(value),
        _overrideInstallmentController.text,
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
    _totalPeriodsController.dispose();
    _rateController.dispose();
    _totalFeeController.dispose();
    _overrideInstallmentController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = billConversionInstallmentFormViewModelProvider(
      widget.billId,
    );
    final asyncState = ref.watch(provider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('账单分期')),
      body: switch (asyncState) {
        AsyncData(value: final state) => _buildState(provider, state),
        AsyncError() => const Center(child: Text('加载失败，请稍后重试')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildState(
    BillConversionInstallmentFormViewModelProvider provider,
    BillConversionInstallmentFormState state,
  ) {
    return switch (state) {
      BillConversionInstallmentLoaded() => _buildForm(provider, state),
      BillConversionInstallmentNotFound() => const Center(child: Text('账单不存在')),
      BillConversionInstallmentNotEligible() => const Center(
        child: Text('只有已出账账单可以发起账单分期'),
      ),
      BillConversionInstallmentNoPending() => const Center(
        child: Text('账单没有可分期消费明细'),
      ),
    };
  }

  Widget _buildForm(
    BillConversionInstallmentFormViewModelProvider provider,
    BillConversionInstallmentLoaded state,
  ) {
    _syncControllers(state);
    final notifier = ref.read(provider.notifier);
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
                value: _periodLabel(state.summary.period),
              ),
              AppPlainValueRow(
                label: '可分期本金',
                value: state.convertiblePrincipal.format(),
              ),
              MoneyPlainFormRow(
                label: '本金',
                controller: _principalController,
                hintText: '请输入分期本金',
                validator: validatePositiveMoneyText,
              ),
              DropdownPlainFormRow<BillRepaymentAllocationMode>(
                label: '分摊方式',
                value: state.allocationMode,
                items: billRepaymentAllocationModeItems,
                onChanged: notifier.setAllocationMode,
              ),
              _IntegerPlainFormRow(
                label: '期数',
                controller: _totalPeriodsController,
                hintText: '总期数',
                validator: _validatePositiveInt,
              ),
              DateTimePlainFormRow(
                label: '借款日期',
                value: _formatDate(state.borrowingDate),
                onTap: () => _pickBorrowingDate(provider, state.borrowingDate),
              ),
              DateTimePlainFormRow(
                label: '首期还款日',
                value: _formatDate(state.firstRepaymentDate),
                onTap:
                    () => _pickFirstRepaymentDate(
                      provider,
                      state.firstRepaymentDate,
                    ),
              ),
              DropdownPlainFormRow<InstallmentRepaymentMethod>(
                label: '分期方式',
                value: state.method,
                items: installmentRepaymentMethodItems,
                onChanged: notifier.setMethod,
              ),
              if (state.method != InstallmentRepaymentMethod.flatFee &&
                  state.method != InstallmentRepaymentMethod.custom)
                DropdownPlainFormRow<InterestAccrualMethod>(
                  label: '计息方式',
                  value: state.accrualMethod,
                  items: interestAccrualMethodItems,
                  onChanged: notifier.setAccrualMethod,
                ),
              if (state.method != InstallmentRepaymentMethod.flatFee &&
                  state.method != InstallmentRepaymentMethod.custom)
                ValueWithUnitPlainFormRow<InterestRatePeriod>(
                  label: '利率(%)',
                  controller: _rateController,
                  hintText: '例：7.2',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  unit: state.ratePeriod,
                  unitItems: interestRatePeriodItems,
                  onUnitChanged: notifier.setRatePeriod,
                ),
              if (state.method == InstallmentRepaymentMethod.equalInstallment)
                MoneyPlainFormRow(
                  label: '还款固定额',
                  controller: _overrideInstallmentController,
                  hintText: '前 n-1 期固定额（可选）',
                  validator: _validateOptionalMoney,
                ),
              if (state.method == InstallmentRepaymentMethod.flatFee)
                MoneyPlainFormRow(
                  label: '总手续费',
                  controller: _totalFeeController,
                  hintText: '所有期次手续费合计（可选）',
                  validator: _validateOptionalMoney,
                ),
              NotePlainFormRow(controller: _noteController),
            ],
          ),
          const SizedBox(height: AppSpacing.space24),
          AppSubmitButton(
            label: '创建分期',
            loading: state.submitting,
            onPressed: () => _submit(provider),
          ),
        ],
      ),
    );
  }

  Future<void> _pickBorrowingDate(
    BillConversionInstallmentFormViewModelProvider provider,
    DateTime initialDate,
  ) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initialDate,
      title: '选择借款日期',
    );
    if (picked == null || !mounted) return;
    ref.read(provider.notifier).setBorrowingDate(picked);
  }

  Future<void> _pickFirstRepaymentDate(
    BillConversionInstallmentFormViewModelProvider provider,
    DateTime initialDate,
  ) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initialDate,
      title: '选择首期还款日',
    );
    if (picked == null || !mounted) return;
    ref.read(provider.notifier).setFirstRepaymentDate(picked);
  }

  Future<void> _submit(
    BillConversionInstallmentFormViewModelProvider provider,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    final outcome = await ref.read(provider.notifier).submit();
    if (!mounted) return;
    switch (outcome) {
      case UiActionSuccess<String>(:final value):
        context.pushReplacement('/installments/$value');
      case UiActionFailure<String>(:final error):
        _showError(error.message);
    }
  }

  void _syncControllers(BillConversionInstallmentLoaded state) {
    _syncing = true;
    syncTextControllerText(_principalController, state.principalText);
    syncTextControllerText(_totalPeriodsController, state.totalPeriodsText);
    syncTextControllerText(_rateController, state.rateText);
    syncTextControllerText(_totalFeeController, state.totalFeeText);
    syncTextControllerText(
      _overrideInstallmentController,
      state.overrideInstallmentText,
    );
    syncTextControllerText(_noteController, state.noteText);
    _syncing = false;
  }

  void _setText(
    void Function(BillConversionInstallmentFormViewModel, String) setter,
    String value,
  ) {
    if (_syncing) return;
    setter(
      ref.read(
        billConversionInstallmentFormViewModelProvider(widget.billId).notifier,
      ),
      value,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String? _validateOptionalMoney(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    try {
      final money = Money.parse(trimmed);
      return money.minorUnits >= 0 ? null : '金额不能小于 0';
    } on FormatException {
      return '请输入有效金额';
    }
  }

  String? _validatePositiveInt(String? value) {
    final n = int.tryParse((value ?? '').trim());
    if (n == null || n <= 0) return '期数必须为正整数';
    return null;
  }
}

class _IntegerPlainFormRow extends StatelessWidget {
  const _IntegerPlainFormRow({
    required this.label,
    required this.controller,
    required this.hintText,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return AppPlainFormRow(
      label: label,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: hintText,
          isDense: true,
          border: InputBorder.none,
        ),
        validator: validator,
      ),
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
];

String _periodLabel(BillPeriod period) {
  return '${period.year}年${period.month.toString().padLeft(2, '0')}月账单';
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
