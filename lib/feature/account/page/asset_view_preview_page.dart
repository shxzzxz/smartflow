import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/analytics/analytics_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_scaffold.dart';
import '../../../design_system/widget/app_sliding_segmented_control.dart';
import '../presentation/asset_view_presentation.dart';
import '../view_model/asset_page_view_model.dart';
import '../widget/asset_account_sections.dart';
import '../widget/asset_summary_card.dart';

class AssetViewPreviewPage extends ConsumerStatefulWidget {
  const AssetViewPreviewPage({
    required this.view,
    this.initiallyHideBalances = false,
    super.key,
  });
  final AssetView view;
  final bool initiallyHideBalances;
  @override
  ConsumerState<AssetViewPreviewPage> createState() =>
      _AssetViewPreviewPageState();
}

class _AssetViewPreviewPageState extends ConsumerState<AssetViewPreviewPage> {
  AssetAccountFilter _filter = AssetAccountFilter.all;
  final Set<String> _collapsed = {};
  @override
  Widget build(BuildContext context) {
    final content = ref.watch(assetViewContentProvider(widget.view, _filter));
    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader.custom(
              titleContent: AppSlidingSegmentedControl<AssetAccountFilter>(
                variant: AppSegmentedControlVariant.header,
                selected: _filter,
                onChanged: (value) => setState(() => _filter = value),
                segments: [
                  for (final value in AssetAccountFilter.values)
                    AppSegment(value: value, label: value.label),
                ],
              ),
            ),
            Expanded(
              child: content.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, trace) => Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.read(assetPageViewModelProvider.notifier).retry(),
                    child: const Text('预览加载失败，点击重试'),
                  ),
                ),
                data: (content) => ListView(
                  padding: const EdgeInsets.all(AppSpacing.space16),
                  children: [
                    Text(
                      '预览 · ${widget.view.name}',
                      style: context.appTextStyles.groupTitle,
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    AssetSummaryCard(
                      statistics: content.statistics,
                      hideBalances: widget.initiallyHideBalances,
                    ),
                    for (final section in content.layout.sections) ...[
                      const SizedBox(height: AppSpacing.space20),
                      AccountSectionCard(
                        section: section,
                        hideBalances: widget.initiallyHideBalances,
                        collapsed: _collapsed.contains(section.id),
                        onToggleCollapsed: () => setState(() {
                          _collapsed.contains(section.id)
                              ? _collapsed.remove(section.id)
                              : _collapsed.add(section.id);
                        }),
                      ),
                    ],
                    if (content.layout.isEmpty)
                      const AppEmptyState(title: '没有匹配的账户'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
