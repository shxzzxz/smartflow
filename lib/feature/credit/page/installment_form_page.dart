import '../../../application/credit/credit_query_api.dart';
import '../view_model/installment_product_view_model.dart';
import '../widget/installment_terms_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/installment_form_view_model.dart';
import '../widget/installment_field_options.dart';

const _installmentSectionPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.space16,
  vertical: AppSpacing.space8,
);

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
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '新建分期'),
            Expanded(
              child: switch (asyncState) {
                AsyncData(value: final InstallmentFormLoaded state) =>
                  _buildForm(context, state),
                AsyncData(value: InstallmentFormNotFound()) => const Center(
                  child: Text('负债账户不存在'),
                ),
                AsyncError() => const Center(child: Text('加载失败，请稍后重试')),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, InstallmentFormLoaded state) {
    final isDisbursement = state.isDisbursement;
    final notifier = ref.read(installmentFormViewModelProvider(_args).notifier);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space12,
          AppSpacing.space16,
          AppSpacing.space24,
        ),
        children: [
          AppFormSection(
            padding: _installmentSectionPadding,
            children: [
              AccountPlainFormRow(
                label: '负债账户',
                account: state.liability,
                selectedId: state.liability.id,
                placeholder: '',
              ),
              MoneyPlainFormRow(
                label: '本金',
                controller: _principalController,
                hintText: '请输入分期本金',
                validator: validatePositiveMoneyText,
              ),
              DateTimePlainFormRow(
                label: '借款日期',
                dateTime: state.borrowingDate,
                value: formatDateLabel(state.borrowingDate),
                onTap: (onSelected) =>
                    _pickBorrowingDate(state.borrowingDate, onSelected),
                onChanged: (value) {
                  if (value != null) notifier.setBorrowingDate(value);
                },
              ),
              if (isDisbursement)
                AppPlainSwitchRow(
                  label: '创建放款交易',
                  description: '迁移已有贷款时可关闭，仅创建合同和还款计划',
                  value: state.createDisbursementTransaction,
                  onChanged: notifier.setCreateDisbursementTransaction,
                ),
              if (isDisbursement && state.createDisbursementTransaction)
                AccountPlainFormRow(
                  label: '到账账户',
                  account: _findAccount(
                    state.fundAccounts,
                    state.disbursementAccountId,
                  ),
                  selectedId: state.disbursementAccountId,
                  placeholder: '请选择放款入账账户',
                  onTap: state.fundAccounts.isEmpty
                      ? null
                      : (onSelected) => _pickAccount(
                          title: '选择到账账户',
                          accounts: state.fundAccounts,
                          selectedId: state.disbursementAccountId,
                          onSelected: onSelected,
                        ),
                  onChanged: notifier.setDisbursementAccountId,
                ),
            ],
          ),
          if (state.liability.profileKey == 'credit.loan') ...[
            const SizedBox(height: AppSpacing.space12),
            AppFormSection(
              children: [
                AppPlainFormRow(
                  label: '分期产品',
                  child: TextButton(
                    onPressed: () => _pickProduct(notifier),
                    child: Text(state.productName ?? '选择产品'),
                  ),
                ),
                if (state.termsDraft == null)
                  TextButton(
                    onPressed: notifier.startStageConfiguration,
                    child: const Text('自定义阶段配置'),
                  ),
              ],
            ),
          ],
          if (state.termsDraft != null) ...[
            AppPlainSwitchRow(
              label: '自定义本笔贷款',
              description: '开启后可修改阶段结构和计算规则；关闭保留修改',
              value: state.customRules,
              onChanged: notifier.setCustomRules,
            ),
            InstallmentTermsEditor(
              value: state.termsDraft!,
              onChanged: notifier.setTermsDraft,
              rulesEditable: state.customRules,
            ),
            TextButton(
              onPressed: () => _preview(notifier),
              child: const Text('预览还款计划'),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.space12),
            AppFormSection(
              padding: _installmentSectionPadding,
              children: [
                AppPlainIntegerFormRow(
                  label: '期数',
                  controller: _totalPeriodsController,
                  hintText: '总期数',
                  validator: _validatePositiveInt,
                ),
                DateTimePlainFormRow(
                  label: '首期还款日',
                  dateTime: state.firstRepaymentDate,
                  value: formatDateLabel(state.firstRepaymentDate),
                  onTap: (onSelected) => _pickFirstRepaymentDate(
                    state.firstRepaymentDate,
                    onSelected,
                  ),
                  onChanged: (value) {
                    if (value != null) notifier.setFirstRepaymentDate(value);
                  },
                ),
                DateTimePlainFormRow(
                  label: '末期还款日',
                  dateTime: state.lastRepaymentDate,
                  value: state.lastRepaymentDate == null
                      ? '按期数和首期还款日自动生成'
                      : formatDateLabel(state.lastRepaymentDate!),
                  onTap: (onSelected) => _pickLastRepaymentDate(
                    state.lastRepaymentDate ?? state.firstRepaymentDate,
                    onSelected,
                  ),
                  onChanged: notifier.setLastRepaymentDate,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space12),
            AppFormSection(
              title: '还款规则',
              padding: _installmentSectionPadding,
              children: [
                AppPlainSelectMenuFormRow<InstallmentRepaymentMethod>(
                  label: '分期方式',
                  value: state.method,
                  options: installmentRepaymentMethodOptions,
                  onChanged: notifier.setMethod,
                ),
                if (state.method != InstallmentRepaymentMethod.flatFee &&
                    state.method != InstallmentRepaymentMethod.custom)
                  AppPlainSelectMenuFormRow<InterestAccrualMethod>(
                    label: '计息方式',
                    value: state.accrualMethod,
                    options: interestAccrualMethodOptions,
                    onChanged: notifier.setAccrualMethod,
                  ),
                if (state.method != InstallmentRepaymentMethod.flatFee &&
                    state.method != InstallmentRepaymentMethod.custom)
                  ValueWithUnitPlainFormRow<InterestRatePeriod>(
                    label: '利率',
                    controller: _rateController,
                    hintText: '例：7.2',
                    suffixText: '%',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    unit: state.ratePeriod,
                    unitOptions: interestRatePeriodOptions,
                    onUnitChanged: notifier.setRatePeriod,
                  ),
                if (state.method == InstallmentRepaymentMethod.equalInstallment)
                  MoneyPlainFormRow(
                    label: '还款固定额',
                    controller: _overrideInstallmentController,
                    hintText: '前 n-1 期固定额（可选）',
                    validator: validateOptionalNonNegativeMoneyText,
                  ),
                if (state.method == InstallmentRepaymentMethod.flatFee)
                  MoneyPlainFormRow(
                    label: '总手续费',
                    controller: _totalFeeController,
                    hintText: '所有期次手续费合计（可选）',
                    validator: validateOptionalNonNegativeMoneyText,
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.space12),
          AppFormSection(
            padding: _installmentSectionPadding,
            children: [NotePlainFormRow(controller: _noteController)],
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

  Future<void> _pickProduct(InstallmentFormViewModel notifier) async {
    final List<InstallmentProductReadModel> products;
    try {
      products = await ref.read(installmentProductsViewModelProvider.future);
    } catch (_) {
      if (mounted) _showError('产品加载失败，请稍后重试');
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final p in products.where((p) => !p.archived))
              ListTile(
                title: Text(p.name),
                onTap: () {
                  notifier.selectProduct(p);
                  Navigator.of(sheetContext).pop();
                },
              ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('管理分期产品'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/installment-products');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _preview(InstallmentFormViewModel notifier) async {
    final outcome = await notifier.preview(_principalController.text);
    if (!mounted) return;
    switch (outcome) {
      case UiActionFailure(:final error):
        _showError(error.message);
      case UiActionSuccess(:final value):
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(ctx).height * 0.75,
              child: ListView(
                children: [
                  ListTile(
                    title: Text('共 ${value.periods.length} 期'),
                    subtitle: Text(
                      '总利息 ${value.totalInterest.format()} · 手续费 ${value.totalFee.format()}',
                    ),
                  ),
                  for (final row in value.periods)
                    ListTile(
                      title: Text(
                        '第 ${row.periodNo} 期 · ${formatDateLabel(row.date)}',
                      ),
                      subtitle: Text(
                        '本金 ${row.principal.format()} · 利息 ${row.interest.format()} · 手续费 ${row.fee.format()}',
                      ),
                      trailing: Text(row.total.format()),
                    ),
                ],
              ),
            ),
          ),
        );
    }
  }

  Future<void> _pickBorrowingDate(
    DateTime initialDate,
    ValueChanged<DateTime?> onSelected,
  ) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initialDate,
      title: '选择借款日期',
    );
    if (picked == null || !mounted) return;
    onSelected(picked);
  }

  Future<void> _pickFirstRepaymentDate(
    DateTime initialDate,
    ValueChanged<DateTime?> onSelected,
  ) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initialDate,
      title: '选择首期还款日',
    );
    if (picked == null || !mounted) return;
    onSelected(picked);
  }

  Future<void> _pickLastRepaymentDate(
    DateTime initialDate,
    ValueChanged<DateTime?> onSelected,
  ) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initialDate,
      title: '选择末期还款日',
    );
    if (picked == null || !mounted) return;
    onSelected(picked);
  }

  Future<void> _pickAccount({
    required String title,
    required List<Account> accounts,
    required String? selectedId,
    required ValueChanged<String?> onSelected,
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

  String? _validatePositiveInt(String? value) {
    final n = int.tryParse((value ?? '').trim());
    if (n == null || n <= 0) return '期数必须为正整数';
    return null;
  }
}

Account? _findAccount(List<Account> accounts, String? id) {
  if (id == null) return null;
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return null;
}
