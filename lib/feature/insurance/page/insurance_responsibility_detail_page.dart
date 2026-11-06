import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_list_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_section_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../presentation/insurance_presentation.dart';
import '../view_model/commercial_insurance_detail_view_model.dart';
import '../widget/insurance/insurance_key_value_row.dart';

class InsuranceResponsibilityDetailPage extends ConsumerWidget {
  const InsuranceResponsibilityDetailPage({
    required this.insuranceId,
    required this.responsibilityId,
    super.key,
  });

  final String insuranceId;
  final String responsibilityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = commercialInsuranceDetailViewModelProvider(insuranceId);
    final detail = ref.watch(provider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(provider),
              child: const Text('加载失败，点击重试'),
            ),
          ),
          data: (value) {
            if (value == null) {
              return const Column(
                children: [
                  AppPageHeader(title: '保障责任详情'),
                  Expanded(child: Center(child: Text('保单不存在'))),
                ],
              );
            }
            final responsibility = value.insurance.responsibilities
                .where((item) => item.id == responsibilityId)
                .firstOrNull;
            if (responsibility == null) {
              return Column(
                children: [
                  AppPageHeader(
                    title: '保障责任详情',
                    subtitle: value.insurance.name,
                  ),
                  const Expanded(child: Center(child: Text('保障责任不存在'))),
                ],
              );
            }
            return Column(
              children: [
                AppPageHeader(title: '保障责任详情', subtitle: value.insurance.name),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.space16,
                      AppSpacing.space8,
                      AppSpacing.space16,
                      AppSpacing.space32,
                    ),
                    children: [
                      AppSectionHeader(
                        title: responsibility.name,
                        subtitle: insuranceResponsibilityKindLabel(
                          responsibility.kind,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space8),
                      if (responsibility.points.isEmpty)
                        AppSurface(
                          border: true,
                          child: const AppEmptyState(
                            title: '暂无责任要点',
                            message: '可在商业保险编辑页补充责任要点。',
                            layout: AppEmptyStateLayout.inline,
                            icon: Icon(RemixIcons.file_list_3_line),
                          ),
                        )
                      else
                        AppListSection(
                          border: true,
                          children: [
                            for (final point in responsibility.points)
                              InsuranceKeyValueRow(
                                label: point.label,
                                value: point.value,
                              ),
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
}
