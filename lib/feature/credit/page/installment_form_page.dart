import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/installment_form_view_model.dart';
import '../view_model/loan_configuration_view_model.dart';
import 'loan_configuration_page.dart';
import '../widget/loan_basic_info_fields.dart';

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
  final _nameController = TextEditingController();
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
    _nameController.dispose();
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
              LoanBasicInfoFields(
                principalController: _principalController,
                borrowingDate: state.borrowingDate,
                onBorrowingDateChanged: notifier.setBorrowingDate,
              ),
              AppPlainSwitchRow(
                label: '创建交易',
                description: '关闭则仅创建合同和计划',
                value: state.createDisbursementTransaction,
                onChanged: notifier.setCreateDisbursementTransaction,
              ),
              if (state.createDisbursementTransaction)
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
              NotePlainFormRow(controller: _noteController),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          AppFormSection(
            padding: _installmentSectionPadding,
            children: [
              AppPlainSelectFormRow<String>(
                label: '分期配置',
                value: state.productName ?? '自定义',
                placeholder: '点击配置',
                onTap: (_) => _configure(state),
              ),
              AppPlainTextFormRow(
                label: '合同名称',
                controller: _nameController,
                hintText: '选填，默认使用借款日期',
              ),
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

  Future<void> _configure(InstallmentFormLoaded state) async {
    FocusScope.of(context).unfocus();
    final initial = InstallmentConfigurationDraft(
      principal: Money.tryParse(_principalController.text.trim()),
      borrowingDate: state.borrowingDate,
      terms: state.termsDraft,
      productId: state.productId,
      productName: state.productName,
    );
    final configuration = await Navigator.of(context)
        .push<InstallmentConfigurationDraft>(
          MaterialPageRoute(
            builder: (_) => LoanConfigurationPage(installment: initial),
          ),
        );
    if (!mounted || configuration == null) return;
    _principalController.text = configuration.principal!.format();
    ref
        .read(installmentFormViewModelProvider(_args).notifier)
        .applyConfiguration(configuration);
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
          nameText: _nameController.text,
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
}

Account? _findAccount(List<Account> accounts, String? id) {
  if (id == null) return null;
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return null;
}
