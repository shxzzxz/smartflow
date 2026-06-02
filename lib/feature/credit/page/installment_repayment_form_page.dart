import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/provider.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import '../../../widget/business/plain_transaction_fields.dart';

enum InstallmentRepaymentMode { scheduled, extraPrincipal, earlySettlement }

class InstallmentRepaymentFormPage extends ConsumerStatefulWidget {
  const InstallmentRepaymentFormPage({
    required this.contractId,
    required this.mode,
    this.scheduleId,
    super.key,
  });

  final String contractId;
  final InstallmentRepaymentMode mode;
  final String? scheduleId;

  @override
  ConsumerState<InstallmentRepaymentFormPage> createState() =>
      _InstallmentRepaymentFormPageState();
}

class _InstallmentRepaymentFormPageState
    extends ConsumerState<InstallmentRepaymentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _principalController = TextEditingController();
  final _interestController = TextEditingController();
  final _feeController = TextEditingController();
  final _discountController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _occurredAt = DateTime.now();
  String? _paidFromAccountId;
  bool _submitting = false;
  bool _initialized = false;

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
    final contractAsync = ref.watch(
      installmentContractProvider(widget.contractId),
    );
    final schedulesAsync = ref.watch(
      installmentSchedulesProvider(widget.contractId),
    );
    final fundAccountsAsync = ref.watch(
      accountsForUsageProvider(AccountUsage.repaymentSource),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(_titleForMode(widget.mode))),
      body: switch ((contractAsync, schedulesAsync, fundAccountsAsync)) {
        (
          AsyncData(value: final contract),
          AsyncData(value: final schedules),
          AsyncData(value: final accounts),
        ) =>
          contract == null
              ? const Center(child: Text('合同不存在'))
              : _buildForm(context, contract, schedules, accounts),
        (AsyncError(:final error), _, _) ||
        (_, AsyncError(:final error), _) ||
        (_, _, AsyncError(:final error)) => Center(child: Text('加载失败：$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildForm(
    BuildContext context,
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
    List<Account> fundAccounts,
  ) {
    final schedule =
        widget.mode == InstallmentRepaymentMode.scheduled
            ? _findSchedule(schedules, widget.scheduleId)
            : null;

    if (!_initialized) {
      _initialized = true;
      if (schedule != null) {
        _principalController.text = schedule.expectedPrincipal.major.toString();
        if (schedule.expectedInterest.minorUnits > 0) {
          _interestController.text = schedule.expectedInterest.major.toString();
        }
        if (schedule.expectedFee.minorUnits > 0) {
          _feeController.text = schedule.expectedFee.major.toString();
        }
      }
      if (widget.mode == InstallmentRepaymentMode.earlySettlement) {
        final paidPrincipalSum = schedules
            .where((s) => s.status.name == 'paid')
            .fold<int>(0, (acc, s) => acc + s.expectedPrincipal.minorUnits);
        final remaining = contract.principal.minorUnits - paidPrincipalSum;
        _principalController.text =
            Money(minorUnits: remaining < 0 ? 0 : remaining).major.toString();
      }
      final disbursementId = contract.disbursementAccountId;
      if (disbursementId != null &&
          fundAccounts.any((a) => a.id == disbursementId)) {
        _paidFromAccountId = disbursementId;
      }
    }

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
              MoneyPlainFormRow(
                label: '本金',
                controller: _principalController,
                hintText: '请输入还款本金',
                validator: _validatePositiveMoney,
              ),
              if (widget.mode != InstallmentRepaymentMode.extraPrincipal)
                MoneyPlainFormRow(
                  label: '利息',
                  controller: _interestController,
                  hintText: '请输入利息（可选）',
                  validator: _validateOptionalMoney,
                ),
              MoneyPlainFormRow(
                label: '手续费',
                controller: _feeController,
                hintText: '请输入手续费（可选）',
                validator: _validateOptionalMoney,
              ),
              if (widget.mode == InstallmentRepaymentMode.scheduled)
                MoneyPlainFormRow(
                  label: '优惠',
                  controller: _discountController,
                  hintText: '请输入优惠（可选）',
                  validator: _validateOptionalMoney,
                ),
              DateTimePlainFormRow(
                label: '还款日期',
                value: _formatDateTime(_occurredAt),
                onTap: _pickDate,
              ),
              AccountPlainFormRow(
                label: '还款账户',
                account: _findAccount(fundAccounts, _paidFromAccountId),
                selectedId: _paidFromAccountId,
                placeholder: '请选择还款账户',
                onTap:
                    fundAccounts.isEmpty
                        ? null
                        : () => _pickAccount(
                          accounts: fundAccounts,
                          onSelected:
                              (id) => setState(() => _paidFromAccountId = id),
                        ),
              ),
              NotePlainFormRow(controller: _noteController),
            ],
          ),
          const SizedBox(height: AppSpacing.space24),
          if (widget.mode == InstallmentRepaymentMode.extraPrincipal)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.space12),
              child: Text(
                '提交后，所有待还期次的金额将按剩余本金重新计算。',
                style: TextStyle(fontSize: 12),
              ),
            ),
          AppSubmitButton(
            label: _submitLabel(widget.mode),
            loading: _submitting,
            onPressed: () => _submit(contract, schedule),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: _occurredAt,
      title: '选择还款日期',
    );
    if (picked == null || !mounted) return;
    setState(() => _occurredAt = picked);
  }

  Future<void> _pickAccount({
    required List<Account> accounts,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showAccountPickerSheet(
      context: context,
      title: '选择还款账户',
      accounts: accounts,
      selectedId: _paidFromAccountId,
    );
    if (!mounted || selected == null) return;
    onSelected(selected);
  }

  Future<void> _submit(
    InstallmentContract contract,
    InstallmentSchedule? schedule,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidFromAccountId == null) {
      _showError('请选择还款账户');
      return;
    }
    final principal = Money.parse(_principalController.text);
    final interest = _parseOptional(_interestController.text);
    final fee = _parseOptional(_feeController.text);
    final discount = _parseOptional(_discountController.text);
    final note = _blankToNull(_noteController.text);

    setState(() => _submitting = true);
    final service = ref.read(installmentServiceProvider);
    Result<dynamic> result;
    switch (widget.mode) {
      case InstallmentRepaymentMode.scheduled:
        if (schedule == null) {
          setState(() => _submitting = false);
          _showError('计划行不存在');
          return;
        }
        result = await service.createScheduledRepayment(
          CreateScheduledRepaymentCommand(
            contractId: contract.id,
            scheduleId: schedule.id,
            principal: principal,
            interest:
                interest != null && interest.minorUnits > 0 ? interest : null,
            fee: fee != null && fee.minorUnits > 0 ? fee : null,
            discount:
                discount != null && discount.minorUnits > 0 ? discount : null,
            paidFromAccountId: _paidFromAccountId!,
            occurredAt: _occurredAt,
            note: note,
          ),
        );
      case InstallmentRepaymentMode.extraPrincipal:
        result = await service.createPrincipalPrepayment(
          CreatePrincipalPrepaymentCommand(
            contractId: contract.id,
            principal: principal,
            fee: fee != null && fee.minorUnits > 0 ? fee : null,
            paidFromAccountId: _paidFromAccountId!,
            occurredAt: _occurredAt,
            note: note,
          ),
        );
      case InstallmentRepaymentMode.earlySettlement:
        result = await service.createEarlySettlement(
          CreateEarlySettlementCommand(
            contractId: contract.id,
            principal: principal,
            interest:
                interest != null && interest.minorUnits > 0 ? interest : null,
            fee: fee != null && fee.minorUnits > 0 ? fee : null,
            paidFromAccountId: _paidFromAccountId!,
            occurredAt: _occurredAt,
            note: note,
          ),
        );
    }
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case Success():
        ref.invalidate(installmentContractProvider(contract.id));
        ref.invalidate(installmentSchedulesProvider(contract.id));
        ref.invalidate(installmentRepaymentsProvider(contract.id));
        ref.invalidate(
          installmentContractsByAccountProvider(contract.liabilityAccountId),
        );
        context.pop();
      case FailureResult(:final failure):
        _showError(failure.message);
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

  Money? _parseOptional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : Money.parse(trimmed);
  }
}

String _titleForMode(InstallmentRepaymentMode mode) {
  return switch (mode) {
    InstallmentRepaymentMode.scheduled => '期次还款',
    InstallmentRepaymentMode.extraPrincipal => '提前还本',
    InstallmentRepaymentMode.earlySettlement => '提前结清',
  };
}

String _submitLabel(InstallmentRepaymentMode mode) {
  return switch (mode) {
    InstallmentRepaymentMode.scheduled => '保存',
    InstallmentRepaymentMode.extraPrincipal => '提交并重算',
    InstallmentRepaymentMode.earlySettlement => '结清',
  };
}

InstallmentSchedule? _findSchedule(
  List<InstallmentSchedule> schedules,
  String? id,
) {
  if (id == null) return null;
  for (final s in schedules) {
    if (s.id == id) return s;
  }
  return null;
}

Account? _findAccount(List<Account> accounts, String? id) {
  if (id == null) return null;
  for (final a in accounts) {
    if (a.id == id) return a;
  }
  return null;
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _formatDateTime(DateTime date) {
  final time =
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} $time';
}
