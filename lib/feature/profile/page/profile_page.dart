import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/update/app_update_info.dart';
import '../../../core/update/app_update_platform.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_bottom_navigation_layout_scope.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../presentation/profile_menu.dart';
import '../widget/profile_group_card.dart';

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
        () => _versionInfo = const AppVersionInfo(
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
    final contentInset = AppBottomNavigationLayoutScope.of(
      context,
    ).contentInset;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '我的'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  AppSpacing.space8,
                  AppSpacing.space16,
                  AppSpacing.space24 + contentInset,
                ),
                children: [
                  for (final group in _profileGroups(
                    context,
                    versionName: versionInfo?.versionName,
                  )) ...[
                    ProfileGroupCard(group: group),
                    const SizedBox(height: AppSpacing.space16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ProfileMenuGroup> _profileGroups(
    BuildContext context, {
    required String? versionName,
  }) {
    return [
      ProfileMenuGroup(
        title: '常用功能',
        layout: ProfileGroupLayout.grid,
        entries: [
          ProfileMenuEntry(
            title: '分类管理',
            iconKey: 'category',
            onTap: () => context.push('/category'),
          ),
          ProfileMenuEntry(
            title: '标签管理',
            iconKey: 'tag',
            onTap: () => context.push('/tags'),
          ),
          ProfileMenuEntry(
            title: '对手方管理',
            iconKey: 'counterparty',
            onTap: () => context.push('/counterparties'),
          ),
          ProfileMenuEntry(
            title: '贷款计算器',
            iconKey: 'calculator',
            onTap: () => context.push('/profile/loan-calculator'),
          ),
          ProfileMenuEntry(
            title: '设置',
            iconKey: 'settings',
            onTap: () => context.push('/profile/settings'),
          ),
        ],
      ),
      ProfileMenuGroup(
        title: '信贷工具',
        layout: ProfileGroupLayout.list,
        entries: [
          ProfileMenuEntry(
            title: '分期产品',
            iconKey: 'installment_product',
            onTap: () => context.push('/installment-products'),
          ),
          ProfileMenuEntry(
            title: '参考利率',
            iconKey: 'reference_rate',
            onTap: () => context.push('/profile/reference-rates'),
          ),
        ],
      ),
      ProfileMenuGroup(
        title: '数据管理',
        layout: ProfileGroupLayout.list,
        entries: [
          ProfileMenuEntry(
            title: '数据导入',
            iconKey: 'import',
            onTap: () => context.push('/profile/import'),
          ),
          ProfileMenuEntry(
            title: '数据清理',
            iconKey: 'cleanup',
            onTap: () => context.push('/profile/data-cleanup'),
          ),
          ProfileMenuEntry(
            title: '数据备份',
            iconKey: 'backup',
            onTap: () => context.push('/profile/backup'),
          ),
        ],
      ),
      ProfileMenuGroup(
        title: '帮助与关于',
        layout: ProfileGroupLayout.list,
        entries: [
          ProfileMenuEntry(
            title: '使用手册',
            iconKey: 'manual',
            onTap: () => context.push('/profile/manual'),
          ),
          ProfileMenuEntry(
            title: '软件版本',
            value: versionName ?? '读取中',
            iconKey: 'version',
            onTap: () => context.push('/profile/software-version'),
          ),
        ],
      ),
      ProfileMenuGroup(
        title: '开发工具',
        layout: ProfileGroupLayout.list,
        entries: [
          ProfileMenuEntry(
            title: '组件示例',
            iconKey: 'components',
            onTap: () => context.push('/dev/design-system'),
          ),
          ProfileMenuEntry(
            title: '日志',
            iconKey: 'logs',
            onTap: () => context.push('/dev/logs'),
          ),
        ],
      ),
    ];
  }
}
