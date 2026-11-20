import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/theme/app_chrome_theme.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_bottom_navigation_bar.dart';
import '../../../design_system/widget/app_page_background.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_page_header_background_scope.dart';
import '../../../design_system/widget/app_sliding_segmented_control.dart';

class NavigationAppearancePreview extends StatefulWidget {
  const NavigationAppearancePreview({
    required this.style,
    required this.showLabels,
    required this.glass,
    super.key,
  });

  final BottomNavigationStyle style;
  final bool showLabels;
  final AppGlassSettings glass;

  @override
  State<NavigationAppearancePreview> createState() =>
      _NavigationAppearancePreviewState();
}

class _NavigationAppearancePreviewState
    extends State<NavigationAppearancePreview> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => _PreviewFrame(
    appearance: AppChromeTheme.of(
      context,
    ).copyWith(navigationGlass: widget.glass),
    overlayBody: true,
    child: AppBottomNavigationBar(
      style: widget.style,
      showLabels: widget.showLabels,
      selectedIndex: _selected,
      onDestinationSelected: (index) => setState(() => _selected = index),
    ),
  );
}

class HeaderAppearancePreview extends StatefulWidget {
  const HeaderAppearancePreview({required this.appearance, super.key});

  final AppAppearanceSettings appearance;

  @override
  State<HeaderAppearancePreview> createState() =>
      _HeaderAppearancePreviewState();
}

class _HeaderAppearancePreviewState extends State<HeaderAppearancePreview> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => _PreviewFrame(
    appearance: AppChromeTheme.of(context).copyWith(
      headerStyle: widget.appearance.headerStyle,
      headerBackgroundGlass: widget.appearance.headerBackgroundGlass,
      headerControlGlass: widget.appearance.headerControlGlass,
    ),
    overlayBody: false,
    child: Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space24),
      child: AppPageHeaderBackgroundScope(
        topInset: AppSpacing.space24,
        child: AppPageHeader.custom(
          showBackButton: false,
          leading: AppHeaderIconButton(
            icon: RemixIcons.arrow_left_s_line,
            tooltip: '预览返回按钮',
            onPressed: () {},
          ),
          titleContent: AppSlidingSegmentedControl<int>(
            variant: AppSegmentedControlVariant.header,
            segments: const [
              AppSegment(value: 0, label: '概览'),
              AppSegment(value: 1, label: '明细'),
            ],
            selected: _selected,
            onChanged: (index) => setState(() => _selected = index),
          ),
          actions: [
            AppHeaderIconButton(
              icon: RemixIcons.add_line,
              tooltip: '预览新增按钮',
              onPressed: () {},
            ),
            AppHeaderIconButton(
              icon: RemixIcons.more_2_fill,
              tooltip: '预览更多按钮',
              onPressed: () {},
            ),
          ],
        ),
      ),
    ),
  );
}

class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({
    required this.appearance,
    required this.overlayBody,
    required this.child,
  });

  final AppChromeTheme appearance;
  final bool overlayBody;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        extensions: [
          ...theme.extensions.values.where(
            (extension) => extension is! AppChromeTheme,
          ),
          appearance,
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.radiusXl),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.radiusXl),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                height: AppComponentTokens.chromeAppearancePreviewHeight,
                child: AppPageBackground(
                  child: overlayBody
                      ? Stack(
                          children: [
                            const Positioned.fill(child: _PreviewContent()),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: child,
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            child,
                            const Expanded(child: _PreviewContent()),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpacing.space16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('本月概览', style: context.appTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.space12),
        for (final label in ['日常支出', '交通出行', '购物消费']) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.space16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(
                alpha: AppComponentTokens.selectedContainerOpacity,
              ),
              borderRadius: BorderRadius.circular(AppRadius.radiusLg),
            ),
            child: Text(label, style: context.appTextStyles.listSupporting),
          ),
          const SizedBox(height: AppSpacing.space8),
        ],
      ],
    ),
  );
}
