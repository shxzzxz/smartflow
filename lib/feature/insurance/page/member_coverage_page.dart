import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/insurance/insurance_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_choice_chip_group.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_list_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_scaffold.dart';
import '../../../design_system/widget/app_sliding_segmented_control.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../design_system/widget/app_tab_swipe_region.dart';
import '../presentation/insurance_presentation.dart';
import '../view_model/member_coverage_view_model.dart';
import '../widget/insurance/insurance_category_icon.dart';
import '../widget/insurance/insurance_metric_strip.dart';
import '../widget/insurance/insurance_policy_tile.dart';
import '../widget/member/insurance_member_header.dart';

class MemberCoveragePage extends ConsumerStatefulWidget {
  const MemberCoveragePage({required this.insuredPersonId, super.key});

  final String insuredPersonId;

  @override
  ConsumerState<MemberCoveragePage> createState() => _MemberCoveragePageState();
}

class _MemberCoveragePageState extends ConsumerState<MemberCoveragePage> {
  InsuranceSourceType _selectedSource = InsuranceSourceType.commercial;
  CommercialInsuranceCategory? _selectedCommercialCategory;
  SocialInsuranceType? _selectedSocialType;

  @override
  Widget build(BuildContext context) {
    final provider = memberCoverageViewModelProvider(widget.insuredPersonId);
    final coverage = ref.watch(provider);
    final member = coverage.asData?.value;
    return AppScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader.custom(
              titleContent: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: AppSlidingSegmentedControl<InsuranceSourceType>(
                  variant: AppSegmentedControlVariant.header,
                  segments: [
                    for (final source in InsuranceSourceType.values)
                      AppSegment(value: source, label: source.label),
                  ],
                  selected: _selectedSource,
                  onChanged: _selectSource,
                ),
              ),
              actions: [
                AppHeaderIconButton(
                  icon: RemixIcons.edit_line,
                  tooltip: '编辑成员',
                  onPressed: member == null
                      ? null
                      : () => context.push(
                          '/insurance/members/${widget.insuredPersonId}/edit',
                        ),
                ),
                AppHeaderIconButton(
                  key: const ValueKey('coverage-add-insurance'),
                  tooltip: '新增${_selectedSource.label}',
                  icon: RemixIcons.add_circle_line,
                  onPressed: member == null
                      ? null
                      : () => context.push(_newRoute()),
                ),
              ],
            ),
            Expanded(
              child: coverage.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(provider),
                    child: const Text('加载失败，点击重试'),
                  ),
                ),
                data: (value) => value == null
                    ? const Center(child: Text('成员不存在'))
                    : AppTabSwipeRegion<InsuranceSourceType>(
                        values: InsuranceSourceType.values,
                        selected: _selectedSource,
                        onChanged: _selectSource,
                        child: _buildContent(value),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(MemberCoverageOverview overview) {
    final commercial = _selectedSource == InsuranceSourceType.commercial;
    final rows = commercial
        ? <Widget>[
            for (final insurance in overview.commercialInsurances)
              if (_selectedCommercialCategory == null ||
                  insurance.category == _selectedCommercialCategory)
                InsurancePolicyTile(
                  insurance: insurance,
                  status: insurance.statusAt(overview.asOf),
                  onTap: () =>
                      context.push('/insurance/commercial/${insurance.id}'),
                ),
          ]
        : <Widget>[
            for (final insurance in overview.socialInsurances)
              if (_selectedSocialType == null ||
                  insurance.insuranceType == _selectedSocialType)
                _SocialRow(insurance: insurance),
          ];
    final filtered = commercial
        ? _selectedCommercialCategory != null
        : _selectedSocialType != null;
    final emptyMessage = commercial
        ? (filtered ? '该分类下还没有商业保险记录' : '还没有商业保险记录')
        : (filtered ? '该分类下还没有社保记录' : '还没有社保记录');

    return ListView(
      key: PageStorageKey(
        'member-coverage-${widget.insuredPersonId}-${_selectedSource.name}',
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space8,
        AppSpacing.space16,
        AppSpacing.space32,
      ),
      children: [
        InsuranceMemberHeader(overview: overview),
        const SizedBox(height: AppSpacing.space12),
        AppSurface(
          border: true,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: InsuranceMetricStrip(
              metrics: [
                InsuranceMetric(
                  label: '保障中保单',
                  value: '${overview.activeCommercialInsuranceCount}',
                  unit: '份',
                ),
                InsuranceMetric(
                  label: '保额总计',
                  value: insuranceCoverageAmountDisplayLabel(
                    overview.activeCoverageAmountTotal,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.space20),
        if (commercial)
          AppChoiceChipGroup<CommercialInsuranceCategory?>(
            size: AppChoiceChipSize.compact,
            options: [
              const AppChoiceChipOption(value: null, label: '全部'),
              for (final category in const [
                CommercialInsuranceCategory.medical,
                CommercialInsuranceCategory.accident,
                CommercialInsuranceCategory.criticalIllness,
                CommercialInsuranceCategory.life,
                CommercialInsuranceCategory.other,
              ])
                AppChoiceChipOption(
                  value: category,
                  label: insuranceCategoryDisplayLabel(category),
                ),
            ],
            selected: _selectedCommercialCategory,
            onChanged: (value) =>
                setState(() => _selectedCommercialCategory = value),
          )
        else
          AppChoiceChipGroup<SocialInsuranceType?>(
            size: AppChoiceChipSize.compact,
            options: [
              const AppChoiceChipOption(value: null, label: '全部'),
              for (final type in SocialInsuranceType.values)
                AppChoiceChipOption(value: type, label: type.label),
            ],
            selected: _selectedSocialType,
            onChanged: (value) => setState(() => _selectedSocialType = value),
          ),
        const SizedBox(height: AppSpacing.space12),
        if (rows.isEmpty)
          AppSurface(
            border: true,
            child: AppEmptyState(
              title: emptyMessage,
              layout: AppEmptyStateLayout.inline,
            ),
          )
        else
          AppListSection(border: true, children: rows),
      ],
    );
  }

  void _selectSource(InsuranceSourceType source) {
    setState(() => _selectedSource = source);
  }

  String _newRoute() {
    final path = switch (_selectedSource) {
      InsuranceSourceType.commercial => '/insurance/commercial/new',
      InsuranceSourceType.social => '/insurance/social/new',
    };
    return Uri(
      path: path,
      queryParameters: {'personId': widget.insuredPersonId},
    ).toString();
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow({required this.insurance});

  final SocialInsurance insurance;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('coverage-social-${insurance.id}'),
      onTap: () => context.push('/insurance/social/${insurance.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Row(
          children: [
            InsuranceCategoryIcon.social(
              insuranceType: insurance.insuranceType,
              size: 40,
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '社保${insurance.insuranceType.label}',
                    style: context.appTextStyles.listTitle,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    '${insurance.region} · ${insurance.participantType.label}',
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
}
