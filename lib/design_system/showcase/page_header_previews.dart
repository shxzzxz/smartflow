import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../application/ledger/ledger_query_api.dart';
import '../../feature/book/widget/book_picker.dart';
import '../../feature/statistics/view/statistics_view_switcher.dart';
import '../../feature/statistics/view_model/statistics_view_model.dart';

import '../theme/app_text_styles.dart';
import '../token/radius.dart';
import '../token/spacing.dart';
import '../widget/app_month_picker.dart';
import '../widget/app_header_select_button.dart';
import '../widget/app_page_background.dart';
import '../widget/app_page_header.dart';
import '../widget/app_page_header_background_scope.dart';
import '../widget/app_popup_menu_button.dart';
import '../widget/app_select.dart';
import '../widget/app_sliding_segmented_control.dart';
import '../widget/app_tab_swipe_region.dart';

/// 使用真实页头组件展示返回、切换、月份、悬浮 Tab 与文字操作。
class PageHeaderPreviews extends StatefulWidget {
  const PageHeaderPreviews({super.key});

  @override
  State<PageHeaderPreviews> createState() => _PageHeaderPreviewsState();
}

class _PageHeaderPreviewsState extends State<PageHeaderPreviews> {
  var _month = DateTime(2026, 11);
  var _showLunar = true;
  var _tab = 0;
  var _accountFilter = 0;
  var _assetViewId = 'daily';
  var _statisticsView = StatisticsViewType.period;
  String? _bookId = Book.dailyId;
  final _books = [
    Book(id: Book.dailyId, name: Book.dailyName),
    Book(id: 'travel', name: '旅行与家庭活动账本'),
  ];

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  Future<void> _pickMonth() async {
    final month = await showAppMonthPicker(
      context: context,
      initialMonth: _month,
    );
    if (month != null && mounted) setState(() => _month = month);
  }

  AppPopupMenuButton _more() => AppPopupMenuButton(
    tooltip: '更多操作',
    icon: RemixIcons.more_2_line,
    items: [
      AppPopupMenuAction(
        label: '页面设置',
        icon: RemixIcons.settings_3_line,
        onPressed: () => _message('页面设置'),
      ),
    ],
  );

  Widget _example(String label, Widget header) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.space16,
          bottom: AppSpacing.space8,
        ),
        child: Text(label, style: context.appTextStyles.listSupporting),
      ),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.radiusXl),
        child: AppPageBackground(
          child: AppPageHeaderBackgroundScope(
            topInset: AppSpacing.space24,
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.space24,
                bottom: AppSpacing.space12,
              ),
              child: header,
            ),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpacing.space24,
    children: [
      _example(
        '统计页居中玻璃 Tab',
        AppPageHeader.custom(
          showBackButton: false,
          titleContent: StatisticsViewSwitcher(
            selected: _statisticsView,
            onChanged: (view) => setState(() => _statisticsView = view),
          ),
        ),
      ),
      _example(
        '返回与页面名称',
        AppPageHeader(
          title: '账户详情',
          onBack: () => _message('返回'),
          actions: [
            AppHeaderIconButton(
              icon: RemixIcons.edit_line,
              tooltip: '编辑账户',
              onPressed: () => _message('编辑账户'),
            ),
            _more(),
          ],
        ),
      ),
      _example(
        '账本选择与工作流回调',
        AppPageHeader.custom(
          singleRow: true,
          leading: BookPickerButton(
            books: _books,
            bookId: _bookId,
            onChanged: (id) => setState(() => _bookId = id),
            onCreateBook: () => _message('新建账本'),
            onManageBooks: () => _message('账本管理'),
          ),
          titleContent: const Text('首页'),
        ),
      ),
      _example(
        '三段同行与紧凑月份选择',
        AppPageHeader.custom(
          singleRow: true,
          leading: AppHeaderIconButton(
            icon: _showLunar ? RemixIcons.eye_line : RemixIcons.eye_off_line,
            tooltip: _showLunar ? '隐藏农历' : '显示农历',
            selected: _showLunar,
            onPressed: () => setState(() => _showLunar = !_showLunar),
          ),
          titleContent: AppMonthSelector(
            visibleMonth: _month,
            onPreviousMonth: () => _shiftMonth(-1),
            onNextMonth: () => _shiftMonth(1),
            onMonthPressed: _pickMonth,
          ),
          actions: [
            AppHeaderIconButton(
              icon: RemixIcons.calendar_check_line,
              tooltip: '回到今天',
              onPressed: () {
                final now = DateTime.now();
                setState(() => _month = DateTime(now.year, now.month));
              },
            ),
            AppHeaderIconButton(
              icon: RemixIcons.pie_chart_2_line,
              tooltip: '本月统计',
              onPressed: () => _message('本月统计'),
            ),
          ],
        ),
      ),
      _example(
        '整屏居中与自适应账户筛选',
        AppPageHeader.custom(
          showBackButton: false,
          singleRow: true,
          singleRowTitleAlignment: AppHeaderTitleAlignment.page,
          leading: AppHeaderSelectButton<String>(
            label: _assetViewId == 'default' ? '默认' : '日常收支与长期规划',
            tooltip: '切换视图',
            value: _assetViewId,
            onChanged: (id) => setState(() => _assetViewId = id),
            options: const [
              AppSelectOption(value: 'default', label: '默认'),
              AppSelectOption(value: 'daily', label: '日常收支与长期规划'),
            ],
            actions: [
              AppPopupMenuAction(
                label: '新建',
                onPressed: () => _message('新建视图'),
              ),
              AppPopupMenuAction(
                label: '管理',
                onPressed: () => _message('管理视图'),
              ),
            ],
          ),
          titleContent: AppSlidingSegmentedControl<int>(
            variant: AppSegmentedControlVariant.adaptiveHeader,
            segments: const [
              AppSegment(value: 0, label: '全部'),
              AppSegment(value: 1, label: '资产'),
              AppSegment(value: 2, label: '负债'),
            ],
            selected: _accountFilter,
            onChanged: (value) => setState(() => _accountFilter = value),
          ),
          actions: [
            AppHeaderIconButton(
              icon: RemixIcons.contract_up_down_line,
              tooltip: '折叠分组',
              compact: true,
              onPressed: () => _message('折叠分组'),
            ),
            AppHeaderIconButton(
              icon: RemixIcons.add_line,
              tooltip: '新建账户',
              compact: true,
              onPressed: () => _message('新建账户'),
            ),
            _more(),
          ],
        ),
      ),
      _example(
        '中间悬浮 Tab',
        Column(
          children: [
            AppPageHeader.custom(
              onBack: () => _message('返回'),
              titleContent: AppSlidingSegmentedControl<int>(
                variant: AppSegmentedControlVariant.header,
                segments: const [
                  AppSegment(value: 0, label: '支出'),
                  AppSegment(value: 1, label: '收入'),
                ],
                selected: _tab,
                onChanged: (tab) => setState(() => _tab = tab),
              ),
              actions: [
                AppHeaderIconButton(
                  icon: RemixIcons.add_line,
                  tooltip: '新建',
                  onPressed: () => _message('新建'),
                ),
                _more(),
              ],
            ),
            AppTabSwipeRegion<int>(
              values: const [0, 1],
              selected: _tab,
              onChanged: (tab) => setState(() => _tab = tab),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.space24,
                ),
                child: Center(
                  child: Text('当前：${_tab == 0 ? '支出' : '收入'} · 左右滑动切换'),
                ),
              ),
            ),
          ],
        ),
      ),
      _example(
        '页面名称与保存',
        AppPageHeader(
          title: '编辑账户',
          onBack: () => _message('返回'),
          actions: [
            AppHeaderTextButton(label: '保存', onPressed: () => _message('保存')),
          ],
        ),
      ),
      _example(
        '长标题与禁用状态',
        AppPageHeader(
          title: '二级页标题文案很长时会省略',
          subtitle: '页面说明文案',
          onBack: () => _message('返回'),
          actions: const [
            AppHeaderIconButton(
              icon: RemixIcons.delete_bin_line,
              tooltip: '暂不可删除',
              onPressed: null,
            ),
          ],
        ),
      ),
    ],
  );
}
