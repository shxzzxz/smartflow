import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/installment_form_view_model.dart';
import '../widget/installment_field_options.dart';

class InstallmentFormPage extends ConsumerStatefulWidget {
  const InstallmentFormPage({
    required this.liabilityAccountId,
    this.lockedSourceType,
    super.key,
  });

  final String liabilityAccountId;
  final InstallmentSourceType? lockedSourceType;

  @override
  ConsumerState<InstallmentFormPage> createState() =>
      _InstallmentFormPageState();
}

class _InstallmentFormPageState extends ConsumerState<InstallmentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _principalController = TextEditingController();
  final _totalPeriodsController = TextEditingController();
  final _rateController = TextEditingController();
  final _totalFeeController = TextEditingController();
  final _overrideInstallmentController = TextEditingController();
  final _noteController = TextEditingController();

  InstallmentFormArgs get _args {
    return InstallmentFormArgs(
      liabilityAccountId: widget.liabilityAccountId,
      lockedSourceType: widget.lockedSourceType,
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
    final asyncState = ref.watch(installmentFormViewModelProvider(_args));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('新建分期')),
      body: switch (asyncState) {
        AsyncData(value: final InstallmentFormLoaded state) => _buildForm(
          context,
          state,
        ),
        AsyncData(value: InstallmentFormNotFound()) => const Center(
          child: Text('负债账户不存在'),
        ),
        AsyncError(:final error) => Center(child: Text('加载失败：$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildForm(BuildContext context, InstallmentFormLoaded state) {
    final isDisbursement = state.isDisbursement;
    final notifier = ref.read(installmentFormViewModelProvider(_args).notifier);

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
              AppPlainFormRow(
                label: '负债账户',
                child: AccountPlainValue(
                  account: state.liability,
                  placeholder: '',
                ),
              ),
              if (isDisbursement)
                AccountPlainFormRow(
                  label: '到账账户',
                  account: _findAccount(
                    state.fundAccounts,
                    state.disbursementAccountId,
                  ),
                  selectedId: state.disbursementAccountId,
                  placeholder: '请选择放款入账账户',
                  onTap:
                      state.fundAccounts.isEmpty
                          ? null
                          : () => _pickAccount(
                            title: '选择到账账户',
                            accounts: state.fundAccounts,
                            selectedId: state.disbursementAccountId,
                            onSelected: notifier.setDisbursementAccountId,
                          ),
                ),
              MoneyPlainFormRow(
                label: '本金',
                controller: _principalController,
                hintText: '请输入分期本金',
                validator: _validatePositiveMoney,
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
                onTap: () => _pickBorrowingDate(state.borrowingDate),
              ),
              DateTimePlainFormRow(
                label: '首期还款日',
                value: _formatDate(state.firstRepaymentDate),
                onTap: () => _pickFirstRepaymentDate(state.firstRepaymentDate),
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
            onPressed: () => _submit(),
          ),
        ],
      ),
    );
  }

  Future<void> _pickBorrowingDate(DateTime initialDate) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initialDate,
      title: '选择借款日期',
    );
    if (picked == null || !mounted) return;
    ref
        .read(installmentFormViewModelProvider(_args).notifier)
        .setBorrowingDate(picked);
  }

  Future<void> _pickFirstRepaymentDate(DateTime initialDate) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initialDate,
      title: '选择首期还款日',
    );
    if (picked == null || !mounted) return;
    ref
        .read(installmentFormViewModelProvider(_args).notifier)
        .setFirstRepaymentDate(picked);
  }

  Future<void> _pickAccount({
    required String title,
    required List<Account> accounts,
    required String? selectedId,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showAccountPickerSheet(
      context: context,
      title: title,
      accounts: accounts,
      selectedId: selectedId,
    );
    if (!mounted || selected == null) return;
    onSelected(selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final outcome = await ref
        .read(installmentFormViewModelProvider(_args).notifier)
        .submit(
          principalText: _principalController.text,
          totalPeriodsText: _totalPeriodsController.text,
          rateText: _rateController.text,
          totalFeeText: _totalFeeController.text,
          overrideInstallmentText: _overrideInstallmentController.text,
          noteText: _noteController.text,
        );
    if (!mounted) return;
    switch (outcome) {
      case UiActionSuccess<String>(:final value):
        context.pushReplacement('/installments/$value');
      case UiActionFailure<String>(:final error):
        _showError(error.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String? _validatePositiveMoney(String? value) {
    try {
      final money = Money.parse(value ?? '');
      return money.minorUnits > 0 ? null : '金额必须大于 0';
    } on FormatException {
      return '请输入有效金额';
    }
  }

  String? _validateOptionalMoney(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    try {
      Money.parse(trimmed);
      return null;
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

Account? _findAccount(List<Account> accounts, String? id) {
  if (id == null) return null;
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return null;
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
