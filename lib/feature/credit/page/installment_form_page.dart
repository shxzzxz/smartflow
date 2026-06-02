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

  DateTime _borrowingDate = DateTime.now();
  DateTime _firstRepaymentDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    DateTime.now().day,
  );
  // 用户是否手工调整过首期还款日；未调整时跟随借款日期联动。
  bool _firstDateTouched = false;
  InstallmentRepaymentMethod _method =
      InstallmentRepaymentMethod.equalInstallment;
  InterestRatePeriod _ratePeriod = InterestRatePeriod.monthly;
  InterestAccrualMethod _accrualMethod = InterestAccrualMethod.daily;
  InstallmentSourceType? _sourceType;
  String? _disbursementAccountId;
  bool _submitting = false;

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
    final liabilityAccountsAsync = ref.watch(
      accountsForUsageProvider(AccountUsage.repaymentTarget),
    );
    final fundAccountsAsync = ref.watch(
      accountsForUsageProvider(AccountUsage.fund),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('新建分期')),
      body: switch ((liabilityAccountsAsync, fundAccountsAsync)) {
        (
          AsyncData(value: final liabilityAccounts),
          AsyncData(value: final fundAccounts),
        ) =>
          _buildForm(context, liabilityAccounts, fundAccounts),
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => Center(child: Text('加载失败：$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<Account> liabilityAccounts,
    List<Account> fundAccounts,
  ) {
    final liability = _findAccount(
      liabilityAccounts,
      widget.liabilityAccountId,
    );
    if (liability == null) {
      return const Center(child: Text('负债账户不存在'));
    }

    _sourceType ??= widget.lockedSourceType ?? _defaultSourceType(liability);
    final isDisbursement = _sourceType == InstallmentSourceType.disbursement;

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
                child: AccountPlainValue(account: liability, placeholder: ''),
              ),
              if (widget.lockedSourceType == null)
                _SourceTypeRow(
                  value: _sourceType!,
                  onChanged: (value) => setState(() => _sourceType = value),
                ),
              if (isDisbursement)
                AccountPlainFormRow(
                  label: '到账账户',
                  account: _findAccount(fundAccounts, _disbursementAccountId),
                  selectedId: _disbursementAccountId,
                  placeholder: '请选择放款入账账户',
                  onTap:
                      fundAccounts.isEmpty
                          ? null
                          : () => _pickAccount(
                            title: '选择到账账户',
                            accounts: fundAccounts,
                            selectedId: _disbursementAccountId,
                            onSelected:
                                (id) =>
                                    setState(() => _disbursementAccountId = id),
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
                value: _formatDate(_borrowingDate),
                onTap: _pickBorrowingDate,
              ),
              DateTimePlainFormRow(
                label: '首期还款日',
                value: _formatDate(_firstRepaymentDate),
                onTap: _pickFirstRepaymentDate,
              ),
              DropdownPlainFormRow<InstallmentRepaymentMethod>(
                label: '分期方式',
                value: _method,
                items: installmentRepaymentMethodItems,
                onChanged: (value) => setState(() => _method = value),
              ),
              if (_method != InstallmentRepaymentMethod.flatFee &&
                  _method != InstallmentRepaymentMethod.custom)
                DropdownPlainFormRow<InterestAccrualMethod>(
                  label: '计息方式',
                  value: _accrualMethod,
                  items: interestAccrualMethodItems,
                  onChanged: (value) => setState(() => _accrualMethod = value),
                ),
              if (_method != InstallmentRepaymentMethod.flatFee &&
                  _method != InstallmentRepaymentMethod.custom)
                ValueWithUnitPlainFormRow<InterestRatePeriod>(
                  label: '利率(%)',
                  controller: _rateController,
                  hintText: '例：7.2',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  unit: _ratePeriod,
                  unitItems: interestRatePeriodItems,
                  onUnitChanged:
                      (period) => setState(() => _ratePeriod = period),
                ),
              if (_method == InstallmentRepaymentMethod.equalInstallment)
                MoneyPlainFormRow(
                  label: '还款固定额',
                  controller: _overrideInstallmentController,
                  hintText: '前 n-1 期固定额（可选）',
                  validator: _validateOptionalMoney,
                ),
              if (_method == InstallmentRepaymentMethod.flatFee)
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
            loading: _submitting,
            onPressed: () => _submit(liability),
          ),
        ],
      ),
    );
  }

  InstallmentSourceType _defaultSourceType(Account liability) {
    return liability.subtype == AccountSubtype.loan
        ? InstallmentSourceType.disbursement
        : InstallmentSourceType.billConversion;
  }

  Future<void> _pickBorrowingDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _borrowingDate,
      title: '选择借款日期',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _borrowingDate = picked;
      if (!_firstDateTouched) {
        _firstRepaymentDate = _addMonths(picked, 1);
      }
    });
  }

  Future<void> _pickFirstRepaymentDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _firstRepaymentDate,
      title: '选择首期还款日',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _firstRepaymentDate = picked;
      _firstDateTouched = true;
    });
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

  Future<void> _submit(Account liability) async {
    if (!_formKey.currentState!.validate()) return;
    final principal = Money.parse(_principalController.text);
    final totalPeriods = int.parse(_totalPeriodsController.text.trim());
    final note = _blankToNull(_noteController.text);
    final isDisbursement = _sourceType == InstallmentSourceType.disbursement;
    if (isDisbursement && _disbursementAccountId == null) {
      _showError('请选择放款入账账户');
      return;
    }

    final ratePpm = _parseRatePpm(_rateController.text);
    final totalFeeMinor =
        _parseOptionalMoney(_totalFeeController.text).minorUnits;
    final overrideMinor =
        _method == InstallmentRepaymentMethod.equalInstallment
            ? _parseOptionalOverride(_overrideInstallmentController.text)
            : null;

    setState(() => _submitting = true);
    final service = ref.read(installmentServiceProvider);
    Result<CreateContractResult> result;
    if (isDisbursement) {
      result = await service.createDisbursementContract(
        CreateDisbursementContractCommand(
          liabilityAccountId: liability.id,
          disbursementAccountId: _disbursementAccountId!,
          principal: principal,
          totalPeriods: totalPeriods,
          borrowingDate: _borrowingDate,
          firstRepaymentDate: _firstRepaymentDate,
          repaymentMethod: _method,
          interestRatePeriod: ratePpm == null ? null : _ratePeriod,
          interestRatePpm: ratePpm,
          interestAccrualMethod: _accrualMethod,
          totalFeeMinor: totalFeeMinor,
          equalInstallmentOverrideMinor: overrideMinor,
          note: note,
        ),
      );
    } else {
      result = await service.createBillConversionContract(
        CreateBillConversionContractCommand(
          liabilityAccountId: liability.id,
          principal: principal,
          totalPeriods: totalPeriods,
          borrowingDate: _borrowingDate,
          firstRepaymentDate: _firstRepaymentDate,
          repaymentMethod: _method,
          interestRatePeriod: ratePpm == null ? null : _ratePeriod,
          interestRatePpm: ratePpm,
          interestAccrualMethod: _accrualMethod,
          totalFeeMinor: totalFeeMinor,
          equalInstallmentOverrideMinor: overrideMinor,
          note: note,
        ),
      );
    }
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case Success(:final value):
        ref.invalidate(installmentContractsByAccountProvider(liability.id));
        context.pushReplacement('/installments/${value.contractId}');
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

  String? _validatePositiveInt(String? value) {
    final n = int.tryParse((value ?? '').trim());
    if (n == null || n <= 0) return '期数必须为正整数';
    return null;
  }

  Money _parseOptionalMoney(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? Money.zero() : Money.parse(trimmed);
  }

  /// 解析"还款固定额"输入；空或非正返回 null（回落公式推导）。
  int? _parseOptionalOverride(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    try {
      final money = Money.parse(trimmed);
      return money.minorUnits > 0 ? money.minorUnits : null;
    } on FormatException {
      return null;
    }
  }

  /// 将输入字符串（百分比形式，如 "0.025" 表示 0.025%）转换为 ppm
  int? _parseRatePpm(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final percent = double.tryParse(trimmed);
    if (percent == null || percent <= 0) return null;
    return (percent * 10000).round();
  }
}

DateTime _addMonths(DateTime date, int months) {
  return DateTime(date.year, date.month + months, date.day);
}

class _SourceTypeRow extends StatelessWidget {
  const _SourceTypeRow({required this.value, required this.onChanged});

  final InstallmentSourceType value;
  final ValueChanged<InstallmentSourceType> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppPlainFormRow(
      label: '类型',
      child: Wrap(
        spacing: AppSpacing.space8,
        children: [
          ChoiceChip(
            label: const Text('放款分期'),
            selected: value == InstallmentSourceType.disbursement,
            onSelected: (selected) {
              if (selected) onChanged(InstallmentSourceType.disbursement);
            },
          ),
          ChoiceChip(
            label: const Text('账单分期'),
            selected: value == InstallmentSourceType.billConversion,
            onSelected: (selected) {
              if (selected) onChanged(InstallmentSourceType.billConversion);
            },
          ),
        ],
      ),
    );
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
  for (final a in accounts) {
    if (a.id == id) return a;
  }
  return null;
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
