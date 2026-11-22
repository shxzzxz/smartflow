import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/shared/app_settings_store.dart';
import '../../../app/notification_providers.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_appearance_values.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_list_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_section_header.dart';
import '../../../design_system/widget/app_settings_row.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../shared/presentation/pull_to_create_sensitivity_options.dart';
import '../../shared/presentation/transaction_list_display_mode_options.dart';
import '../../shared/view_model/app_settings_view_model.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../widget/settings_color_row.dart';
import '../../../widget/business/finance/money_text.dart';
import '../../../design_system/widget/app_scaffold.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final settings =
        ref.watch(appSettingsViewModelProvider).value ?? const AppSettings();
    final notifier = ref.read(appSettingsViewModelProvider.notifier);
    final notificationsSupported = ref.watch(notificationsSupportedProvider);
    final notificationPermission =
        ref.watch(notificationPermissionProvider).value ?? false;
    final appearance = AppAppearanceValues.resolve(settings.appearance);
    final textStyles = context.appTextStyles;

    return AppScaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '设置'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  AppSpacing.space8,
                  AppSpacing.space16,
                  AppSpacing.space24,
                ),
                children: [
                  _SettingsSection(
                    title: '操作设置',
                    rows: [
                      AppSettingsSwitchRow(
                        label: '记账悬浮按钮',
                        value: settings.showAddTransactionFab,
                        onChanged: notifier.setShowAddTransactionFab,
                      ),
                      AppSettingsSelectRow<PullToCreateSensitivity>(
                        label: '首页下拉灵敏度',
                        value: settings.pullToCreateSensitivity,
                        options: pullToCreateSensitivityOptions,
                        onChanged: notifier.setPullToCreateSensitivity,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  _SettingsSection(
                    title: '交易设置',
                    rows: [
                      AppSettingsSelectRow<TransactionListDisplayMode>(
                        label: '交易列表信息',
                        value: settings.transactionListDisplayMode,
                        options: transactionListDisplayModeOptions,
                        onChanged: notifier.setTransactionListDisplayMode,
                      ),
                      SettingsColorRow(
                        label: '收入颜色',
                        value: appearance.incomeColor,
                        onChanged: notifier.setIncomeColor,
                        example: MoneyText(
                          money: const Money(minorUnits: 9999),
                          semantic: MoneySemantic.income,
                          showSign: true,
                          style: textStyles.listSupporting,
                        ),
                      ),
                      SettingsColorRow(
                        label: '支出颜色',
                        value: appearance.expenseColor,
                        onChanged: notifier.setExpenseColor,
                        example: MoneyText(
                          money: const Money(minorUnits: -1024),
                          semantic: MoneySemantic.expense,
                          style: textStyles.listSupporting,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  _SettingsSection(
                    title: '外观设置',
                    rows: [
                      AppSettingsRow(
                        label: '导航栏外观',
                        onTap: () =>
                            context.push('/profile/navigation-appearance'),
                        child: const Icon(RemixIcons.arrow_right_s_line),
                      ),
                      AppSettingsRow(
                        label: '顶部外观',
                        onTap: () => context.push('/profile/header-appearance'),
                        child: const Icon(RemixIcons.arrow_right_s_line),
                      ),
                      AppSettingsRow(
                        label: '主题外观',
                        onTap: () => context.push('/profile/theme-appearance'),
                        child: const Icon(RemixIcons.arrow_right_s_line),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  _SettingsSection(
                    title: '通知设置',
                    rows: [
                      AppSettingsSwitchRow(
                        label: '还款提醒',
                        description: '同日待还合并为一条通知',
                        value: settings.repaymentRemindersEnabled,
                        onChanged: (value) => _showOutcome(
                          context,
                          notifier.setRepaymentRemindersEnabled(value),
                        ),
                      ),
                      AppSettingsRow(
                        label: '还款提醒时间',
                        description: '还款日前一天提醒',
                        child: Text(
                          settings.repaymentReminderTime.toString(),
                          style: textStyles.listSupporting,
                        ),
                        onTap: () async {
                          final time = await showAppTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: settings.repaymentReminderTime.hour,
                              minute: settings.repaymentReminderTime.minute,
                            ),
                            title: '还款提醒时间',
                          );
                          if (time == null || !context.mounted) return;
                          await _showOutcome(
                            context,
                            notifier.setRepaymentReminderTime(
                              NotificationTime(
                                hour: time.hour,
                                minute: time.minute,
                              ),
                            ),
                          );
                        },
                      ),
                      AppSettingsRow(
                        label: '系统通知权限',
                        enabled: notificationsSupported,
                        child: Text(
                          !notificationsSupported
                              ? '当前平台不支持'
                              : notificationPermission
                              ? '已开启'
                              : '点击开启',
                          style: textStyles.listSupporting,
                          textAlign: TextAlign.end,
                        ),
                        onTap: () => _showOutcome(
                          context,
                          notifier.requestNotificationPermission(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOutcome(
    BuildContext context,
    Future<UiActionOutcome<void>> action,
  ) async {
    final outcome = await action;
    if (!context.mounted) return;
    if (outcome case UiActionFailure<void>(:final error)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return AppListSection(
      header: AppSectionHeader(title: title),
      children: rows,
    );
  }
}
