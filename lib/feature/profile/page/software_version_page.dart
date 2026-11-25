import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/app_update_providers.dart';
import '../../../core/update/app_update_channel.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../design_system/widget/app_scaffold.dart';

class SoftwareVersionPage extends ConsumerStatefulWidget {
  const SoftwareVersionPage({super.key});

  @override
  ConsumerState<SoftwareVersionPage> createState() =>
      _SoftwareVersionPageState();
}

class _SoftwareVersionPageState extends ConsumerState<SoftwareVersionPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(appUpdateControllerProvider.notifier).initialize());
      }
    });
  }

  String _statusLabel(AppUpdateState state) {
    return switch (state.downloadStatus) {
      AppUpdateDownloadStatus.downloading => '正在后台下载',
      AppUpdateDownloadStatus.readyToInstall => '正在准备安装',
      AppUpdateDownloadStatus.installing => '正在打开安装界面',
      AppUpdateDownloadStatus.downloaded => '新版本已下载',
      AppUpdateDownloadStatus.idle =>
        state.isChecking
            ? '正在检查更新'
            : state.hasCheckedLatest
            ? '当前已是最新版本'
            : '当前软件版本',
    };
  }

  String _versionLabel(AppUpdateState state) {
    final version = state.versionInfo;
    if (version == null) return '正在读取当前版本';
    if (version.buildNumber <= 0) return version.versionName;
    return '${version.versionName} (${version.buildNumber})';
  }

  String _actionLabel(AppUpdateState state) {
    if (state.isChecking) return '正在检查';
    return switch (state.downloadStatus) {
      AppUpdateDownloadStatus.downloading => '下载中',
      AppUpdateDownloadStatus.installing => '正在安装',
      AppUpdateDownloadStatus.readyToInstall ||
      AppUpdateDownloadStatus.downloaded => '立即安装',
      AppUpdateDownloadStatus.idle => '检查更新',
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appUpdateControllerProvider);
    final controller = ref.read(appUpdateControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    final progress = state.downloadProgress?.fraction;

    return AppScaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '软件版本'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space20,
                  AppSpacing.space24,
                  AppSpacing.space20,
                  AppSpacing.space28,
                ),
                children: [
                  const SizedBox(height: AppSpacing.space16),
                  Center(
                    child: _UpdateHeroIcon(
                      color: colors.primary,
                      surfaceColor: colors.primaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space28),
                  Text(
                    _statusLabel(state),
                    textAlign: TextAlign.center,
                    style: textStyles.sectionTitleStrong,
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  Text(
                    '${_versionLabel(state)} · ${state.channel.shortName} 渠道',
                    textAlign: TextAlign.center,
                    style: textStyles.detailValue.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (state.downloadStatus ==
                      AppUpdateDownloadStatus.downloading) ...[
                    const SizedBox(height: AppSpacing.space16),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: AppSpacing.space8),
                    Text(
                      progress == null
                          ? '正在下载，可以继续使用应用'
                          : '已下载 ${(progress * 100).round()}%，可以继续使用应用',
                      textAlign: TextAlign.center,
                      style: textStyles.listSupporting,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.space24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: state.isBusy || !state.isInitialized
                          ? null
                          : () => unawaited(
                              state.canInstall
                                  ? controller.installDownloadedUpdate()
                                  : controller.checkForUpdate(),
                            ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(AppSpacing.space48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppRadius.radiusMd,
                          ),
                        ),
                      ),
                      child: Text(_actionLabel(state)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space32),
                  Text('更新渠道', style: textStyles.sectionTitleStrong),
                  const SizedBox(height: AppSpacing.space12),
                  AppSurface(
                    border: true,
                    child: Column(
                      children: [
                        for (final channel in AppUpdateChannel.values) ...[
                          _UpdateChannelRow(
                            channel: channel,
                            selected: channel == state.channel,
                            onSelected: state.isBusy || !state.isInitialized
                                ? null
                                : () =>
                                      unawaited(controller.setChannel(channel)),
                          ),
                          if (channel != AppUpdateChannel.values.last)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.space16,
                              ),
                              child: Divider(height: 1),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        RemixIcons.information_line,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.space8),
                      Text('切换渠道后需重新检查更新', style: textStyles.detailLabel),
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
}

class _UpdateHeroIcon extends StatelessWidget {
  const _UpdateHeroIcon({required this.color, required this.surfaceColor});

  final Color color;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: surfaceColor.withValues(alpha: 0.46),
              shape: BoxShape.circle,
            ),
          ),
          Icon(Icons.arrow_upward_rounded, size: 56, color: color),
          Positioned(
            left: AppSpacing.space12,
            top: AppSpacing.space48 - AppSpacing.space4,
            child: _UpdateOrbitDot(color: color, outlined: true),
          ),
          Positioned(
            right: AppSpacing.space10,
            top: AppSpacing.space28,
            child: _UpdateOrbitDot(color: color, outlined: true),
          ),
          Positioned(
            right: AppSpacing.space24,
            bottom: AppSpacing.space32,
            child: _UpdateOrbitDot(color: color),
          ),
        ],
      ),
    );
  }
}

class _UpdateOrbitDot extends StatelessWidget {
  const _UpdateOrbitDot({required this.color, this.outlined = false});

  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: outlined ? AppSpacing.space12 : AppSpacing.space10,
      height: outlined ? AppSpacing.space12 : AppSpacing.space10,
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.62),
        shape: BoxShape.circle,
        border: outlined
            ? Border.all(color: color.withValues(alpha: 0.62))
            : null,
      ),
    );
  }
}

class _UpdateChannelRow extends StatelessWidget {
  const _UpdateChannelRow({
    required this.channel,
    required this.selected,
    required this.onSelected,
  });

  final AppUpdateChannel channel;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.appTextStyles;

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(AppRadius.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space16,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(channel.displayName, style: textStyles.listTitle),
                  const SizedBox(height: AppSpacing.space6),
                  Text(
                    channel.userFacingDescription,
                    style: textStyles.detailLabel,
                  ),
                ],
              ),
            ),
            _ChannelSelectionIndicator(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _ChannelSelectionIndicator extends StatelessWidget {
  const _ChannelSelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: AppSpacing.space24,
      height: AppSpacing.space24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? colors.primary : colors.outline,
          width: selected ? 2 : 1.5,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: AppSpacing.space12,
                height: AppSpacing.space12,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

extension on AppUpdateChannel {
  String get shortName {
    return switch (this) {
      AppUpdateChannel.stable => 'Stable',
      AppUpdateChannel.beta => 'Beta',
      AppUpdateChannel.dev => 'Dev',
    };
  }

  String get displayName {
    return switch (this) {
      AppUpdateChannel.stable => 'Stable（稳定版）',
      AppUpdateChannel.beta => 'Beta（测试版）',
      AppUpdateChannel.dev => 'Dev（开发版）',
    };
  }

  String get userFacingDescription {
    return switch (this) {
      AppUpdateChannel.stable => '功能稳定，推荐使用',
      AppUpdateChannel.beta => '体验新功能，可能存在问题',
      AppUpdateChannel.dev => '最新开发内容，可能不稳定',
    };
  }
}
