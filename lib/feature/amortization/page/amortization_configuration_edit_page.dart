import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../app/provider.dart';
import '../../../application/orchestration/orchestration_command_api.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_segmented_control.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/amortization_providers.dart';
import '../../../widget/business/form/plain_transaction_fields.dart';

class AmortizationConfigurationEditPage extends ConsumerWidget {
  const AmortizationConfigurationEditPage({required this.planId, super.key});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(amortizationPlanProvider(planId));
    return switch (plan) {
      AsyncData(value: final plan?) => _ConfigurationForm(
        key: ValueKey(planId),
        plan: plan,
      ),
      AsyncData(value: null) => const _StatusPage(message: '摊销计划不存在'),
      AsyncError() => const _StatusPage(message: '摊销计划加载失败'),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _ConfigurationForm extends ConsumerStatefulWidget {
  const _ConfigurationForm({required this.plan, super.key});

  final AmortizationPlan plan;

  @override
  ConsumerState<_ConfigurationForm> createState() => _ConfigurationFormState();
}

class _ConfigurationFormState extends ConsumerState<_ConfigurationForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _intervalController;
  late final TextEditingController _countController;
  late DateTime _firstRecognitionAt;
  late AmortizationCadenceUnit _cadenceUnit;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _firstRecognitionAt = plan.firstRecognitionAt;
    _cadenceUnit = plan.cadenceUnit;
    _intervalController = TextEditingController(
      text: '${plan.cadenceInterval}',
    );
    _countController = TextEditingController(text: '${plan.recognitionCount}');
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '配置编辑',
              onBack: () => Navigator.of(context).maybePop(),
            ),
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
                      title: '摊销配置',
                      children: [
                        DateTimePlainFormRow(
                          label: '首期日期',
                          dateTime: _firstRecognitionAt,
                          value: _formatDate(_firstRecognitionAt),
                          onTap: (onSelected) =>
                              _pickDate(onSelected: onSelected),
                          onChanged: (_) {},
                          showChevron: true,
                        ),
                        AppPlainSegmentedFormRow<AmortizationCadenceUnit>(
                          label: '间隔方式',
                          value: _cadenceUnit,
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
                          onChanged: (value) {
                            setState(() => _cadenceUnit = value);
                          },
                        ),
                        AppPlainIntegerFormRow(
                          label: '间隔数',
                          controller: _intervalController,
                          hintText: '请输入间隔',
                          requiredIndicator: true,
                          validator: _positiveIntegerValidator,
                        ),
                        AppPlainIntegerFormRow(
                          label: '摊销期数',
                          controller: _countController,
                          hintText: '请输入摊销期数',
                          requiredIndicator: true,
                          validator: _positiveIntegerValidator,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space8,
                AppSpacing.space16,
                AppSpacing.space8,
              ),
              child: AppSubmitButton(
                label: '保存并重算',
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required ValueChanged<DateTime?> onSelected}) async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: _firstRecognitionAt,
    );
    if (selected == null || !mounted) return;
    setState(() => _firstRecognitionAt = selected);
    onSelected(selected);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _submitting) return;
    setState(() => _submitting = true);
    final outcome = await guardUiAction(
      _logger,
      'Update amortization configuration',
      () => ref
          .read(amortizationPlanAppServiceProvider)
          .updateConfiguration(
            UpdateAmortizationConfigurationCommand(
              planId: widget.plan.id,
              firstRecognitionAt: _firstRecognitionAt,
              cadenceUnit: _cadenceUnit,
              cadenceInterval: int.parse(_intervalController.text),
              recognitionCount: int.parse(_countController.text),
              now: DateTime.now(),
            ),
          ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (outcome) {
      case UiActionSuccess():
        ref
          ..invalidate(amortizationPlanProvider(widget.plan.id))
          ..invalidate(amortizationPlansProvider());
        Navigator.of(context).pop();
      case UiActionFailure(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _StatusPage extends StatelessWidget {
  const _StatusPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '配置编辑'),
            Expanded(child: Center(child: Text(message))),
          ],
        ),
      ),
    );
  }
}

final _logger = Logger('feature.amortization.configuration_edit');

String _formatDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String? _positiveIntegerValidator(String? value) {
  final parsed = int.tryParse(value ?? '');
  return parsed == null || parsed <= 0 ? '请输入正整数' : null;
}
