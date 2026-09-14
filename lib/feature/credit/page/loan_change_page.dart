import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/loan_change_presentation.dart';
import '../view_model/loan_change_state.dart';
import '../view_model/loan_change_view_model.dart';
import '../view_model/loan_configuration_view_model.dart';
import '../widget/loan_change_operation_dialog.dart';
import '../widget/loan_configuration_entry.dart';
import 'loan_configuration_page.dart';
import 'loan_plan_page.dart';

class LoanChangePage extends ConsumerWidget {
  const LoanChangePage({this.initial, super.key});
  final LoanConfiguration? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = loanChangeViewModelProvider(initial: initial);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '贷款变更试算'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.space16),
                children: [
                  LoanConfigurationEntry(
                    label: '贷款配置',
                    configured: state.configuration != null,
                    onTap: () =>
                        _configure(context, notifier, state.configuration),
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  AppFormSection(
                    title: '试算操作',
                    children: [
                      if (state.operations.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.space16,
                          ),
                          child: Text('添加提前还款、重定价或利息调整，可组合多次操作。'),
                        ),
                      for (final operation in state.operations)
                        ListTile(
                          key: ValueKey('loan-operation-${operation.id}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(loanChangeOperationLabel(operation.kind)),
                          subtitle: Text(
                            loanChangeOperationDescription(operation, state),
                          ),
                          onTap: () => _edit(
                            context,
                            notifier,
                            state,
                            operation.kind,
                            operation,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: '编辑操作',
                                icon: const Icon(RemixIcons.edit_line),
                                onPressed: () => _edit(
                                  context,
                                  notifier,
                                  state,
                                  operation.kind,
                                  operation,
                                ),
                              ),
                              IconButton(
                                tooltip: '删除操作',
                                icon: const Icon(RemixIcons.delete_bin_line),
                                onPressed: () =>
                                    notifier.removeOperation(operation.id),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: state.configuration == null
                              ? null
                              : () => _add(context, notifier, state),
                          icon: const Icon(RemixIcons.add_line),
                          label: const Text('添加操作'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space24),
                  AppSubmitButton(
                    label: '试算',
                    onPressed: state.configuration == null
                        ? null
                        : () => _simulate(context, notifier),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _configure(
    BuildContext context,
    LoanChangeViewModel notifier,
    LoanConfiguration? configuration,
  ) async {
    final value = await Navigator.of(context).push<LoanConfiguration>(
      MaterialPageRoute(
        builder: (_) =>
            LoanConfigurationPage(initial: configuration, selection: true),
      ),
    );
    if (context.mounted && value != null) notifier.setConfiguration(value);
  }

  Future<void> _add(
    BuildContext context,
    LoanChangeViewModel notifier,
    LoanChangeState state,
  ) async {
    final kind = await showModalBottomSheet<LoanChangeOperationKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kind in LoanChangeOperationKind.values)
              ListTile(
                title: Text(loanChangeOperationLabel(kind)),
                enabled:
                    kind != LoanChangeOperationKind.repricing ||
                    state.repricingStages.isNotEmpty,
                onTap: () => Navigator.of(context).pop(kind),
              ),
          ],
        ),
      ),
    );
    if (context.mounted && kind != null) {
      await _edit(context, notifier, state, kind);
    }
  }

  Future<void> _edit(
    BuildContext context,
    LoanChangeViewModel notifier,
    LoanChangeState state,
    LoanChangeOperationKind kind, [
    LoanChangeOperation? operation,
  ]) => showDialog<void>(
    context: context,
    builder: (_) => LoanChangeOperationDialog(
      state: state,
      notifier: notifier,
      kind: kind,
      initial: operation,
    ),
  );

  Future<void> _simulate(
    BuildContext context,
    LoanChangeViewModel notifier,
  ) async {
    final outcome = await notifier.simulate();
    if (!context.mounted) return;
    switch (outcome) {
      case UiActionFailure(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      case UiActionSuccess(:final value):
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => LoanPlanPage.changes(simulation: value),
          ),
        );
    }
  }
}
