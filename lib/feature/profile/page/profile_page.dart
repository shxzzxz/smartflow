import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/update/app_update_info.dart';
import '../../../core/update/app_update_platform.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/list.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';

final _logger = Logger('feature.profile');

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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final versionInfo = _versionInfo;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '我的'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  AppSpacing.space8,
                  AppSpacing.space16,
                  AppSpacing.space24,
                ),
                children: [
                  _ProfileActionSection(
                    title: '账务管理',
                    actions: [
                      _ProfileActionRow(
                        icon: RemixIcons.apps_2_line,
                        label: '分类管理',
                        description: '维护收入与支出分类',
                        onTap: () => context.push('/category'),
                      ),
                      _ProfileActionRow(
                        icon: RemixIcons.wallet_3_line,
                        label: '账户管理',
                        description: '管理资产与负债账户',
                        onTap: () => context.go('/account'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  _ProfileActionSection(
                    title: '数据管理',
                    actions: [
                      _ProfileActionRow(
                        icon: RemixIcons.file_excel_2_line,
                        label: '数据导入',
                        description: '从外部账单或记账应用导入交易',
                        onTap: () => context.push('/profile/import'),
                      ),
                      _ProfileActionRow(
                        icon: RemixIcons.delete_bin_6_line,
                        label: '数据清理',
                        description: '按分类、账户、时间批量清理交易',
                        onTap: () => context.push('/profile/data-cleanup'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  _ProfileActionSection(
                    title: '偏好设置',
                    actions: [
                      _ProfileActionRow(
                        icon: RemixIcons.settings_3_line,
                        label: '界面设置',
                        description: '记账悬浮按钮、导航栏文字显示',
                        onTap: () => context.push('/profile/settings'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  _ProfileActionSection(
                    title: '帮助与关于',
                    actions: [
                      _ProfileActionRow(
                        icon: RemixIcons.book_open_line,
                        label: '使用手册',
                        description: '了解记账、账单、分期与关键指标',
                        onTap: () => context.push('/profile/manual'),
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
                  const SizedBox(height: AppSpacing.space16),
                  _ProfileActionSection(
                    title: '开发工具',
                    actions: [
                      _ProfileActionRow(
                        icon: Icons.widgets_outlined,
                        label: '组件示例',
                        description: '查看设计规范与组件交互状态',
                        onTap: () => context.push('/dev/design-system'),
                      ),
                      _ProfileActionRow(
                        icon: RemixIcons.file_list_3_line,
                        label: '日志',
                        description: '浏览与搜索应用运行日志',
                        onTap: () => context.push('/dev/logs'),
                      ),
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

class _ProfileActionSection extends StatelessWidget {
  const _ProfileActionSection({required this.title, required this.actions});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
          child: Text(title, style: context.appTextStyles.groupTitle),
        ),
        const SizedBox(height: AppSpacing.space8),
        AppSurface(
          child: Column(
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                actions[index],
                if (index < actions.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.space16,
                    ),
                    child: Divider(height: AppListTokens.dividerThickness),
                  ),
              ],
            ],
          ),
        ),
      ],
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
