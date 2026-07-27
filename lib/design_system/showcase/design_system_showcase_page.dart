import 'package:flutter/material.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/widget/business/account/account_type_tag.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';
import 'package:smartflow/widget/business/transaction/empty_transaction_card.dart';
import 'package:smartflow/widget/business/transaction/transaction_purpose_badge.dart';
import 'package:smartflow/widget/business/transaction/transaction_row.dart';

import '../theme/app_text_styles.dart';
import '../theme/app_theme_extension.dart';
import '../token/radius.dart';
import '../token/spacing.dart';
import '../widget/app_datetime_picker.dart';
import '../widget/app_form_section.dart';
import '../widget/app_page_header.dart';
import '../widget/app_plain_form_field.dart';
import '../widget/app_plain_form_row.dart';
import '../widget/app_segmented_control.dart';
import '../widget/app_status_banner.dart';
import '../widget/app_submit_button.dart';
import '../widget/app_surface.dart';
import '../widget/app_swipe_action.dart';
import '../widget/app_month_picker.dart';

const _showcaseCategories = <String>[
  '基础规范',
  '基础组件',
  '表单组件',
  '数据展示',
  '日期组件',
  '操作与反馈',
  '财务表达',
  '交易与列表',
  '布局组件',
];

void _ignoreSwitchChange(bool _) {}

enum _ShowcaseExampleKind {
  colorSemantics,
  typography,
  spacing,
  radius,
  buttons,
  segmentedControl,
  surface,
  textFormRow,
  selectFormRow,
  switchRow,
  submitButton,
  chips,
  progressIndicators,
  datePicker,
  timePicker,
  monthPicker,
  swipeAction,
  statusFeedback,
  snackBar,
  moneyText,
  accountTypeTags,
  transactionPurposeBadges,
  transactionRows,
  emptyTransaction,
  pageHeader,
  formSection,
}

const _showcaseExamples = <_ShowcaseExample>[
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.colorSemantics,
    category: '基础规范',
    title: '色彩语义',
    componentNames: 'ColorScheme / AppThemeExtension',
    keywords: ['颜色', '主题', '状态色'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.typography,
    category: '基础规范',
    title: '字体层级',
    componentNames: 'AppTextStyles',
    keywords: ['字体', '标题', '正文'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.spacing,
    category: '基础规范',
    title: '间距',
    componentNames: 'AppSpacing',
    keywords: ['间距', '尺寸'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.radius,
    category: '基础规范',
    title: '圆角',
    componentNames: 'AppRadius',
    keywords: ['圆角', '尺寸'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.buttons,
    category: '基础组件',
    title: '按钮',
    componentNames: 'FilledButton / OutlinedButton / TextButton',
    keywords: ['按钮', '主要', '次要', '禁用'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.segmentedControl,
    category: '基础组件',
    title: '分段控件',
    componentNames: 'AppSegmentedControl',
    keywords: ['分段', '切换', '选中'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.surface,
    category: '基础组件',
    title: '卡片',
    componentNames: 'AppSurface',
    keywords: ['卡片', '容器', '表面'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.textFormRow,
    category: '表单组件',
    title: '文本输入行',
    componentNames: 'AppPlainTextFormRow',
    keywords: ['输入', '文本框', '错误', '禁用'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.selectFormRow,
    category: '表单组件',
    title: '选择行',
    componentNames: 'AppPlainSelectFormRow',
    keywords: ['选择', '选项', '禁用'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.switchRow,
    category: '表单组件',
    title: '开关行',
    componentNames: 'AppPlainSwitchRow',
    keywords: ['开关', '开启', '关闭', '禁用'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.submitButton,
    category: '表单组件',
    title: '提交按钮',
    componentNames: 'AppSubmitButton',
    keywords: ['按钮', '提交', '加载', '禁用'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.chips,
    category: '数据展示',
    title: '标签',
    componentNames: 'Chip',
    keywords: ['标签', '状态'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.progressIndicators,
    category: '数据展示',
    title: '进度条',
    componentNames: 'LinearProgressIndicator',
    keywords: ['进度', '百分比', '状态'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.datePicker,
    category: '日期组件',
    title: '日期选择器',
    componentNames: 'AppDatePicker / showAppDatePicker',
    keywords: ['日期', '选择器'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.timePicker,
    category: '日期组件',
    title: '时间选择器',
    componentNames: 'AppTimePicker / showAppTimePicker',
    keywords: ['时间', '选择器'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.monthPicker,
    category: '日期组件',
    title: '月份选择器',
    componentNames: 'AppMonthSelector / showAppMonthPicker',
    keywords: ['月份', '选择器'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.swipeAction,
    category: '操作与反馈',
    title: '滑动操作',
    componentNames: 'AppSwipeAction',
    keywords: ['滑动', '快捷操作'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.statusFeedback,
    category: '操作与反馈',
    title: '状态提示',
    componentNames: 'AppStatusBanner',
    keywords: ['成功', '注意', '失败', '信息', '提示'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.snackBar,
    category: '操作与反馈',
    title: '消息提示',
    componentNames: 'SnackBar',
    keywords: ['成功', '失败', '消息', '提示'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.moneyText,
    category: '财务表达',
    title: '金额文本',
    componentNames: 'MoneyText / MoneySemantic',
    keywords: ['金额', '收入', '支出', '中性'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.accountTypeTags,
    category: '财务表达',
    title: '账户类型标签',
    componentNames: 'AccountTypeTag',
    keywords: ['账户', '资产', '负债', '权益', '标签'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.transactionPurposeBadges,
    category: '财务表达',
    title: '交易用途标签',
    componentNames: 'TransactionPurposeBadge',
    keywords: ['交易', '收入', '支出', '转账', '标签'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.transactionRows,
    category: '交易与列表',
    title: '交易行',
    componentNames: 'TransactionRow',
    keywords: ['交易', '列表', '收入', '支出'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.emptyTransaction,
    category: '交易与列表',
    title: '空状态',
    componentNames: 'EmptyTransactionCard',
    keywords: ['交易', '列表', '空状态'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.pageHeader,
    category: '布局组件',
    title: '页面标题',
    componentNames: 'AppPageHeader',
    keywords: ['布局', '标题', '操作'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.formSection,
    category: '布局组件',
    title: '表单分组',
    componentNames: 'AppFormSection',
    keywords: ['布局', '表单', '分组', '说明'],
  ),
];

class DesignSystemShowcasePage extends StatefulWidget {
  const DesignSystemShowcasePage({super.key});

  @override
  State<DesignSystemShowcasePage> createState() =>
      _DesignSystemShowcasePageState();
}

class _DesignSystemShowcasePageState extends State<DesignSystemShowcasePage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _inputController = TextEditingController(text: '输入内容');
  final _errorInputController = TextEditingController();
  final _disabledInputController = TextEditingController(text: '禁用内容');
  late final TabController _categoryController;
  var _selectedCategoryIndex = 0;
  var _query = '';
  var _selectedDate = DateTime(2026, 5, 20);
  var _selectedTime = const TimeOfDay(hour: 9, minute: 30);
  var _visibleMonth = DateTime(2026, 5);
  var _selectedOption = '选项一';
  var _switchValue = true;
  var _selectedSegment = 0;

  @override
  void initState() {
    super.initState();
    _categoryController = TabController(
      length: _showcaseCategories.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _searchController.dispose();
    _inputController.dispose();
    _errorInputController.dispose();
    _disabledInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedCategory = _showcaseCategories[_selectedCategoryIndex];
    final normalizedQuery = _query.trim().toLowerCase();
    final visibleExamples =
        normalizedQuery.isEmpty
            ? [
              for (final example in _showcaseExamples)
                if (example.category == selectedCategory) example,
            ]
            : [
              for (final example in _showcaseExamples)
                if (example.matches(normalizedQuery)) example,
            ];

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('组件示例'), centerTitle: true),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: colors.surfaceContainerLowest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.space16,
                      AppSpacing.space8,
                      AppSpacing.space16,
                      AppSpacing.space8,
                    ),
                    child: SearchBar(
                      controller: _searchController,
                      hintText: '搜索组件',
                      leading: const Icon(Icons.search_rounded),
                      trailing: [
                        if (_query.isNotEmpty)
                          IconButton(
                            tooltip: '清除搜索',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                      ],
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  TabBar(
                    controller: _categoryController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space16,
                    ),
                    labelPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space12,
                    ),
                    tabs: [
                      for (final category in _showcaseCategories)
                        Tab(text: category),
                    ],
                    onTap: (index) {
                      setState(() {
                        _selectedCategoryIndex = index;
                        _query = '';
                        _searchController.clear();
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.space8),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  AppSpacing.space16,
                  AppSpacing.space16,
                  AppSpacing.space24,
                ),
                children:
                    visibleExamples.isEmpty
                        ? const [_EmptySearchResult()]
                        : [
                          for (
                            var index = 0;
                            index < visibleExamples.length;
                            index++
                          ) ...[
                            _ShowcaseSection(
                              example: visibleExamples[index],
                              showCategory: normalizedQuery.isNotEmpty,
                              preview: _buildPreview(visibleExamples[index]),
                            ),
                            if (index < visibleExamples.length - 1)
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

  Widget _buildPreview(_ShowcaseExample example) {
    if (example.kind == _ShowcaseExampleKind.colorSemantics) {
      final colors = Theme.of(context).colorScheme;
      final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
      return Wrap(
        spacing: AppSpacing.space8,
        runSpacing: AppSpacing.space8,
        children: [
          _ColorSample(label: '品牌', color: colors.primary),
          _ColorSample(label: '表面', color: colors.surfaceContainerHighest),
          _ColorSample(label: '错误', color: colors.error),
          _ColorSample(label: '收入', color: financeColors.income),
          _ColorSample(label: '支出', color: financeColors.expense),
          _ColorSample(label: '转账', color: financeColors.transfer),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.typography) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('页面标题', style: context.appTextStyles.pageTitle),
          const SizedBox(height: AppSpacing.space8),
          Text('分组标题', style: context.appTextStyles.groupTitle),
          const SizedBox(height: AppSpacing.space8),
          Text('表单值文本', style: context.appTextStyles.formValue),
          const SizedBox(height: AppSpacing.space4),
          Text(
            '辅助说明用于补充上下文，不承担主要信息。',
            style: context.appTextStyles.listSupporting,
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.spacing) {
      return const Wrap(
        spacing: AppSpacing.space12,
        runSpacing: AppSpacing.space12,
        children: [
          _TokenSample(
            label: 'space8',
            size: AppSpacing.space8,
            radius: AppRadius.radiusMd,
          ),
          _TokenSample(
            label: 'space16',
            size: AppSpacing.space16,
            radius: AppRadius.radiusMd,
          ),
          _TokenSample(
            label: 'space24',
            size: AppSpacing.space24,
            radius: AppRadius.radiusMd,
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.radius) {
      return const Wrap(
        spacing: AppSpacing.space12,
        runSpacing: AppSpacing.space12,
        children: [
          _TokenSample(
            label: 'radiusSm',
            size: AppSpacing.space8,
            radius: AppRadius.radiusSm,
          ),
          _TokenSample(
            label: 'radiusMd',
            size: AppSpacing.space8,
            radius: AppRadius.radiusMd,
          ),
          _TokenSample(
            label: 'radiusLg',
            size: AppSpacing.space8,
            radius: AppRadius.radiusLg,
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.chips) {
      final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
      return Wrap(
        spacing: AppSpacing.space8,
        runSpacing: AppSpacing.space8,
        children: [
          const Chip(label: Text('默认标签')),
          Chip(
            avatar: Icon(Icons.check_rounded, color: financeColors.success),
            label: const Text('成功标签'),
            backgroundColor: financeColors.success.withValues(alpha: 0.1),
            side: BorderSide.none,
          ),
          Chip(
            avatar: Icon(
              Icons.warning_amber_rounded,
              color: financeColors.warning,
            ),
            label: const Text('警告标签'),
            backgroundColor: financeColors.warning.withValues(alpha: 0.1),
            side: BorderSide.none,
          ),
          Chip(
            avatar: Icon(Icons.info_rounded, color: financeColors.info),
            label: const Text('信息标签'),
            backgroundColor: financeColors.info.withValues(alpha: 0.1),
            side: BorderSide.none,
          ),
          Chip(
            avatar: Icon(Icons.cancel_rounded, color: financeColors.danger),
            label: const Text('危险标签'),
            backgroundColor: financeColors.danger.withValues(alpha: 0.1),
            side: BorderSide.none,
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.progressIndicators) {
      final colors = Theme.of(context).colorScheme;
      final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
      return Column(
        children: [
          _ProgressSample(label: '默认 60%', value: 0.6, color: colors.primary),
          const SizedBox(height: AppSpacing.space16),
          _ProgressSample(
            label: '成功 30%',
            value: 0.3,
            color: financeColors.success,
          ),
          const SizedBox(height: AppSpacing.space16),
          _ProgressSample(
            label: '警告 80%',
            value: 0.8,
            color: financeColors.warning,
          ),
          const SizedBox(height: AppSpacing.space16),
          _ProgressSample(
            label: '危险 50%',
            value: 0.5,
            color: financeColors.danger,
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.swipeAction) {
      return AppSwipeAction(
        dismissibleKey: const ValueKey('showcase-swipe-action'),
        label: '编辑',
        icon: Icons.edit_rounded,
        onTriggered: () => _showMessage('已触发滑动操作'),
        child: AppSurface(
          border: true,
          child: const ListTile(
            leading: Icon(Icons.swipe_right_rounded),
            title: Text('向右滑动'),
            subtitle: Text('展示列表项的快捷操作'),
          ),
        ),
      );
    }

    if (example.kind == _ShowcaseExampleKind.statusFeedback) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppStatusBanner(
            message: '操作成功的提示文案',
            tone: AppStatusBannerTone.success,
          ),
          SizedBox(height: AppSpacing.space8),
          AppStatusBanner(
            message: '需要注意的提示文案',
            tone: AppStatusBannerTone.warning,
          ),
          SizedBox(height: AppSpacing.space8),
          AppStatusBanner(
            message: '操作失败的提示文案',
            tone: AppStatusBannerTone.danger,
          ),
          SizedBox(height: AppSpacing.space8),
          AppStatusBanner(message: '普通提示的文案内容', tone: AppStatusBannerTone.info),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.snackBar) {
      return Wrap(
        spacing: AppSpacing.space8,
        runSpacing: AppSpacing.space8,
        children: [
          FilledButton.icon(
            onPressed: () => _showMessage('操作成功'),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('显示成功提示'),
          ),
          OutlinedButton.icon(
            onPressed: () => _showMessage('操作失败，请稍后重试'),
            icon: const Icon(Icons.error_outline_rounded),
            label: const Text('显示错误提示'),
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.pageHeader) {
      return AppPageHeader(
        title: '页面标题文案',
        subtitle: '页面说明文案与操作入口',
        actions: [
          AppHeaderIconButton(
            icon: Icons.more_horiz_rounded,
            tooltip: '更多操作',
            onPressed: () => _showMessage('更多操作'),
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.formSection) {
      return const AppFormSection(
        title: '分组标题',
        description: '这是分组的说明文案',
        children: [
          AppPlainValueRow(label: '字段名称', value: '字段内容'),
          AppPlainValueRow(label: '另一字段', value: '另一内容'),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.buttons) {
      return Wrap(
        spacing: AppSpacing.space8,
        runSpacing: AppSpacing.space8,
        children: [
          FilledButton(
            onPressed: () => _showMessage('主要操作'),
            child: const Text('主要按钮'),
          ),
          OutlinedButton(
            onPressed: () => _showMessage('次要操作'),
            child: const Text('次要按钮'),
          ),
          TextButton(
            onPressed: () => _showMessage('文本操作'),
            child: const Text('文本按钮'),
          ),
          const FilledButton(onPressed: null, child: Text('禁用按钮')),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.segmentedControl) {
      return AppSegmentedControl<int>(
        segments: const [
          AppSegment(value: 0, label: '本月'),
          AppSegment(value: 1, label: '年度'),
          AppSegment(value: 2, label: '自定义'),
        ],
        selected: _selectedSegment,
        onChanged: (value) => setState(() => _selectedSegment = value),
      );
    }

    if (example.kind == _ShowcaseExampleKind.surface) {
      return AppSurface(
        border: true,
        child: const ListTile(
          leading: Icon(Icons.widgets_outlined),
          title: Text('卡片标题'),
          subtitle: Text('这是卡片的描述文案'),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
      );
    }

    if (example.kind == _ShowcaseExampleKind.textFormRow) {
      return AppPlainFormSection(
        children: [
          AppPlainTextFormRow(
            label: '默认状态',
            controller: _inputController,
            hintText: '请输入内容',
          ),
          AppPlainTextFormRow(
            label: '错误状态',
            controller: _errorInputController,
            hintText: '请输入内容',
            validator: (_) => '输入错误',
            autovalidateMode: AutovalidateMode.always,
          ),
          AppPlainTextFormRow(
            label: '禁用状态',
            controller: _disabledInputController,
            enabled: false,
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.selectFormRow) {
      return AppPlainFormSection(
        children: [
          AppPlainSelectFormRow<String>(
            label: '选中状态',
            value: _selectedOption,
            valueText: _selectedOption,
            placeholder: '选择选项',
            onTap: (onSelected) {
              onSelected(_selectedOption == '选项一' ? '选项二' : '选项一');
            },
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedOption = value);
            },
          ),
          const AppPlainSelectFormRow<String>(
            label: '禁用状态',
            value: '选项二',
            valueText: '选项二',
            placeholder: '选择选项',
            enabled: false,
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.switchRow) {
      return AppPlainFormSection(
        children: [
          AppPlainSwitchRow(
            label: _switchValue ? '开启状态' : '关闭状态',
            value: _switchValue,
            onChanged: (value) => setState(() => _switchValue = value),
          ),
          const AppPlainSwitchRow(
            label: '禁用状态',
            value: true,
            enabled: false,
            onChanged: _ignoreSwitchChange,
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.submitButton) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ShowcaseState(
            label: '默认状态',
            child: AppSubmitButton(
              label: '主要按钮',
              onPressed: () => _showMessage('已触发主要按钮'),
            ),
          ),
          const SizedBox(height: AppSpacing.space12),
          _ShowcaseState(
            label: '危险操作',
            child: AppSubmitButton(
              label: '危险按钮',
              tone: AppSubmitButtonTone.danger,
              onPressed: () => _showMessage('已触发危险按钮'),
            ),
          ),
          const SizedBox(height: AppSpacing.space12),
          const _ShowcaseState(
            label: '加载状态',
            child: AppSubmitButton(
              label: '加载按钮',
              loading: true,
              onPressed: null,
            ),
          ),
          const SizedBox(height: AppSpacing.space12),
          const _ShowcaseState(
            label: '禁用状态',
            child: AppSubmitButton(label: '禁用按钮', onPressed: null),
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.transactionRows) {
      const rows = [
        TransactionRowPresentation(
          transactionId: 'showcase-expense',
          iconKey: null,
          title: '餐饮',
          subtitle: '12:30',
          amountText: '-68.00',
          compactAmountText: '-68',
          amountTone: FinanceTone.expense,
          accountFlow: TransactionAccountFlowPresentation(
            out: AccountEndpointPresentation(label: '现金账户'),
          ),
          badges: [
            TransactionBadgePresentation(
              label: '不计预算',
              tone: FinanceTone.neutral,
            ),
          ],
          canQuickEdit: false,
        ),
        TransactionRowPresentation(
          transactionId: 'showcase-income',
          iconKey: null,
          title: '工资',
          subtitle: '09:00',
          amountText: '+8,000.00',
          compactAmountText: '+8千',
          amountTone: FinanceTone.income,
          accountFlow: TransactionAccountFlowPresentation(
            in_: AccountEndpointPresentation(label: '银行卡'),
          ),
          badges: [],
          canQuickEdit: false,
        ),
      ];

      return AppSurface(
        border: true,
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              TransactionRow(
                presentation: rows[index],
                enableQuickEdit: false,
                onTap: () => _showMessage('打开交易详情'),
              ),
              if (index < rows.length - 1)
                const Divider(height: AppSpacing.space2),
            ],
          ],
        ),
      );
    }

    if (example.kind == _ShowcaseExampleKind.emptyTransaction) {
      return const EmptyTransactionCard(message: '暂无交易');
    }

    if (example.kind == _ShowcaseExampleKind.moneyText) {
      return Wrap(
        spacing: AppSpacing.space16,
        runSpacing: AppSpacing.space12,
        children: [
          _InlineShowcaseState(
            label: '收入状态',
            child: MoneyText(
              money: const Money(minorUnits: 128000),
              semantic: MoneySemantic.income,
              showSign: true,
              style: context.appTextStyles.amountPrimary,
            ),
          ),
          _InlineShowcaseState(
            label: '支出状态',
            child: MoneyText(
              money: const Money(minorUnits: -6800),
              semantic: MoneySemantic.expense,
              showSign: true,
              style: context.appTextStyles.amountPrimary,
            ),
          ),
          _InlineShowcaseState(
            label: '中性状态',
            child: MoneyText(
              money: Money.zero(),
              semantic: MoneySemantic.neutral,
              style: context.appTextStyles.amountPrimary,
            ),
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.accountTypeTags) {
      return const Wrap(
        spacing: AppSpacing.space8,
        runSpacing: AppSpacing.space8,
        children: [
          AccountTypeTag(type: AccountType.asset),
          AccountTypeTag(type: AccountType.liability),
          AccountTypeTag(type: AccountType.equity),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.transactionPurposeBadges) {
      return const Wrap(
        spacing: AppSpacing.space8,
        runSpacing: AppSpacing.space8,
        children: [
          TransactionPurposeBadge(purpose: BusinessPurpose.dailyIncome),
          TransactionPurposeBadge(purpose: BusinessPurpose.dailyExpense),
          TransactionPurposeBadge(purpose: BusinessPurpose.transfer),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.datePicker) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showAppDatePicker(
                context: context,
                initialDate: _selectedDate,
              );
              if (picked == null || !mounted) return;
              setState(() => _selectedDate = picked);
            },
            icon: const Icon(Icons.calendar_today_rounded),
            label: const Text('选择日期'),
          ),
          const SizedBox(height: AppSpacing.space8),
          Text(
            '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日',
            style: context.appTextStyles.formValue,
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.timePicker) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showAppTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (picked == null || !mounted) return;
              setState(() => _selectedTime = picked);
            },
            icon: const Icon(Icons.schedule_rounded),
            label: const Text('选择时间'),
          ),
          const SizedBox(height: AppSpacing.space8),
          Text(
            '${_selectedTime.hour.toString().padLeft(2, '0')}:'
            '${_selectedTime.minute.toString().padLeft(2, '0')}',
            style: context.appTextStyles.formValue,
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.monthPicker) {
      return AppMonthSelector(
        visibleMonth: _visibleMonth,
        onPreviousMonth:
            () => setState(
              () =>
                  _visibleMonth = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month - 1,
                  ),
            ),
        onMonthPressed: () async {
          final picked = await showAppMonthPicker(
            context: context,
            initialMonth: _visibleMonth,
          );
          if (picked == null || !mounted) return;
          setState(() => _visibleMonth = picked);
        },
        onNextMonth:
            () => setState(
              () =>
                  _visibleMonth = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month + 1,
                  ),
            ),
      );
    }

    throw StateError('Unsupported showcase example: ${example.kind}');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ShowcaseExample {
  const _ShowcaseExample({
    required this.kind,
    required this.category,
    required this.title,
    required this.componentNames,
    required this.keywords,
  });

  final _ShowcaseExampleKind kind;
  final String category;
  final String title;
  final String componentNames;
  final List<String> keywords;

  bool matches(String query) {
    final searchable =
        [category, title, componentNames, ...keywords].join(' ').toLowerCase();
    return searchable.contains(query);
  }
}

class _ShowcaseState extends StatelessWidget {
  const _ShowcaseState({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: context.appTextStyles.listSupporting),
        const SizedBox(height: AppSpacing.space6),
        child,
      ],
    );
  }
}

class _InlineShowcaseState extends StatelessWidget {
  const _InlineShowcaseState({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.appTextStyles.listSupporting),
        const SizedBox(height: AppSpacing.space4),
        child,
      ],
    );
  }
}

class _ProgressSample extends StatelessWidget {
  const _ProgressSample({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: value,
            color: color,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ),
        const SizedBox(width: AppSpacing.space12),
        SizedBox(
          width: AppSpacing.space32 * 2,
          child: Text(label, style: context.appTextStyles.listSupporting),
        ),
      ],
    );
  }
}

class _ShowcaseSection extends StatelessWidget {
  const _ShowcaseSection({
    required this.example,
    required this.showCategory,
    required this.preview,
  });

  final _ShowcaseExample example;
  final bool showCategory;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showCategory) ...[
              Text(
                example.category,
                style: context.appTextStyles.listSupporting.copyWith(
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
            ],
            Text(example.title, style: context.appTextStyles.subsectionTitle),
            const SizedBox(height: AppSpacing.space2),
            Text(
              example.componentNames,
              style: context.appTextStyles.listSupporting,
            ),
            const SizedBox(height: AppSpacing.space16),
            preview,
          ],
        ),
      ),
    );
  }
}

class _EmptySearchResult extends StatelessWidget {
  const _EmptySearchResult();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, color: colors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.space8),
            Text('未找到匹配组件', style: context.appTextStyles.listSupporting),
          ],
        ),
      ),
    );
  }
}

class _ColorSample extends StatelessWidget {
  const _ColorSample({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.space48 * 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: AppSpacing.space48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(label, style: context.appTextStyles.listSupporting),
        ],
      ),
    );
  }
}

class _TokenSample extends StatelessWidget {
  const _TokenSample({
    required this.label,
    required this.size,
    required this.radius,
  });

  final String label;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: AppSpacing.space48 * 2,
      child: Column(
        children: [
          Container(
            width: AppSpacing.space48,
            height: AppSpacing.space48,
            padding: EdgeInsets.all(size / 2),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(label, style: context.appTextStyles.listSupporting),
        ],
      ),
    );
  }
}
