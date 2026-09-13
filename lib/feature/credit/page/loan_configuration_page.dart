import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/loan_configuration_view_model.dart';
import '../widget/installment_terms_editor.dart';
import '../widget/loan_basic_info_fields.dart';
import 'loan_plan_page.dart';

class LoanConfigurationPage extends ConsumerStatefulWidget {
  const LoanConfigurationPage({
    this.initial,
    this.selection = false,
    this.installment,
    super.key,
  });
  final LoanConfiguration? initial;
  final bool selection;
  final InstallmentConfigurationDraft? installment;

  @override
  ConsumerState<LoanConfigurationPage> createState() =>
      _LoanConfigurationPageState();
}

class _LoanConfigurationPageState extends ConsumerState<LoanConfigurationPage> {
  final _formKey = GlobalKey<FormState>();
  late final _principalController = TextEditingController(
    text:
        widget.installment?.principal?.format() ??
        widget.initial?.principal.format(),
  );

  LoanConfigurationViewModelProvider get _provider =>
      loanConfigurationViewModelProvider(
        initial: widget.initial,
        selection: widget.selection,
        installment: widget.installment,
      );

  @override
  void dispose() {
    _principalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final notifier = ref.read(_provider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '贷款配置'),
            Expanded(
              child: Form(
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
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: AppPlainSelectFormRow<String>(
                                label: '产品模板',
                                value: state.productName,
                                placeholder: '请选择',
                                onTap: (_) => _pickProduct(notifier),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.space8),
                            Expanded(
                              child: FilterChip(
                                label: const Center(child: Text('高级配置')),
                                selected: state.advanced,
                                showCheckmark: false,
                                onSelected: notifier.setAdvanced,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    AppFormSection(
                      title: '贷款',
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space16,
                        vertical: AppSpacing.space8,
                      ),
                      children: [
                        if (state.installment?.basicInfoReadOnly == true)
                          LoanBasicInfoFields.readOnly(
                            principal: state.installment!.principal!,
                            borrowingDate: state.borrowingDate,
                          )
                        else
                          LoanBasicInfoFields(
                            principalController: _principalController,
                            borrowingDate: state.borrowingDate,
                            onBorrowingDateChanged: notifier.setBorrowingDate,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    InstallmentTermsEditor(
                      mode: state.installment == null
                          ? InstallmentTermsEditorMode.calculator
                          : InstallmentTermsEditorMode.contract,
                      value: state.terms,
                      onChanged: notifier.setTerms,
                      borrowingDate: state.borrowingDate,
                      showAdvanced: state.advanced,
                      repricingConfigurationEditable:
                          state.installment?.basicInfoReadOnly != true,
                      planAction: AppSubmitButton(
                        label: state.submitLabel,
                        onPressed: () => _submit(notifier, state.selection),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProduct(LoanConfigurationViewModel notifier) async {
    final outcome = await notifier.loadProducts();
    if (!mounted) return;
    switch (outcome) {
      case UiActionFailure(:final error):
        _showError(error.message);
      case UiActionSuccess(:final value):
        final product = await showModalBottomSheet<InstallmentProductReadModel>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text('选择产品模板'),
                  subtitle: Text('加载产品规则后，填写本次贷款的金额、期限和利率'),
                ),
                if (value.isEmpty) const ListTile(title: Text('暂无可用的产品模板')),
                for (final product in value)
                  ListTile(
                    title: Text(product.name),
                    onTap: () => Navigator.of(context).pop(product),
                  ),
              ],
            ),
          ),
        );
        if (mounted && product != null) notifier.selectProduct(product);
    }
  }

  Future<void> _submit(
    LoanConfigurationViewModel notifier,
    bool selection,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (widget.installment != null) {
      final outcome = await notifier.submitInstallment(
        _principalController.text,
      );
      if (!mounted) return;
      switch (outcome) {
        case UiActionFailure(:final error):
          _showError(error.message);
        case UiActionSuccess(:final value):
          Navigator.of(context).pop(value);
      }
      return;
    }
    final outcome = await notifier.submit(_principalController.text);
    if (!mounted) return;
    switch (outcome) {
      case UiActionFailure(:final error):
        _showError(error.message);
      case UiActionSuccess(:final value):
        if (selection) {
          Navigator.of(context).pop(value);
        } else {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => LoanPlanPage(calculation: value.calculation),
            ),
          );
        }
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
