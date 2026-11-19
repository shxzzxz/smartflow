import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/app_shell.dart';
import '../../../application/shared/app_settings_store.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_theme.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/finance/money_text.dart';
import '../../../design_system/widget/app_scaffold.dart';

/// 只读示例复用实际主题、财务金额、导航和记账按钮，不加载用户数据。
class PersonalizationPreview extends StatelessWidget {
  const PersonalizationPreview({
    required this.appearance,
    required this.showAddTransactionFab,
    required this.settings,
    super.key,
  });

  final AppAppearanceSettings appearance;
  final bool showAddTransactionFab;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.dark(appearance: appearance)
        : AppTheme.light(appearance: appearance);
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) => MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: IgnorePointer(
            child: AppScaffold(
              extendBody: true,
              body: const _PreviewBody(),
              floatingActionButton: showAddTransactionFab
                  ? FloatingActionButton(
                      onPressed: () {},
                      tooltip: '记账悬浮按钮',
                      shape: const CircleBorder(),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      child: const Icon(RemixIcons.add_line),
                    )
                  : null,
              bottomNavigationBar: AppBottomNavigationBar(
                style: settings.bottomNavigationStyle,
                selectedIndex: 0,
                showLabels: settings.showBottomNavLabels,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space12,
          AppSpacing.space12,
          AppSpacing.space12,
          AppComponentTokens.navigationBarHeight,
        ),
        children: [
          Text('首页', style: text.titleMedium),
          const SizedBox(height: AppSpacing.space8),
          AppSurface(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('本月收支', style: text.labelLarge),
                  const SizedBox(height: AppSpacing.space8),
                  Row(
                    children: [
                      Expanded(
                        child: _PreviewAmount(
                          label: '收入',
                          money: const Money(minorUnits: 1000000),
                          semantic: MoneySemantic.income,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space16),
                      Expanded(
                        child: _PreviewAmount(
                          label: '支出',
                          money: const Money(minorUnits: 320000),
                          semantic: MoneySemantic.expense,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (constraints.maxHeight >=
              AppComponentTokens.personalizationPreviewDetailsMinHeight *
                  textScale) ...[
            const SizedBox(height: AppSpacing.space12),
            AppSurface(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('最近流水', style: text.labelLarge),
                    const SizedBox(height: AppSpacing.space8),
                    Row(
                      children: [
                        Expanded(child: Text('餐饮', style: text.bodyMedium)),
                        MoneyText(
                          money: const Money(minorUnits: -4200),
                          semantic: MoneySemantic.expense,
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.space8),
          Text(
            '示例数据',
            style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PreviewAmount extends StatelessWidget {
  const _PreviewAmount({
    required this.label,
    required this.money,
    required this.semantic,
  });

  final String label;
  final Money money;
  final MoneySemantic semantic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: MoneyText(
            money: money,
            semantic: semantic,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}
