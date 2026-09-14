import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';

import '../../../core/money/money.dart';
import '../../../domain/credit/valobj/bill_period.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../design_system/widget/app_status_banner.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/bill_conversion_installment_form_view_model.dart';
import '../view_model/loan_configuration_view_model.dart';
import '../widget/loan_basic_info_fields.dart';
import 'loan_configuration_page.dart';

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
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  bool _controllersHydrated = false;

  @override
  void dispose() {
    _principalController.dispose();
    _nameController.dispose();
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
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '账单分期'),
            Expanded(
              child: switch (asyncState) {
                AsyncData(value: final state) => _buildState(provider, state),
                AsyncError() => const Center(child: Text('加载失败，请稍后重试')),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
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
    _hydrateControllers(state);
    final notifier = ref.read(provider.notifier);
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
          const AppStatusBanner(
            message: '仅支持消费账单明细进行账单分期还款',
            tone: AppStatusBannerTone.info,
          ),
          const SizedBox(height: AppSpacing.space12),
          AppFormSection(
            children: [
              AppPlainValueRow(
                label: '账单',
                value: _periodLabel(state.summary.period),
              ),
              AppPlainValueRow(
                label: '可分期本金',
                value: state.convertiblePrincipal.format(),
              ),
              LoanBasicInfoFields(
                principalController: _principalController,
                borrowingDate: state.borrowingDate,
                onBorrowingDateChanged: notifier.setBorrowingDate,
              ),
              NotePlainFormRow(controller: _noteController),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          AppFormSection(
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
            onPressed: () => _submit(provider),
          ),
        ],
      ),
    );
  }

  Future<void> _configure(BillConversionInstallmentLoaded state) async {
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
        .read(
          billConversionInstallmentFormViewModelProvider(
            widget.billId,
          ).notifier,
        )
        .applyConfiguration(configuration);
  }

  Future<void> _submit(
    BillConversionInstallmentFormViewModelProvider provider,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    final outcome = await ref
        .read(provider.notifier)
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

  void _hydrateControllers(BillConversionInstallmentLoaded state) {
    if (_controllersHydrated) return;
    syncTextControllerText(_principalController, state.principalText);
    _controllersHydrated = true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

String _periodLabel(BillPeriod period) {
  return '${period.year}年${period.month.toString().padLeft(2, '0')}月账单';
}
