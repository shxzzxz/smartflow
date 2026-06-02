import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/update/app_update_info.dart';
import '../../../core/update/app_update_platform.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _updatePlatform = const AppUpdatePlatform();

  AppVersionInfo? _versionInfo;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final versionInfo = await _updatePlatform.getVersionInfo();
      if (!mounted) {
        return;
      }
      setState(() => _versionInfo = versionInfo);
    } catch (_) {
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final versionInfo = _versionInfo;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space20,
            AppSpacing.space24,
            AppSpacing.space20,
            AppSpacing.space24,
          ),
          children: [
            Text('我的', style: context.appTextStyles.pageTitle),
            const SizedBox(height: AppSpacing.space20),
            AppSurface(
              child: Column(
                children: [
                  _ProfileActionRow(
                    icon: RemixIcons.apps_2_line,
                    label: '分类管理',
                    description: '维护收入与支出分类',
                    onTap: () => context.push('/category'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.space16,
                    ),
                    child: Divider(height: 1),
                  ),
                  _ProfileActionRow(
                    icon: RemixIcons.wallet_3_line,
                    label: '账户管理',
                    description: '管理资产与负债账户',
                    onTap: () => context.go('/account'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.space16,
                    ),
                    child: Divider(height: 1),
                  ),
                  _ProfileActionRow(
                    icon: RemixIcons.book_open_line,
                    label: '使用说明',
                    description: '分期方式 / 计息方式 / 关键指标释义',
                    onTap: () => context.push('/profile/installment-guide'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.space16,
                    ),
                    child: Divider(height: 1),
                  ),
                  _ProfileActionRow(
                    icon: RemixIcons.download_cloud_2_line,
                    label: '软件版本',
                    description:
                        versionInfo == null
                            ? '正在读取当前版本'
                            : versionInfo.versionName,
                    onTap: () => context.push('/profile/software-version'),
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

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space14,
        ),
        child: Row(
          children: [
            Container(
              width: AppSpacing.space48 - AppSpacing.space8,
              height: AppSpacing.space48 - AppSpacing.space8,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colors.primary, size: 22),
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.appTextStyles.formValue),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    description,
                    style: context.appTextStyles.listSupporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(RemixIcons.arrow_right_s_line, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
