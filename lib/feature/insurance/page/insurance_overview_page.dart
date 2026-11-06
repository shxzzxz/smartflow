import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/token/component.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_section_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../presentation/insurance_presentation.dart';
import '../view_model/insurance_overview_view_model.dart';
import '../widget/insurance/insurance_metric_strip.dart';
import '../widget/insurance/insurance_overview_hero.dart';
import '../widget/member/insurance_member_strip.dart';

class InsuranceOverviewPage extends ConsumerWidget {
  const InsuranceOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(insuranceOverviewViewModelProvider);
    final value = overview.asData?.value;
    final hasMembers = value?.overview.members.isNotEmpty ?? false;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '保险',
              actions: [
                AppHeaderIconButton(
                  icon: RemixIcons.user_heart_line,
                  tooltip: '成员管理',
                  onPressed: () => context.push('/insurance/members'),
                ),
                AppHeaderIconButton(
                  icon: RemixIcons.shield_check_line,
                  tooltip: '保单管理',
                  onPressed: () => context.push('/insurance/policies'),
                ),
              ],
            ),
            Expanded(
              child: overview.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(insuranceOverviewViewModelProvider),
                    child: const Text('加载失败，点击重试'),
                  ),
                ),
                data: (state) => ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space16,
                    AppSpacing.space8,
                    AppSpacing.space16,
                    AppSpacing.space24,
                  ),
                  children: [
                    const InsuranceOverviewHero(),
                    const SizedBox(height: AppSpacing.space20),
                    const AppSectionHeader(title: '家庭保障概况'),
                    const SizedBox(height: AppSpacing.space8),
                    AppSurface(
                      border: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space8,
                          vertical: AppSpacing.space8,
                        ),
                        child: InsuranceMetricStrip(
                          metrics: [
                            InsuranceMetric(
                              icon: RemixIcons.shield_check_fill,
                              label: '保单数量',
                              value: '${state.overview.activePolicyCount}',
                            ),
                            InsuranceMetric(
                              icon: RemixIcons.team_fill,
                              label: '保障成员',
                              value: '${state.overview.coveredMemberCount}',
                              unit: '人',
                            ),
                            InsuranceMetric(
                              icon: RemixIcons.calendar_fill,
                              label: '年度保费',
                              value: insuranceDisplayMoneyLabel(
                                state.annualPremium,
                              ),
                            ),
                          ],
                          showDividers: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space20),
                    AppSectionHeader(
                      title: '家庭成员保障',
                      trailing: TextButton(
                        onPressed: () => context.push('/insurance/members'),
                        child: const Text('查看详情'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    if (state.overview.members.isEmpty)
                      AppSurface(
                        border: true,
                        child: AppEmptyState(
                          title: '还没有家庭成员',
                          message: '先添加成员，再为家人记录商业保险和社保信息。',
                          icon: const Icon(RemixIcons.user_heart_line),
                          layout: AppEmptyStateLayout.inline,
                          action: FilledButton.icon(
                            onPressed: () =>
                                context.push('/insurance/members/new'),
                            icon: const Icon(RemixIcons.add_line),
                            label: const Text('添加成员'),
                          ),
                        ),
                      )
                    else
                      InsuranceMemberStrip(
                        members: state.overview.members,
                        onMemberTap: (member) => context.push(
                          '/insurance/members/${member.insuredPersonId}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space16,
            AppSpacing.space8,
            AppSpacing.space16,
            AppSpacing.space12,
          ),
          child: FilledButton.icon(
            onPressed: value == null
                ? null
                : () => context.push(
                    hasMembers
                        ? '/insurance/commercial/new'
                        : '/insurance/members/new',
                  ),
            icon: const Icon(RemixIcons.add_line),
            label: Text(hasMembers ? '添加保单' : '添加成员'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(
                AppComponentTokens.controlMinHeight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
