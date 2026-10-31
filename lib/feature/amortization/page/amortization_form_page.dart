import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/orchestration/orchestration_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_segmented_control.dart';
import '../../../widget/business/account/account_picker_sheet.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../../widget/business/form/plain_transaction_fields.dart';
import '../../../domain/ledger/entity/account.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/amortization_form_view_model.dart';

class AmortizationFormPage extends ConsumerStatefulWidget {
  const AmortizationFormPage({
    this.initialKind = AmortizationKind.prepaidExpense,
    this.initialDeferralAccountId,
    super.key,
  });

  final AmortizationKind initialKind;
  final String? initialDeferralAccountId;

  @override
  ConsumerState<AmortizationFormPage> createState() =>
      _AmortizationFormPageState();
}

class _AmortizationFormPageState extends ConsumerState<AmortizationFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _intervalController;
  late final TextEditingController _countController;
  late final TextEditingController _feeController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _intervalController = TextEditingController(text: '1');
    _countController = TextEditingController(text: '1');
    _feeController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _intervalController.dispose();
    _countController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = amortizationFormViewModelProvider(
      widget.initialKind.name,
      widget.initialDeferralAccountId,
    );
    final asyncState = ref.watch(provider);
    return switch (asyncState) {
      AsyncData(value: final state) => _buildForm(context, provider, state),
      AsyncError() => _StatusScaffold(title: '新建摊销', message: '摊销表单加载失败，请稍后重试'),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }

  Widget _buildForm(
    BuildContext context,
    AmortizationFormViewModelProvider provider,
    AmortizationFormState state,
  ) {
    final notifier = ref.read(provider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _FormHeader(
                title: '新建摊销',
                submitting: state.submitting,
                onSave: () => _submit(state, notifier),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space16,
                    AppSpacing.space16,
                    AppSpacing.space16,
                    AppSpacing.space24,
                  ),
                  children: [
                    AppFormSection(
                      title: '类型',
                      children: [
                        AppPlainSegmentedFormRow<AmortizationKind>(
                          label: '摊销类型',
                          value: state.kind,
                          segments: const [
                            AppSegment(
                              value: AmortizationKind.prepaidExpense,
                              label: '预付费用',
                            ),
                            AppSegment(
                              value: AmortizationKind.deferredIncome,
                              label: '预收收入',
                            ),
                          ],
                          onChanged: notifier.setKind,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space24),
                    AppFormSection(
                      title: '收付',
                      children: [
                        MoneyPlainFormRow(
                          label: '总额',
                          controller: _amountController,
                          hintText: '请输入预付或预收金额',
                          requiredIndicator: true,
                          validator: validatePositiveMoneyText,
                        ),
                        AccountPlainFormRow(
                          label: state.kind == AmortizationKind.prepaidExpense
                              ? '付款账户'
                              : '收款账户',
                          account: findAccountById(
                            state.fundingAccountId,
                            state.fundAccounts,
                          ),
                          placeholder: '请选择资金账户',
                          onTap: (onSelected) => _pickAccount(
                            title: '选择资金账户',
                            accountList: state.fundAccounts,
                            selectedId: state.fundingAccountId,
                            onSelected: notifier.setFundingAccountId,
                          ),
                        ),
                        AccountPlainFormRow(
                          label: '递延账户',
                          account: findAccountById(
                            state.deferralAccountId,
                            state.deferralAccounts,
                          ),
                          placeholder: state.deferralAccounts.isEmpty
                              ? '请先创建预付或预收账户'
                              : '请选择递延账户',
                          onTap: (onSelected) => _pickAccount(
                            title: '选择递延账户',
                            accountList: state.deferralAccounts,
                            selectedId: state.deferralAccountId,
                            onSelected: notifier.setDeferralAccountId,
                          ),
                        ),
                        if (state.kind == AmortizationKind.prepaidExpense)
                          MoneyPlainFormRow(
                            label: '手续费',
                            controller: _feeController,
                            hintText: '0.00',
                            validator: validateOptionalNonNegativeMoneyText,
                          ),
                        DateTimePlainFormRow(
                          label: '收付日期',
                          dateTime: state.occurredAt,
                          value: _formatDate(state.occurredAt),
                          onTap: (onSelected) => _pickDateTime(
                            initial: state.occurredAt,
                            onSelected: notifier.setOccurredAt,
                          ),
                          onChanged: (_) {},
                          showChevron: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space24),
                    AppFormSection(
                      title: '确认',
                      children: [
                        AppPlainSelectFormRow<String>(
                          label: '确认分类',
                          value: state.categoryAccountId,
                          valueText: _categoryName(
                            state.categoryAccounts,
                            state.categoryAccountId,
                          ),
                          placeholder: '请选择收入或支出分类',
                          onTap: (onSelected) => _pickCategory(
                            accounts: state.categoryAccounts,
                            onSelected: notifier.setCategoryAccountId,
                          ),
                        ),
                        DateTimePlainFormRow(
                          label: '首期日期',
                          dateTime: state.firstRecognitionAt,
                          value: _formatDate(state.firstRecognitionAt),
                          onTap: (onSelected) => _pickDate(
                            initial: state.firstRecognitionAt,
                            onSelected: notifier.setFirstRecognitionAt,
                          ),
                          onChanged: (_) {},
                          showChevron: true,
                        ),
                        AppPlainSegmentedFormRow<AmortizationCadenceUnit>(
                          label: '间隔方式',
                          value: state.cadenceUnit,
                          segments: const [
                            AppSegment(
                              value: AmortizationCadenceUnit.daily,
                              label: '天',
                            ),
                            AppSegment(
                              value: AmortizationCadenceUnit.monthly,
                              label: '月',
                            ),
                            AppSegment(
                              value: AmortizationCadenceUnit.yearly,
                              label: '年',
                            ),
                          ],
                          onChanged: notifier.setCadenceUnit,
                        ),
                        AppPlainIntegerFormRow(
                          label: '间隔',
                          controller: _intervalController,
                          hintText: '请输入间隔',
                          requiredIndicator: true,
                          validator: _positiveIntegerValidator,
                        ),
                        AppPlainIntegerFormRow(
                          label: '期数',
                          controller: _countController,
                          hintText: '请输入确认期数',
                          requiredIndicator: true,
                          validator: _positiveIntegerValidator,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space24),
                    AppFormSection(
                      title: '计划配置',
                      children: [
                        AppPlainSwitchRow(
                          label: '默认不计收支',
                          description: '应用于之后生成的计划交易，可单独调整。',
                          value: state.excludeStats,
                          onChanged: notifier.setDefaultExcludedFromStats,
                        ),
                        AppPlainSwitchRow(
                          label: '默认不计预算',
                          value: state.excludeBudget,
                          onChanged: notifier.setDefaultExcludedFromBudget,
                        ),
                        NotePlainFormRow(controller: _noteController),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(
    AmortizationFormState state,
    AmortizationFormViewModel notifier,
  ) async {
    if (!_formKey.currentState!.validate() || state.submitting) return;
    final outcome = await notifier.submit(
      amountText: _amountController.text,
      intervalText: _intervalController.text,
      countText: _countController.text,
      feeText: _feeController.text,
      noteText: _noteController.text,
    );
    if (!mounted) return;
    switch (outcome) {
      case UiActionSuccess(:final value):
        context.pushReplacement('/amortizations/$value');
      case UiActionFailure(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _pickAccount({
    required String title,
    required List<Account> accountList,
    required String? selectedId,
    required ValueChanged<String?> onSelected,
  }) async {
    final selected = await showAccountPickerSheet(
      context: context,
      accounts: accountList,
      selectedId: selectedId,
    );
    if (selected != null) onSelected(selected);
  }

  Future<void> _pickCategory({
    required List<Account> accounts,
    required ValueChanged<String?> onSelected,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final account in accounts)
              ListTile(
                title: Text(account.name),
                trailing: account.parentId == null
                    ? null
                    : const Icon(RemixIcons.arrow_right_s_line),
                onTap: () => Navigator.of(sheetContext).pop(account.id),
              ),
          ],
        ),
      ),
    );
    if (selected != null) onSelected(selected);
  }

  Future<void> _pickDateTime({
    required DateTime initial,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final selected = await showAppDateTimePicker(
      context: context,
      initialDateTime: initial,
    );
    if (selected != null) onSelected(selected);
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: initial,
    );
    if (selected != null) onSelected(selected);
  }
}

class _FormHeader extends StatelessWidget {
  const _FormHeader({
    required this.title,
    required this.submitting,
    required this.onSave,
  });

  final String title;
  final bool submitting;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space12,
        AppSpacing.space12,
        AppSpacing.space4,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(RemixIcons.arrow_left_s_line),
              tooltip: '返回',
              style: appHeaderIconButtonStyle,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: submitting ? null : onSave,
              child: submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('创建'),
            ),
          ),
          Text(title, style: context.appTextStyles.dateNavigationTitle),
        ],
      ),
    );
  }
}

class _StatusScaffold extends StatelessWidget {
  const _StatusScaffold({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: title),
            Expanded(child: Center(child: Text(message))),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String? _categoryName(List<Account> accounts, String? id) {
  if (id == null) return null;
  for (final account in accounts) {
    if (account.id == id) return account.name;
  }
  return null;
}

String? _positiveIntegerValidator(String? value) {
  final parsed = int.tryParse(value ?? '');
  return parsed == null || parsed <= 0 ? '请输入正整数' : null;
}
