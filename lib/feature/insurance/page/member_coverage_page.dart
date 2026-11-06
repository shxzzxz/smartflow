import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/insurance/insurance_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_list_divider.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import '../../../design_system/widget/app_section_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../presentation/insurance_presentation.dart';
import '../view_model/member_coverage_view_model.dart';
import '../widget/insurance/insurance_category_icon.dart';
import '../widget/insurance/insurance_metric_strip.dart';
import '../widget/insurance/insurance_policy_tile.dart';
import '../widget/member/insurance_member_header.dart';

class MemberCoveragePage extends ConsumerWidget {
  const MemberCoveragePage({required this.insuredPersonId, super.key});

  final String insuredPersonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = memberCoverageViewModelProvider(insuredPersonId);
    final coverage = ref.watch(provider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: coverage.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(provider),
              child: const Text('加载失败，点击重试'),
            ),
          ),
          data: (value) {
            if (value == null) {
              return Column(
                children: [
                  const AppPageHeader(title: '保障详情'),
                  const Expanded(child: Center(child: Text('成员不存在'))),
                ],
              );
            }
            final socialRows = [
              for (final insurance in value.socialMedicalInsurances)
                _SocialRow(
                  id: insurance.id,
                  sourceType: InsuranceSourceType.socialMedical,
                  region: insurance.region,
                  participantType: insurance.participantType,
                  recordCount: insurance.contributionRecords.length,
                ),
              for (final insurance in value.socialPensionInsurances)
                _SocialRow(
                  id: insurance.id,
                  sourceType: InsuranceSourceType.socialPension,
                  region: insurance.region,
                  participantType: insurance.participantType,
                  recordCount: insurance.contributionRecords.length,
                ),
            ];
            return Column(
              children: [
                AppPageHeader(
                  title: '成员详情',
                  actions: [
                    AppHeaderIconButton(
                      icon: RemixIcons.edit_line,
                      tooltip: '编辑成员',
                      onPressed: () => context.push(
                        '/insurance/members/$insuredPersonId/edit',
                      ),
                    ),
                    AppPopupMenuButton(
                      tooltip: '新增保险',
                      icon: RemixIcons.add_circle_line,
                      items: [
                        AppPopupMenuAction(
                          label: '新增商业保险',
                          icon: RemixIcons.shield_check_line,
                          onPressed: () => context.push(
                            _newRoute(
                              '/insurance/commercial/new',
                              insuredPersonId,
                            ),
                          ),
                        ),
                        AppPopupMenuAction(
                          label: '新增社保医保',
                          icon: RemixIcons.hospital_line,
                          onPressed: () => context.push(
                            _newRoute(
                              '/insurance/social-medical/new',
                              insuredPersonId,
                            ),
                          ),
                        ),
                        AppPopupMenuAction(
                          label: '新增社保养老',
                          icon: RemixIcons.hand_heart_line,
                          onPressed: () => context.push(
                            _newRoute(
                              '/insurance/social-pension/new',
                              insuredPersonId,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.space16,
                      AppSpacing.space8,
                      AppSpacing.space16,
                      AppSpacing.space32,
                    ),
                    children: [
                      InsuranceMemberHeader(overview: value),
                      const SizedBox(height: AppSpacing.space12),
                      AppSurface(
                        border: true,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.space16),
                          child: InsuranceMetricStrip(
                            metrics: [
                              InsuranceMetric(
                                label: '保障中保单',
                                value:
                                    '${value.activeCommercialInsuranceCount}',
                                unit: '份',
                              ),
                              InsuranceMetric(
                                label: '保额总计',
                                value: insuranceCoverageAmountDisplayLabel(
                                  value.activeCoverageAmountTotal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space20),
                      _CoverageSection(
                        title: '关联保单',
                        trailing: _SectionAddButton(
                          key: const ValueKey('coverage-add-commercial'),
                          tooltip: '新增保单',
                          onPressed: () => context.push(
                            _newRoute(
                              '/insurance/commercial/new',
                              insuredPersonId,
                            ),
                          ),
                        ),
                        emptyMessage: '还没有商业保险记录',
                        children: [
                          for (
                            var index = 0;
                            index < value.commercialInsurances.length;
                            index++
                          ) ...[
                            InsurancePolicyTile(
                              insurance: value.commercialInsurances[index],
                              status: value.commercialInsurances[index]
                                  .statusAt(value.asOf),
                              onTap: () => context.push(
                                '/insurance/commercial/'
                                '${value.commercialInsurances[index].id}',
                              ),
                            ),
                            if (index < value.commercialInsurances.length - 1)
                              const AppListDivider(),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space20),
                      _CoverageSection(
                        title: '社保',
                        trailing: _SectionAddMenuButton(
                          key: const ValueKey('coverage-add-social'),
                          tooltip: '新增社保记录',
                          items: [
                            AppPopupMenuAction(
                              label: '新增社保医保',
                              icon: RemixIcons.hospital_line,
                              onPressed: () => context.push(
                                _newRoute(
                                  '/insurance/social-medical/new',
                                  insuredPersonId,
                                ),
                              ),
                            ),
                            AppPopupMenuAction(
                              label: '新增社保养老',
                              icon: RemixIcons.hand_heart_line,
                              onPressed: () => context.push(
                                _newRoute(
                                  '/insurance/social-pension/new',
                                  insuredPersonId,
                                ),
                              ),
                            ),
                          ],
                        ),
                        emptyMessage: '还没有社保记录',
                        children: [
                          for (
                            var index = 0;
                            index < socialRows.length;
                            index++
                          ) ...[
                            socialRows[index],
                            if (index < socialRows.length - 1)
                              const AppListDivider(),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _newRoute(String path, String personId) {
    return Uri(path: path, queryParameters: {'personId': personId}).toString();
  }
}

class _SectionAddButton extends StatelessWidget {
  const _SectionAddButton({
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(RemixIcons.add_line, size: AppSpacing.space16),
        label: const Text('新增'),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.primary,
          minimumSize: const Size(0, AppSpacing.space48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space8),
        ),
      ),
    );
  }
}

class _SectionAddMenuButton extends StatelessWidget {
  const _SectionAddMenuButton({
    required this.tooltip,
    required this.items,
    super.key,
  });

  final String tooltip;
  final List<AppPopupMenuEntry> items;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: const MenuStyle(
        minimumSize: WidgetStatePropertyAll(
          Size(AppComponentTokens.menuMinWidth, 0),
        ),
      ),
      menuChildren: items.cast<Widget>(),
      builder: (context, controller, child) {
        return _SectionAddButton(
          tooltip: tooltip,
          onPressed: controller.isOpen ? controller.close : controller.open,
        );
      },
    );
  }
}

class _CoverageSection extends StatelessWidget {
  const _CoverageSection({
    required this.title,
    required this.emptyMessage,
    required this.children,
    this.trailing,
  });

  final String title;
  final String emptyMessage;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(title: title, trailing: trailing),
        const SizedBox(height: AppSpacing.space8),
        AppSurface(
          border: true,
          child: children.isEmpty
              ? AppEmptyState(
                  title: emptyMessage,
                  layout: AppEmptyStateLayout.inline,
                )
              : Column(children: children),
        ),
      ],
    );
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow({
    required this.id,
    required this.sourceType,
    required this.region,
    required this.participantType,
    required this.recordCount,
  });

  final String id;
  final InsuranceSourceType sourceType;
  final String region;
  final SocialParticipantType participantType;
  final int recordCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('coverage-${_routeSegment(sourceType)}-$id'),
      onTap: () => context.push('/insurance/${_routeSegment(sourceType)}/$id'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Row(
          children: [
            InsuranceCategoryIcon.social(sourceType: sourceType, size: 40),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sourceType.label,
                    style: context.appTextStyles.listTitle,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    '$region · ${participantType.label}',
                    style: context.appTextStyles.listSupporting,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    '$recordCount 条缴费记录',
                    style: context.appTextStyles.listSupporting,
                  ),
                ],
              ),
            ),
            Icon(
              RemixIcons.arrow_right_s_line,
              size: AppSpacing.space20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _routeSegment(InsuranceSourceType type) {
    return switch (type) {
      InsuranceSourceType.socialMedical => 'social-medical',
      InsuranceSourceType.socialPension => 'social-pension',
      InsuranceSourceType.commercial => 'commercial',
    };
  }
}
