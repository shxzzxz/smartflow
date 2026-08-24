import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/provider.dart';
import '../../../core/update/app_update_channel.dart';
import '../../../core/update/app_update_info.dart';
import '../../../core/update/app_update_platform.dart';
import '../../../core/update/app_update_service.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';

final _logger = Logger('feature.profile.software_version');

class SoftwareVersionPage extends ConsumerStatefulWidget {
  const SoftwareVersionPage({super.key});

  @override
  ConsumerState<SoftwareVersionPage> createState() =>
      _SoftwareVersionPageState();
}

class _SoftwareVersionPageState extends ConsumerState<SoftwareVersionPage> {
  static const _manifestUrlOverride = String.fromEnvironment(
    'SMARTFLOW_UPDATE_URL',
    defaultValue: '',
  );
  static const _manifestBaseUrl = String.fromEnvironment(
    'SMARTFLOW_UPDATE_BASE_URL',
    defaultValue: AppUpdateService.defaultManifestBaseUrl,
  );
  static final _defaultUpdateChannel = AppUpdateChannel.fromCode(
    const String.fromEnvironment(
      'SMARTFLOW_UPDATE_CHANNEL',
      defaultValue: 'beta',
    ),
  );

  final _updatePlatform = const AppUpdatePlatform();

  AppVersionInfo? _versionInfo;
  AppUpdateChannel _updateChannel = _defaultUpdateChannel;
  bool _isCheckingUpdate = false;
  bool _hasCheckedLatest = false;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
    _loadUpdateChannel();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final versionInfo = await _updatePlatform.getVersionInfo();
      if (!mounted) {
        return;
      }
      setState(() => _versionInfo = versionInfo);
    } catch (error, stackTrace) {
      _logger.warning('Failed to load app version info.', error, stackTrace);
      if (!mounted) {
        return;
      }
      setState(
        () =>
            _versionInfo = const AppVersionInfo(
              versionName: '未知版本',
              buildNumber: 0,
            ),
      );
    }
  }

  Future<void> _loadUpdateChannel() async {
    try {
      final code =
          await ref.read(updateChannelStoreProvider).readUpdateChannel();
      if (!mounted || code == null) {
        return;
      }
      setState(() => _updateChannel = AppUpdateChannel.fromCode(code));
    } catch (error, stackTrace) {
      _logger.warning('Failed to load update channel.', error, stackTrace);
      // Keep the compile-time default channel when local metadata is unreadable.
    }
  }

  Future<void> _setUpdateChannel(AppUpdateChannel channel) async {
    if (channel == _updateChannel) {
      return;
    }

    setState(() {
      _updateChannel = channel;
      _hasCheckedLatest = false;
    });
    await ref.read(updateChannelStoreProvider).saveUpdateChannel(channel.code);
  }

  Future<void> _checkForUpdate() async {
    if (_isCheckingUpdate) {
      return;
    }

    var versionInfo = _versionInfo;
    if (versionInfo == null || versionInfo.buildNumber <= 0) {
      await _loadVersionInfo();
      versionInfo = _versionInfo;
    }

    if (!mounted) {
      return;
    }

    if (versionInfo == null || versionInfo.buildNumber <= 0) {
      _showMessage('暂时无法读取当前版本');
      return;
    }

    setState(() {
      _isCheckingUpdate = true;
      _hasCheckedLatest = false;
    });
    try {
      final updateService = _createUpdateService();
      final supportedAbis = await _updatePlatform.getSupportedAbis();
      if (!mounted) {
        return;
      }

      final updateInfo = await updateService.checkForUpdate(
        currentAndroidVersionCode: versionInfo.buildNumber,
        supportedAbis: supportedAbis,
      );
      if (!mounted) {
        return;
      }

      if (updateInfo == null) {
        setState(() => _hasCheckedLatest = true);
        _showMessage('当前已是最新版本');
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: !updateInfo.required,
        builder:
            (context) => _AppUpdateDialog(
              updateInfo: updateInfo,
              supportedAbis: supportedAbis,
              updateService: updateService,
              updatePlatform: _updatePlatform,
            ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('检查更新失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  AppUpdateService _createUpdateService() {
    final override = _manifestUrlOverride.trim();
    if (override.isNotEmpty) {
      return AppUpdateService(
        manifestUri: Uri.parse(override),
        expectedChannel: _updateChannel,
      );
    }

    return AppUpdateService(
      manifestUri: AppUpdateService.manifestUriForChannel(
        _updateChannel,
        baseUrl: _manifestBaseUrl,
      ),
      expectedChannel: _updateChannel,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String get _statusLabel {
    if (_isCheckingUpdate) {
      return '正在检查更新';
    }
    if (_hasCheckedLatest) {
      return '当前已是最新版本';
    }
    return '当前软件版本';
  }

  String get _versionLabel {
    final versionInfo = _versionInfo;
    if (versionInfo == null) {
      return '正在读取当前版本';
    }
    if (versionInfo.buildNumber <= 0) {
      return versionInfo.versionName;
    }
    return '${versionInfo.versionName} (${versionInfo.buildNumber})';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;

    return Scaffold(
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
                    _statusLabel,
                    textAlign: TextAlign.center,
                    style: textStyles.sectionTitleStrong,
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  Text(
                    '$_versionLabel · ${_updateChannel.shortName} 渠道',
                    textAlign: TextAlign.center,
                    style: textStyles.detailValue.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isCheckingUpdate ? null : _checkForUpdate,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(AppSpacing.space48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppRadius.radiusMd,
                          ),
                        ),
                      ),
                      child: Text(_isCheckingUpdate ? '正在检查' : '检查更新'),
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
                            selected: channel == _updateChannel,
                            onSelected: () => _setUpdateChannel(channel),
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
        border:
            outlined ? Border.all(color: color.withValues(alpha: 0.62)) : null,
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
  final VoidCallback onSelected;

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
      child:
          selected
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

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({
    required this.updateInfo,
    required this.supportedAbis,
    required this.updateService,
    required this.updatePlatform,
  });

  final AppUpdateInfo updateInfo;
  final List<String> supportedAbis;
  final AppUpdateService updateService;
  final AppUpdatePlatform updatePlatform;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  bool _isDownloading = false;
  double? _progress;

  Future<void> _downloadAndInstall() async {
    if (_isDownloading) {
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0;
    });

    var downloadCompleted = false;
    try {
      final package = widget.updateInfo.resolvePackage(widget.supportedAbis);
      if (package == null) {
        return;
      }
      final download = await widget.updatePlatform.downloadApk(
        package,
        versionName: widget.updateInfo.versionName,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() => _progress = progress.fraction);
        },
      );
      try {
        await widget.updateService.verifyDownloadedApk(download.file, package);
      } catch (_) {
        try {
          await widget.updatePlatform.removeApkDownload(download.downloadId);
        } catch (_) {
          // The invalid package should not hide the verification failure.
        }
        rethrow;
      }
      downloadCompleted = true;
      await widget.updatePlatform.installApk(download.file.path);
      if (mounted && !widget.updateInfo.required) {
        Navigator.of(context).pop();
      }
    } on PlatformException catch (error) {
      if (downloadCompleted) {
        _logger.warning('APK install failed.', error);
      }
      if (!mounted) {
        return;
      }
      final message =
          error.code == 'downloadFailed' || !downloadCompleted
              ? '下载失败，请稍后重试'
              : '安装失败，请稍后重试';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (error, stackTrace) {
      _logger.warning(
        'APK download flow failed unexpectedly.',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(downloadCompleted ? '安装失败，请稍后重试' : '下载失败，请稍后重试'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    final progress = _progress;
    final package = widget.updateInfo.resolvePackage(widget.supportedAbis);

    return AlertDialog(
      title: Text('发现新版本 ${widget.updateInfo.versionName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.updateInfo.notes.isNotEmpty)
            Text(widget.updateInfo.notes, style: textStyles.detailValue),
          if (widget.updateInfo.notes.isEmpty)
            Text('有新的内测版本可用。', style: textStyles.detailValue),
          const SizedBox(height: AppSpacing.space12),
          if (package != null)
            Text(
              '安装包：${package.abi}',
              style: textStyles.listSupporting.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          if (package == null)
            Text(
              '当前设备暂无可用安装包',
              style: textStyles.listSupporting.copyWith(color: colors.error),
            ),
          if (_isDownloading) ...[
            const SizedBox(height: AppSpacing.space16),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: AppSpacing.space8),
            Text(
              progress == null ? '正在下载' : '已下载 ${(progress * 100).round()}%',
              style: textStyles.listSupporting.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              '切换到其他应用后仍会继续下载',
              style: textStyles.listSupporting.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!widget.updateInfo.required)
          TextButton(
            onPressed:
                _isDownloading ? null : () => Navigator.of(context).pop(),
            child: const Text('稍后'),
          ),
        FilledButton(
          onPressed:
              _isDownloading || package == null ? null : _downloadAndInstall,
          child: Text(_isDownloading ? '下载中' : '立即更新'),
        ),
      ],
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
