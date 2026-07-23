import 'package:flutter/material.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/widget/business/account/account_type_tag.dart';
import 'package:smartflow/widget/business/finance/finance_labels.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';
import 'package:smartflow/widget/business/transaction/empty_transaction_card.dart';
import 'package:smartflow/widget/business/transaction/transaction_purpose_badge.dart';
import 'package:smartflow/widget/business/transaction/transaction_row.dart';

import '../theme/app_text_styles.dart';
import '../theme/app_theme_extension.dart';
import '../token/list.dart';
import '../token/radius.dart';
import '../token/spacing.dart';
import '../widget/app_datetime_picker.dart';
import '../widget/app_form_section.dart';
import '../widget/app_page_header.dart';
import '../widget/app_plain_form_field.dart';
import '../widget/app_plain_form_row.dart';
import '../widget/app_segmented_control.dart';
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

enum _ShowcaseExampleKind {
  colorSemantics,
  typography,
  spacingAndRadius,
  buttonsAndSegments,
  plainForm,
  labelsAndProgress,
  dateAndTime,
  actionsAndFeedback,
  moneySemantics,
  transactions,
  pageLayout,
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
    kind: _ShowcaseExampleKind.spacingAndRadius,
    category: '基础规范',
    title: '间距与圆角',
    componentNames: 'AppSpacing / AppRadius',
    keywords: ['间距', '圆角', '尺寸'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.buttonsAndSegments,
    category: '基础组件',
    title: '按钮与分段控件',
    componentNames: 'Button / AppSegmentedControl',
    keywords: ['按钮', '切换'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.plainForm,
    category: '表单组件',
    title: '行式表单',
    componentNames: 'AppPlainTextFormRow / AppPlainSelectFormRow',
    keywords: ['输入', '选择', '开关'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.labelsAndProgress,
    category: '数据展示',
    title: '标签与进度',
    componentNames: 'Chip / LinearProgressIndicator',
    keywords: ['标签', '进度', '状态'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.dateAndTime,
    category: '日期组件',
    title: '日期与时间选择',
    componentNames: 'AppDatePicker / AppTimePicker',
    keywords: ['日期', '时间', '月份'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.actionsAndFeedback,
    category: '操作与反馈',
    title: '操作状态与消息',
    componentNames: 'AppSubmitButton / SnackBar',
    keywords: ['加载', '禁用', '提示'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.moneySemantics,
    category: '财务表达',
    title: '金额语义',
    componentNames: 'MoneyText / MoneySemantic',
    keywords: ['金额', '收入', '支出'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.transactions,
    category: '交易与列表',
    title: '交易行与空状态',
    componentNames: 'TransactionRow / EmptyTransactionCard',
    keywords: ['交易', '列表', '空状态'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.pageLayout,
    category: '布局组件',
    title: '页面标题与分组',
    componentNames: 'AppPageHeader / AppFormSection',
    keywords: ['布局', '标题', '分组'],
  ),
];

class DesignSystemShowcasePage extends StatefulWidget {
  const DesignSystemShowcasePage({super.key});

  @override
  State<DesignSystemShowcasePage> createState() =>
      _DesignSystemShowcasePageState();
}

class _DesignSystemShowcasePageState extends State<DesignSystemShowcasePage> {
  final _searchController = TextEditingController();
  final _accountNameController = TextEditingController(text: '工资卡');
  var _selectedCategoryIndex = 0;
  var _query = '';
  var _selectedDate = DateTime(2026, 5, 20);
  var _selectedTime = const TimeOfDay(hour: 9, minute: 30);
  var _visibleMonth = DateTime(2026, 5);
  var _selectedAccountType = AccountType.asset;
  var _includeInStatistics = true;
  var _selectedSegment = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _accountNameController.dispose();
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
      appBar: AppBar(
        title: const Text('组件示例'),
        backgroundColor: colors.surface,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
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
                elevation: const WidgetStatePropertyAll(0),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space16,
              ),
              child: Row(
                children: [
                  for (
                    var index = 0;
                    index < _showcaseCategories.length;
                    index++
                  )
                    Padding(
                      padding: EdgeInsets.only(
                        right:
                            index == _showcaseCategories.length - 1
                                ? AppSpacing.space0
                                : AppSpacing.space8,
                      ),
                      child: ChoiceChip(
                        label: Text(_showcaseCategories[index]),
                        selected: index == _selectedCategoryIndex,
                        onSelected: (selected) {
                          if (!selected) return;
                          setState(() {
                            _selectedCategoryIndex = index;
                            _query = '';
                            _searchController.clear();
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  AppSpacing.space4,
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
                            _ShowcaseCard(
                              example: visibleExamples[index],
                              showCategory: normalizedQuery.isNotEmpty,
                              preview: _buildPreview(visibleExamples[index]),
                            ),
                            if (index < visibleExamples.length - 1)
                              const SizedBox(height: AppSpacing.space12),
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

    if (example.kind == _ShowcaseExampleKind.spacingAndRadius) {
      return const Wrap(
        spacing: AppSpacing.space12,
        runSpacing: AppSpacing.space12,
        children: [
          _TokenSample(
            label: 'space8',
            size: AppSpacing.space8,
            radius: AppRadius.radiusSm,
          ),
          _TokenSample(
            label: 'space16',
            size: AppSpacing.space16,
            radius: AppRadius.radiusMd,
          ),
          _TokenSample(
            label: 'space24',
            size: AppSpacing.space24,
            radius: AppRadius.radiusLg,
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.labelsAndProgress) {
      final colors = Theme.of(context).colorScheme;
      final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Wrap(
            spacing: AppSpacing.space8,
            runSpacing: AppSpacing.space8,
            children: [
              Chip(label: Text('默认')),
              Chip(avatar: Icon(Icons.check_rounded), label: Text('已完成')),
              Chip(avatar: Icon(Icons.schedule_rounded), label: Text('处理中')),
            ],
          ),
          const SizedBox(height: AppSpacing.space16),
          _StatusBanner(
            icon: Icons.check_circle_rounded,
            label: '操作成功，数据已保存',
            color: financeColors.success,
          ),
          const SizedBox(height: AppSpacing.space8),
          _StatusBanner(
            icon: Icons.info_rounded,
            label: '请确认本次调整的统计口径',
            color: financeColors.info,
          ),
          const SizedBox(height: AppSpacing.space16),
          LinearProgressIndicator(
            value: 0.65,
            color: colors.primary,
            backgroundColor: colors.surfaceContainerHighest,
          ),
          const SizedBox(height: AppSpacing.space8),
          LinearProgressIndicator(
            value: 0.35,
            color: financeColors.income,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.actionsAndFeedback) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSwipeAction(
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
          ),
          const SizedBox(height: AppSpacing.space12),
          Wrap(
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
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.pageLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageHeader(
            title: '账户详情',
            subtitle: '页面身份、说明与操作入口',
            actions: [
              AppHeaderIconButton(
                icon: Icons.more_horiz_rounded,
                tooltip: '更多操作',
                onPressed: () => _showMessage('更多操作'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space16),
          const AppFormSection(
            title: '基本信息',
            description: '使用统一的标题、说明、表面和字段间距',
            children: [
              AppPlainValueRow(label: '账户类型', value: '资产账户'),
              AppPlainValueRow(label: '默认币种', value: '人民币'),
            ],
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.buttonsAndSegments) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
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
          ),
          const SizedBox(height: AppSpacing.space16),
          AppSegmentedControl<int>(
            segments: const [
              AppSegment(value: 0, label: '本月'),
              AppSegment(value: 1, label: '年度'),
              AppSegment(value: 2, label: '自定义'),
            ],
            selected: _selectedSegment,
            onChanged: (value) => setState(() => _selectedSegment = value),
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.plainForm) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPlainFormSection(
            children: [
              AppPlainTextFormRow(
                label: '账户名称',
                controller: _accountNameController,
                requiredIndicator: true,
                hintText: '请输入账户名称',
              ),
              AppPlainSelectFormRow<AccountType>(
                label: '账户类型',
                value: _selectedAccountType,
                valueText: '${accountTypeLabel(_selectedAccountType)}账户',
                placeholder: '请选择账户类型',
                onTap: (onSelected) {
                  onSelected(
                    _selectedAccountType == AccountType.asset
                        ? AccountType.liability
                        : AccountType.asset,
                  );
                },
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedAccountType = value);
                },
              ),
              AppPlainSwitchRow(
                label: '参与统计',
                description: '关闭后仍保留交易，但不进入统计口径',
                value: _includeInStatistics,
                onChanged:
                    (value) => setState(() => _includeInStatistics = value),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          Row(
            children: [
              Expanded(
                child: AppSubmitButton(
                  label: '保存',
                  onPressed: () => _showMessage('表单已保存'),
                ),
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: AppSubmitButton(
                  label: '保存中',
                  loading: true,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.transactions) {
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

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSurface(
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
          ),
          const SizedBox(height: AppSpacing.space12),
          const EmptyTransactionCard(message: '暂无更多交易'),
        ],
      );
    }

    if (example.kind == _ShowcaseExampleKind.moneySemantics) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.space16,
            runSpacing: AppSpacing.space8,
            children: [
              MoneyText(
                money: const Money(minorUnits: 128000),
                semantic: MoneySemantic.income,
                showSign: true,
                style: context.appTextStyles.amountPrimary,
              ),
              MoneyText(
                money: const Money(minorUnits: -6800),
                semantic: MoneySemantic.expense,
                showSign: true,
                style: context.appTextStyles.amountPrimary,
              ),
              MoneyText(
                money: Money.zero(),
                semantic: MoneySemantic.neutral,
                style: context.appTextStyles.amountPrimary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space16),
          Text('账户类型', style: context.appTextStyles.listTitle),
          const SizedBox(height: AppSpacing.space8),
          const Wrap(
            spacing: AppSpacing.space8,
            runSpacing: AppSpacing.space8,
            children: [
              AccountTypeTag(type: AccountType.asset),
              AccountTypeTag(type: AccountType.liability),
              AccountTypeTag(type: AccountType.equity),
            ],
          ),
          const SizedBox(height: AppSpacing.space16),
          Text('交易用途', style: context.appTextStyles.listTitle),
          const SizedBox(height: AppSpacing.space8),
          const Wrap(
            spacing: AppSpacing.space8,
            runSpacing: AppSpacing.space8,
            children: [
              TransactionPurposeBadge(purpose: BusinessPurpose.dailyIncome),
              TransactionPurposeBadge(purpose: BusinessPurpose.dailyExpense),
              TransactionPurposeBadge(purpose: BusinessPurpose.transfer),
            ],
          ),
        ],
      );
    }

    if (example.kind != _ShowcaseExampleKind.dateAndTime) {
      throw StateError('Unsupported showcase example: ${example.kind}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.space8,
          runSpacing: AppSpacing.space8,
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
          ],
        ),
        const SizedBox(height: AppSpacing.space8),
        Text(
          '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日 '
          '${_selectedTime.hour.toString().padLeft(2, '0')}:'
          '${_selectedTime.minute.toString().padLeft(2, '0')}',
          style: context.appTextStyles.formValue,
        ),
        const SizedBox(height: AppSpacing.space16),
        AppMonthSelector(
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
        ),
      ],
    );
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

class _ShowcaseCard extends StatelessWidget {
  const _ShowcaseCard({
    required this.example,
    required this.showCategory,
    required this.preview,
  });

  final _ShowcaseExample example;
  final bool showCategory;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showCategory) ...[
              Text(
                example.category,
                style: context.appTextStyles.listSupporting,
              ),
              const SizedBox(height: AppSpacing.space4),
            ],
            Text(example.title, style: context.appTextStyles.subsectionTitle),
            const SizedBox(height: AppSpacing.space4),
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space12,
        vertical: AppSpacing.space8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppListTokens.statusBackgroundOpacity),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: AppSpacing.space18, color: color),
          const SizedBox(width: AppSpacing.space8),
          Expanded(
            child: Text(
              label,
              style: context.appTextStyles.listSupporting.copyWith(
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
