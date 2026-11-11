import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_status_banner.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../../widget/business/transaction/transaction_feed.dart';
import '../../shared/provider/current_date_time_provider.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/account_reconciliation_view_model.dart';

class AccountReconciliationPage extends ConsumerStatefulWidget {
  const AccountReconciliationPage({required this.accountId, super.key});

  final String accountId;

  @override
  ConsumerState<AccountReconciliationPage> createState() =>
      _AccountReconciliationPageState();
}

class _AccountReconciliationPageState
    extends ConsumerState<AccountReconciliationPage> {
  late final TextEditingController _expectedBalanceController;

  @override
  void initState() {
    super.initState();
    _expectedBalanceController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant AccountReconciliationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) {
      _expectedBalanceController.clear();
    }
  }

  @override
  void dispose() {
    _expectedBalanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountId = widget.accountId;
    final state = ref.watch(accountReconciliationViewModelProvider(accountId));
    final loaded = state is AccountReconciliationLoaded ? state : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '账户对账',
              actions: [
                AppHeaderTextButton(
                  label: loaded?.submitting == true ? '确认中…' : '确认',
                  onPressed: loaded?.canConfirm == true
                      ? () => _confirm(loaded!)
                      : null,
                ),
              ],
            ),
            Expanded(
              child: switch (state) {
                AccountReconciliationLoaded() => _LoadedContent(
                  state: state,
                  expectedBalanceController: _expectedBalanceController,
                  onPickRange: () => _pickRange(state),
                  onExpectedBalanceChanged: (value) => ref
                      .read(
                        accountReconciliationSelectionProvider(
                          accountId,
                        ).notifier,
                      )
                      .setExpectedBalanceText(value),
                ),
                AccountReconciliationNotFound() => const Center(
                  child: Text('账户不存在'),
                ),
                AccountReconciliationError(:final message) => Center(
                  child: Text(message),
                ),
                AccountReconciliationLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange(AccountReconciliationLoaded state) async {
    final now = ref.read(currentDateTimeProvider);
    final range = await showAppDateRangePicker(
      context: context,
      initialRange: DateTimeRange(start: state.from, end: state.untilInclusive),
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (range == null || !mounted) return;
    ref
        .read(accountReconciliationSelectionProvider(widget.accountId).notifier)
        .setRange(range.start, range.end);
  }

  Future<void> _confirm(AccountReconciliationLoaded state) async {
    if (state.changedDayCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('更新对账快照？'),
          content: Text(
            '有 ${state.changedDayCount} 天的流水与上次确认时不同。'
            '确认后将使用当前流水更新这些日期的快照。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final outcome = await ref
        .read(accountReconciliationViewModelProvider(widget.accountId).notifier)
        .confirm();
    if (!mounted) return;
    switch (outcome) {
      case UiActionSuccess():
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('对账快照已更新')));
        context.go('/account/${state.account.id}');
      case UiActionFailure(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _LoadedContent extends StatelessWidget {
  const _LoadedContent({
    required this.state,
    required this.expectedBalanceController,
    required this.onPickRange,
    required this.onExpectedBalanceChanged,
  });

  final AccountReconciliationLoaded state;
  final TextEditingController expectedBalanceController;
  final VoidCallback onPickRange;
  final ValueChanged<String> onExpectedBalanceChanged;

  @override
  Widget build(BuildContext context) {
    return TransactionFeedScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space8,
        AppSpacing.space16,
        AppSpacing.space24,
      ),
      leading: [
        AppFormSection(
          title: '对账范围',
          description: '结束日期望余额用于从结束日向前推算每日期望余额',
          children: [
            AppPlainFormRow(
              label: '日期范围',
              onTap: onPickRange,
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.space4),
                      child: AppPlainValueText(
                        text:
                            '${_dateLabel(state.from)} - '
                            '${_dateLabel(state.untilInclusive)}',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: AppSpacing.space48,
                    height: AppSpacing.space48,
                    child: Center(
                      child: Icon(
                        RemixIcons.arrow_right_s_line,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            MoneyPlainFormRow(
              label: '期望余额',
              controller: expectedBalanceController,
              hintText: '结束日期望余额',
              onChanged: onExpectedBalanceChanged,
            ),
          ],
        ),
        if (state.changedDayCount > 0) ...[
          const SizedBox(height: AppSpacing.space12),
          AppStatusBanner(
            tone: AppStatusBannerTone.warning,
            message: '有 ${state.changedDayCount} 天的流水与上次确认时不同。',
          ),
        ],
        if (state.unconfirmedDayCount > 0) ...[
          const SizedBox(height: AppSpacing.space12),
          AppStatusBanner(
            tone: AppStatusBannerTone.info,
            message: '有 ${state.unconfirmedDayCount} 天新增流水尚未对账。',
          ),
        ],
        const SizedBox(height: AppSpacing.space16),
      ],
      groups: state.groups,
      emptyMessage: '所选范围暂无账户流水',
      groupEmptyMessage: '该日原流水已删除',
      showDailyTotals: false,
      showClosingBalance: true,
    );
  }

  String _dateLabel(DateTime value) {
    return '${value.year}.${value.month.toString().padLeft(2, '0')}.'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
