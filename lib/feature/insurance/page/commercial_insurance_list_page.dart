import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/insurance/insurance_query_api.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_choice_chip_group.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_list_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../presentation/insurance_presentation.dart';
import '../view_model/commercial_insurance_list_view_model.dart';
import '../widget/insurance/insurance_policy_tile.dart';

class CommercialInsuranceListPage extends ConsumerStatefulWidget {
  const CommercialInsuranceListPage({super.key});

  @override
  ConsumerState<CommercialInsuranceListPage> createState() =>
      _CommercialInsuranceListPageState();
}

class _CommercialInsuranceListPageState
    extends ConsumerState<CommercialInsuranceListPage> {
  CommercialInsuranceCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final policies = ref.watch(commercialInsuranceListViewModelProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '保单管理',
              actions: [
                AppHeaderIconButton(
                  icon: RemixIcons.add_line,
                  tooltip: '新增保单',
                  onPressed: () => context.push('/insurance/commercial/new'),
                ),
              ],
            ),
            Expanded(
              child: policies.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(
                      commercialInsuranceListViewModelProvider,
                    ),
                    child: const Text('加载失败，点击重试'),
                  ),
                ),
                data: (items) => _buildContent(items),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<CommercialInsuranceListItem> items) {
    if (items.isEmpty) {
      return AppEmptyState(
        title: '还没有商业保单',
        message: '添加保单后，可在这里按险种筛选和查看保障状态。',
        icon: const Icon(RemixIcons.shield_check_line),
        action: FilledButton.icon(
          onPressed: () => context.push('/insurance/commercial/new'),
          icon: const Icon(RemixIcons.add_line),
          label: const Text('添加保单'),
        ),
      );
    }

    final categories = CommercialInsuranceCategory.values
        .where(
          (category) =>
              items.any((item) => item.insurance.category == category),
        )
        .toList(growable: false);
    final visibleItems = _selectedCategory == null
        ? items
        : items
              .where((item) => item.insurance.category == _selectedCategory)
              .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space8,
        AppSpacing.space16,
        AppSpacing.space32,
      ),
      children: [
        AppChoiceChipGroup<CommercialInsuranceCategory?>(
          options: [
            AppChoiceChipOption<CommercialInsuranceCategory?>(
              value: null,
              label: '全部 (${items.length})',
            ),
            for (final category in categories)
              AppChoiceChipOption<CommercialInsuranceCategory?>(
                value: category,
                label:
                    '${insuranceCategoryDisplayLabel(category)} '
                    '(${items.where((item) => item.insurance.category == category).length})',
              ),
          ],
          selected: _selectedCategory,
          onChanged: (value) => setState(() => _selectedCategory = value),
        ),
        const SizedBox(height: AppSpacing.space16),
        AppListSection(
          border: true,
          children: [
            for (final policy in visibleItems)
              InsurancePolicyTile(
                insurance: policy.insurance,
                status: policy.status,
                insuredPeopleLabel: policy.insuredPeopleLabel,
                showInsuredPeople: true,
                onTap: () => context.push(
                  '/insurance/commercial/${policy.insurance.id}',
                ),
              ),
          ],
        ),
      ],
    );
  }
}
