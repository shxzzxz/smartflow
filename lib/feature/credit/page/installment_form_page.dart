import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/installment_schedule_presentation.dart';
import '../view_model/installment_form_view_model.dart';
import '../widget/installment_plan_summary_card.dart';
import '../widget/installment_schedule_view.dart';
import '../widget/installment_terms_editor.dart';
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
            title: '贷款',
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
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          AppFormSection(
            title: '放款信息',
            padding: _installmentSectionPadding,
            children: [
              AppPlainSwitchRow(
                label: '创建放款交易',
                description: '迁移已有贷款时可关闭，仅创建合同和还款计划',
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
            ],
          ),
          if (state.canChooseProduct) ...[
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
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.space12),
          AppPlainSwitchRow(
            label: '自定义本笔贷款',
            description: '开启后可修改阶段结构和计算规则；关闭保留修改',
            value: state.customRules,
            onChanged: notifier.setCustomRules,
          ),
          InstallmentTermsEditor(
            value: state.termsDraft,
            onChanged: notifier.setTermsDraft,
            borrowingDate: state.borrowingDate,
            rulesEditable: state.customRules,
            usesBillingCycle: state.usesBillingCycle,
            planAction: state.usesBillingCycle
                ? null
                : AppSubmitButton(
                    label: '预览还款计划',
                    onPressed: () => _preview(notifier),
                  ),
          ),
          if (state.usesBillingCycle) const Text('信用账户按账期生成单阶段计划，创建后可查看还款明细。'),
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
      products = await notifier.loadProducts();
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
    if (!_formKey.currentState!.validate()) return;
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
                padding: const EdgeInsets.all(AppSpacing.space16),
                children: [
                  InstallmentPlanSummaryCard(
                    metrics: value.metrics,
                    principal: value.totalPrincipal,
                    periodCount: value.periods.length,
                    stages: value.stages,
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  InstallmentScheduleView(
                    items: calculationScheduleItems(
                      value.periods,
                      stages: value.stages,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }
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
