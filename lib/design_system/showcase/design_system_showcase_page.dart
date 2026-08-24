import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/widget/business/account/account_endpoint.dart';
import 'package:smartflow/widget/business/account/account_endpoint_view.dart';
import 'package:smartflow/widget/business/account/account_type_tag.dart';
import 'package:smartflow/widget/business/analytics/analysis_chart_card.dart';
import 'package:smartflow/widget/business/analytics/chart/app_cartesian_chart.dart';
import 'package:smartflow/widget/business/analytics/chart/app_chart_empty_state.dart';
import 'package:smartflow/widget/business/analytics/category_progress_list_item.dart';
import 'package:smartflow/widget/business/analytics/chart/app_donut_chart.dart';
import 'package:smartflow/widget/business/category/category_avatar.dart';
import 'package:smartflow/widget/business/category/category_grid_picker.dart';
import 'package:smartflow/widget/business/finance/adaptive_money_text.dart';
import 'package:smartflow/widget/business/finance/bill_item_row.dart';
import 'package:smartflow/widget/business/finance/bill_status_badge.dart';
import 'package:smartflow/widget/business/finance/bill_summary_row.dart';
import 'package:smartflow/widget/business/finance/cashflow_summary_card.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';
import 'package:smartflow/widget/business/icon/business_icon_bubble.dart';
import 'package:smartflow/widget/business/icon/icon_catalog_picker.dart';
import 'package:smartflow/widget/business/icon/icon_choice_grid.dart';
import 'package:smartflow/widget/business/transaction/empty_transaction_card.dart';
import 'package:smartflow/widget/business/transaction/transaction_amount_input.dart';
import 'package:smartflow/widget/business/transaction/transaction_day_card.dart';
import 'package:smartflow/widget/business/transaction/transaction_feed.dart';
import 'package:smartflow/widget/business/transaction/transaction_progress_badges.dart';
import 'package:smartflow/widget/business/transaction/transaction_purpose_badge.dart';
import 'package:smartflow/widget/business/transaction/transaction_row.dart';

import '../theme/app_text_styles.dart';
import '../theme/app_theme_extension.dart';
import '../token/chart.dart';
import '../token/radius.dart';
import '../token/list.dart';
import '../token/spacing.dart';
import '../widget/app_datetime_picker.dart';
import '../widget/app_cascade_multi_select.dart';
import '../widget/app_date_picker_panel.dart';
import '../widget/app_dropdown.dart';
import '../widget/app_form_field.dart';
import '../widget/app_form_section.dart';
import '../widget/app_month_picker.dart';
import '../widget/app_page_header.dart';
import '../widget/app_plain_form_field.dart';
import '../widget/app_plain_form_row.dart';
import '../widget/app_popup_menu_button.dart';
import '../widget/app_select.dart';
import '../widget/app_settings_row.dart';
import '../widget/app_segmented_control.dart';
import '../widget/app_sliding_segmented_control.dart';
import '../widget/app_status_banner.dart';
import '../widget/app_submit_button.dart';
import '../widget/app_surface.dart';
import '../widget/app_swipe_action.dart';
import '../../widget/business/category/tree_select.dart';

const _showcaseCategories = <String>[
  '设计基础',
  '基础控件',
  '表单与输入',
  '选择器与弹层',
  '反馈与状态',
  '布局与容器',
  '数据展示',
  '财务表达',
  '业务图标',
  '交易与列表',
];

void _ignoreSwitchChange(bool _) {}

enum _ShowcaseExampleKind {
  colorSemantics,
  typography,
  spacing,
  radius,
  formFields,
  plainRows,
  buttons,
  segmentedControl,
  popupMenu,
  selectMenu,
  dropdown,
  settingsRows,
  surface,
  textFormRow,
  selectFormRow,
  choiceFormRows,
  switchRow,
  moneyFormRow,
  businessFormRows,
  transactionAmountPanel,
  iconChoiceGrid,
  iconCatalogPicker,
  categoryGridPicker,
  cascadeMultiSelect,
  submitButton,
  chips,
  progressIndicators,
  categoryProgress,
  analyticsCharts,
  datePicker,
  datePickerPanel,
  timePicker,
  monthPicker,
  treeSelect,
  swipeAction,
  statusFeedback,
  snackBar,
  moneyText,
  adaptiveMoneyText,
  billRows,
  businessIcons,
  accountEndpoint,
  accountTypeTags,
  transactionPurposeBadges,
  cashflowSummary,
  transactionRows,
  transactionProgressBadges,
  transactionDayCard,
  transactionFeed,
  emptyTransaction,
  pageHeader,
  formSection,
}

const _showcaseExamples = <_ShowcaseExample>[
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.colorSemantics,
    category: '设计基础',
    title: '色彩语义',
    componentNames: 'ColorScheme / AppThemeExtension',
    keywords: ['颜色', '主题', '状态色'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.typography,
    category: '设计基础',
    title: '字体层级',
    componentNames: 'AppTextStyles',
    keywords: ['字体', '标题', '正文'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.spacing,
    category: '设计基础',
    title: '间距',
    componentNames: 'AppSpacing',
    keywords: ['间距', '尺寸'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.radius,
    category: '设计基础',
    title: '圆角',
    componentNames: 'AppRadius',
    keywords: ['圆角', '尺寸'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.formFields,
    category: '表单与输入',
    title: '表单字段',
    componentNames:
        'AppTextFormField / AppDropdownFormField / AppPlainTextFormField',
    keywords: ['表单', '输入框', '下拉', '校验', '无装饰'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.plainRows,
    category: '表单与输入',
    title: '基础表单行',
    componentNames: 'AppPlainFormRow / AppPlainValueRow / AppPlainValueText',
    keywords: ['表单行', '只读', '值', '布局'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.buttons,
    category: '基础控件',
    title: '按钮',
    componentNames: 'FilledButton / OutlinedButton / TextButton',
    keywords: ['按钮', '主要', '次要', '禁用'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.segmentedControl,
    category: '基础控件',
    title: '分段控件',
    componentNames: 'AppSegmentedControl / AppSlidingSegmentedControl',
    keywords: ['分段', '切换', '选中', '滑动'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.popupMenu,
    category: '基础控件',
    title: '弹出菜单',
    componentNames: 'AppPopupMenuButton',
    keywords: ['菜单', '弹出', '更多', '设置', '开关'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.selectMenu,
    category: '基础控件',
    title: '选择菜单',
    componentNames: 'AppSelectMenu / AppSelectOption',
    keywords: ['选择', '菜单', '图标', '定位'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.dropdown,
    category: '基础控件',
    title: '下拉选择',
    componentNames: 'AppDropdown',
    keywords: ['下拉', '选择', '菜单'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.settingsRows,
    category: '基础控件',
    title: '设置行',
    componentNames: 'AppSettingsSwitchRow / AppSettingsSelectRow',
    keywords: ['设置', '开关', '选择', '整行', '说明'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.surface,
    category: '布局与容器',
    title: '卡片',
    componentNames: 'AppSurface',
    keywords: ['卡片', '容器', '表面'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.textFormRow,
    category: '表单与输入',
    title: '文本输入行',
    componentNames: 'AppPlainTextFormRow',
    keywords: ['输入', '文本框', '必填', '只读', '错误', '禁用'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.selectFormRow,
    category: '表单与输入',
    title: '选择行',
    componentNames: 'AppPlainSelectFormRow',
    keywords: ['选择', '选项', '占位', '禁用'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.choiceFormRows,
    category: '表单与输入',
    title: '菜单与分段表单行',
    componentNames: 'AppPlainSelectMenuFormRow / AppPlainSegmentedFormRow',
    keywords: ['选择', '菜单', '分段', '校验', '禁用'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.switchRow,
    category: '表单与输入',
    title: '开关行',
    componentNames: 'AppSwitch / AppPlainSwitchRow',
    keywords: ['开关', '开启', '关闭', '描述', '禁用'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.moneyFormRow,
    category: '表单与输入',
    title: '金额输入行',
    componentNames: 'MoneyPlainFormRow',
    keywords: ['金额', '输入', '小数', '必填'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.businessFormRows,
    category: '表单与输入',
    title: '业务字段行',
    componentNames:
        'AccountPlainFormRow / AppPlainSelectMenuFormRow / '
        'ValueWithUnitPlainFormRow / showAccountPickerSheet',
    keywords: ['账户', '下拉', '单位', '选择', '底部弹层'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.transactionAmountPanel,
    category: '表单与输入',
    title: '交易金额面板',
    componentNames: 'TransactionAmountInput',
    keywords: ['金额', '备注', '面板', '支出'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.iconChoiceGrid,
    category: '选择器与弹层',
    title: '图标选择网格',
    componentNames: 'IconChoiceGrid',
    keywords: ['图标', '选择', '网格'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.iconCatalogPicker,
    category: '选择器与弹层',
    title: '图标目录选择',
    componentNames: 'IconCatalogPicker',
    keywords: ['图标', '搜索', '分类', '账户'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.categoryGridPicker,
    category: '选择器与弹层',
    title: '分类网格选择',
    componentNames: 'CategoryGridPicker',
    keywords: ['分类', '选择', '网格', '子分类'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.cascadeMultiSelect,
    category: '选择器与弹层',
    title: '级联多选',
    componentNames: 'AppCascadeMultiSelect',
    keywords: ['级联', '多选', '层级', '全部', '清除'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.submitButton,
    category: '反馈与状态',
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
    category: '反馈与状态',
    title: '进度条',
    componentNames: 'LinearProgressIndicator',
    keywords: ['进度', '百分比', '状态'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.categoryProgress,
    category: '数据展示',
    title: '分类进度项',
    componentNames: 'CategoryProgressListItem',
    keywords: ['分类', '进度', '列表', '分析'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.analyticsCharts,
    category: '数据展示',
    title: '分析图表',
    componentNames:
        'AnalysisSectionCard / AppCartesianChart / AppDonutChart / AppChartEmptyState',
    keywords: ['图表', '折线', '柱状', '环形', '分析', '空状态'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.datePicker,
    category: '选择器与弹层',
    title: '日期选择器',
    componentNames: 'AppDatePicker / showAppDatePicker',
    keywords: ['日期', '选择器'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.datePickerPanel,
    category: '选择器与弹层',
    title: '日期面板',
    componentNames: 'AppDatePickerPanel',
    keywords: ['日期', '面板', '范围', '月份', '年份', '宫格'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.timePicker,
    category: '选择器与弹层',
    title: '时间选择器',
    componentNames: 'AppTimePicker / showAppTimePicker',
    keywords: ['时间', '选择器'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.monthPicker,
    category: '选择器与弹层',
    title: '月份选择器',
    componentNames: 'AppMonthSelector / showAppMonthPicker',
    keywords: ['月份', '选择器'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.treeSelect,
    category: '选择器与弹层',
    title: '树形选择',
    componentNames: 'TreeSelect',
    keywords: ['树形', '分类', '选择', '子项'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.swipeAction,
    category: '基础控件',
    title: '滑动操作',
    componentNames: 'AppSwipeAction',
    keywords: ['滑动', '快捷操作'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.statusFeedback,
    category: '反馈与状态',
    title: '状态提示',
    componentNames: 'AppStatusBanner',
    keywords: ['成功', '注意', '失败', '信息', '提示'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.snackBar,
    category: '反馈与状态',
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
    kind: _ShowcaseExampleKind.adaptiveMoneyText,
    category: '财务表达',
    title: '自适应金额文本',
    componentNames: 'AdaptiveMoneyText / ComparedMoneyText / SummaryMoneyText',
    keywords: ['金额', '自适应', '紧凑', '对比'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.billRows,
    category: '财务表达',
    title: '账单行与状态',
    componentNames: 'BillSummaryRow / BillItemRow / BillStatusBadge',
    keywords: ['账单', '明细', '金额', '状态', '徽章'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.businessIcons,
    category: '业务图标',
    title: '图标展示',
    componentNames: 'BusinessIcon / BusinessIconBubble / CategoryAvatar',
    keywords: ['图标', '气泡', '分类', '账户'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.accountEndpoint,
    category: '财务表达',
    title: '账户端点',
    componentNames: 'AccountEndpointView',
    keywords: ['账户', '图标', '流向'],
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
    kind: _ShowcaseExampleKind.cashflowSummary,
    category: '财务表达',
    title: '现金流汇总卡',
    componentNames: 'CashflowSummaryCard',
    keywords: ['收入', '支出', '预算', '汇总'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.transactionRows,
    category: '交易与列表',
    title: '交易行',
    componentNames: 'TransactionRow',
    keywords: ['交易', '列表', '收入', '支出'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.transactionProgressBadges,
    category: '交易与列表',
    title: '交易进度徽章',
    componentNames: 'TransactionProgressBadges',
    keywords: ['徽章', '退款', '报销', '聚合'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.transactionDayCard,
    category: '交易与列表',
    title: '交易日卡片',
    componentNames: 'TransactionDayCard',
    keywords: ['交易', '日分组', '汇总', '列表'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.transactionFeed,
    category: '交易与列表',
    title: '交易 Feed',
    componentNames: 'TransactionFeedScrollView',
    keywords: ['交易', '滚动', '分页', '加载', '错误'],
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
    category: '布局与容器',
    title: '页面头部',
    componentNames: 'AppPageHeader / AppHeaderIconButton',
    keywords: ['布局', '标题', '页头', '返回', '操作'],
  ),
  _ShowcaseExample(
    kind: _ShowcaseExampleKind.formSection,
    category: '布局与容器',
    title: '表单分组',
    componentNames: 'AppFormSection',
    keywords: ['布局', '表单', '分组', '说明'],
  ),
];

const _sampleTransactionRows = <TransactionRowPresentation>[
  TransactionRowPresentation(
    transactionId: 'showcase-expense',
    iconKey: 'meal',
    title: '餐饮',
    subtitle: '12:30',
    amountText: '-68.00',
    compactAmountText: '-68',
    amountTone: FinanceTone.expense,
    accountFlow: TransactionAccountFlowPresentation(
      out: AccountEndpointPresentation(label: '现金账户', iconKey: 'cash'),
    ),
    badges: [
      TransactionBadgePresentation(label: '不计预算', tone: FinanceTone.neutral),
    ],
    canQuickEdit: true,
  ),
  TransactionRowPresentation(
    transactionId: 'showcase-income',
    iconKey: 'salary',
    title: '工资',
    subtitle: '09:00',
    amountText: '+8,000.00',
    compactAmountText: '+8千',
    amountTone: FinanceTone.income,
    accountFlow: TransactionAccountFlowPresentation(
      in_: AccountEndpointPresentation(label: '工资卡', iconKey: 'boc_debit_card'),
    ),
    badges: [],
    canQuickEdit: false,
  ),
];

const _sampleTransactionBadges = <TransactionBadgePresentation>[
  TransactionBadgePresentation(label: '退 12', tone: FinanceTone.income),
  TransactionBadgePresentation(label: '报 45', tone: FinanceTone.info),
  TransactionBadgePresentation(label: '优 3.5', tone: FinanceTone.income),
  TransactionBadgePresentation(label: '不计预算', tone: FinanceTone.equity),
];

const _sampleCashflowSummary = CashflowSummaryPresentation(
  metrics: [
    CashflowSummaryMetricPresentation(
      label: '本月收入',
      amount: Money(minorUnits: 800000),
      caption: '+1.2千/18%/12%',
      tone: FinanceTone.income,
    ),
    CashflowSummaryMetricPresentation(
      label: '本月支出',
      amount: Money(minorUnits: 620000),
      caption: '-680/-9%/-5%',
      tone: FinanceTone.expense,
    ),
    CashflowSummaryMetricPresentation(
      label: '本月预算',
      amount: Money(minorUnits: 1000000),
      caption: '62%/10000',
      tone: FinanceTone.primary,
    ),
  ],
);

Account _sampleCategory(String id, String name, String iconKey) {
  return Account(
    id: id,
    name: name,
    type: AccountType.expense,
    balance: Money.zero(),
    iconKey: iconKey,
  );
}

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
  final _requiredInputController = TextEditingController();
  final _readOnlyInputController = TextEditingController(text: '只读内容');
  final _errorInputController = TextEditingController();
  final _disabledInputController = TextEditingController(text: '禁用内容');
  final _moneyController = TextEditingController(text: '128.00');
  final _moneyHintController = TextEditingController();
  final _termValueController = TextEditingController(text: '12');
  final _panelAmountController = TextEditingController(text: '88.00');
  final _panelNoteController = TextEditingController();
  late final TabController _categoryController;
  late final List<Account> _sampleAccounts = [
    Account(
      id: 'acc-cash',
      name: '现金账户',
      type: AccountType.asset,
      balance: const Money(minorUnits: 128000),
      iconKey: 'cash',
    ),
    Account(
      id: 'acc-salary',
      name: '工资卡',
      type: AccountType.asset,
      balance: const Money(minorUnits: 8000000),
      iconKey: 'boc_debit_card',
    ),
    Account(
      id: 'acc-alipay',
      name: '支付宝',
      type: AccountType.asset,
      balance: const Money(minorUnits: 52000),
      iconKey: 'alipay',
    ),
  ];
  late final List<CategoryNode> _sampleCategoryNodes = [
    CategoryNode(
      account: _sampleCategory('cat-dining', '餐饮', 'meal'),
      children: [
        _sampleCategory('cat-breakfast', '早餐', 'cup-line'),
        _sampleCategory('cat-lunch', '午餐', 'bowl-line'),
      ],
    ),
    CategoryNode(account: _sampleCategory('cat-transport', '交通', 'metro')),
    CategoryNode(account: _sampleCategory('cat-shopping', '购物', 'shopping')),
  ];
  var _selectedCategoryIndex = 0;
  var _query = '';
  var _selectedDate = DateTime(2026, 5, 20);
  var _selectedTime = const TimeOfDay(hour: 9, minute: 30);
  var _visibleMonth = DateTime(2026, 5);
  var _dropdownValue = '月';
  DateTimeRange? _panelRange;
  var _selectedOption = '选项一';
  var _settingsSelectValue = 0;
  var _switchValue = true;
  var _describedSwitchValue = false;
  var _selectedSegment = 0;
  var _selectedSlidingSegment = 0;
  var _selectedMenuOption = 0;
  var _menuSwitchOn = true;
  var _menuDensity = 0;
  var _menuActionCount = 0;
  var _selectedCycle = 0;
  var _selectedTermUnit = 0;
  String? _selectedAccountId = 'acc-cash';
  String? _selectedIconKey = 'meal';
  String? _selectedCategoryRootId = 'cat-dining';
  String? _selectedCategoryId = 'cat-breakfast';
  Set<String> _selectedCascadeValues = {'parent', 'child'};

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
    _requiredInputController.dispose();
    _readOnlyInputController.dispose();
    _errorInputController.dispose();
    _disabledInputController.dispose();
    _moneyController.dispose();
    _moneyHintController.dispose();
    _termValueController.dispose();
    _panelAmountController.dispose();
    _panelNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedCategory = _showcaseCategories[_selectedCategoryIndex];
    final normalizedQuery = _query.trim().toLowerCase();
    final visibleExamples = normalizedQuery.isEmpty
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppPageHeader(title: '组件示例'),
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
                children: visibleExamples.isEmpty
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
    return switch (example.kind) {
      _ShowcaseExampleKind.colorSemantics => _colorSemanticsPreview(),
      _ShowcaseExampleKind.typography => _typographyPreview(),
      _ShowcaseExampleKind.spacing => _spacingPreview(),
      _ShowcaseExampleKind.radius => _radiusPreview(),
      _ShowcaseExampleKind.formFields => _formFieldsPreview(),
      _ShowcaseExampleKind.plainRows => _plainRowsPreview(),
      _ShowcaseExampleKind.buttons => _buttonsPreview(),
      _ShowcaseExampleKind.segmentedControl => _segmentedControlPreview(),
      _ShowcaseExampleKind.popupMenu => _popupMenuPreview(),
      _ShowcaseExampleKind.selectMenu => _selectMenuPreview(),
      _ShowcaseExampleKind.dropdown => _dropdownPreview(),
      _ShowcaseExampleKind.settingsRows => _settingsRowsPreview(),
      _ShowcaseExampleKind.surface => _surfacePreview(),
      _ShowcaseExampleKind.textFormRow => _textFormRowPreview(),
      _ShowcaseExampleKind.selectFormRow => _selectFormRowPreview(),
      _ShowcaseExampleKind.choiceFormRows => _choiceFormRowsPreview(),
      _ShowcaseExampleKind.switchRow => _switchRowPreview(),
      _ShowcaseExampleKind.moneyFormRow => _moneyFormRowPreview(),
      _ShowcaseExampleKind.businessFormRows => _businessFormRowsPreview(),
      _ShowcaseExampleKind.transactionAmountPanel =>
        _transactionAmountPanelPreview(),
      _ShowcaseExampleKind.iconChoiceGrid => _iconChoiceGridPreview(),
      _ShowcaseExampleKind.iconCatalogPicker => _iconCatalogPickerPreview(),
      _ShowcaseExampleKind.categoryGridPicker => _categoryGridPickerPreview(),
      _ShowcaseExampleKind.cascadeMultiSelect => _cascadeMultiSelectPreview(),
      _ShowcaseExampleKind.submitButton => _submitButtonPreview(),
      _ShowcaseExampleKind.chips => _chipsPreview(),
      _ShowcaseExampleKind.progressIndicators => _progressIndicatorsPreview(),
      _ShowcaseExampleKind.categoryProgress => _categoryProgressPreview(),
      _ShowcaseExampleKind.analyticsCharts => _analyticsChartsPreview(),
      _ShowcaseExampleKind.datePicker => _datePickerPreview(),
      _ShowcaseExampleKind.datePickerPanel => _datePickerPanelPreview(),
      _ShowcaseExampleKind.timePicker => _timePickerPreview(),
      _ShowcaseExampleKind.monthPicker => _monthPickerPreview(),
      _ShowcaseExampleKind.treeSelect => _treeSelectPreview(),
      _ShowcaseExampleKind.swipeAction => _swipeActionPreview(),
      _ShowcaseExampleKind.statusFeedback => _statusFeedbackPreview(),
      _ShowcaseExampleKind.snackBar => _snackBarPreview(),
      _ShowcaseExampleKind.moneyText => _moneyTextPreview(),
      _ShowcaseExampleKind.adaptiveMoneyText => _adaptiveMoneyTextPreview(),
      _ShowcaseExampleKind.billRows => _billRowsPreview(),
      _ShowcaseExampleKind.businessIcons => _businessIconsPreview(),
      _ShowcaseExampleKind.accountEndpoint => _accountEndpointPreview(),
      _ShowcaseExampleKind.accountTypeTags => _accountTypeTagsPreview(),
      _ShowcaseExampleKind.transactionPurposeBadges =>
        _transactionPurposeBadgesPreview(),
      _ShowcaseExampleKind.cashflowSummary => _cashflowSummaryPreview(),
      _ShowcaseExampleKind.transactionRows => _transactionRowsPreview(),
      _ShowcaseExampleKind.transactionProgressBadges =>
        _transactionProgressBadgesPreview(),
      _ShowcaseExampleKind.transactionDayCard => _transactionDayCardPreview(),
      _ShowcaseExampleKind.transactionFeed => _transactionFeedPreview(),
      _ShowcaseExampleKind.emptyTransaction => _emptyTransactionPreview(),
      _ShowcaseExampleKind.pageHeader => _pageHeaderPreview(),
      _ShowcaseExampleKind.formSection => _formSectionPreview(),
    };
  }

  Widget _colorSemanticsPreview() {
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

  Widget _typographyPreview() {
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

  Widget _spacingPreview() {
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

  Widget _radiusPreview() {
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

  Widget _formFieldsPreview() {
    return AppPlainFormSection(
      children: [
        AppTextFormField(
          controller: _inputController,
          labelText: '标准字段',
          hintText: '支持标签和主题输入装饰',
        ),
        AppDropdownFormField<String>(
          value: _selectedOption,
          labelText: '下拉字段',
          items: const [
            DropdownMenuItem(value: '选项一', child: Text('选项一')),
            DropdownMenuItem(value: '选项二', child: Text('选项二')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _selectedOption = value);
          },
        ),
        AppPlainTextFormField(
          controller: _readOnlyInputController,
          hintText: '无装饰字段',
          readOnly: true,
        ),
      ],
    );
  }

  Widget _plainRowsPreview() {
    return AppPlainFormSection(
      children: [
        AppPlainFormRow(
          label: '自定义内容',
          supportingText: '基础行只负责标签、状态和内容布局',
          child: const Text('组件内容'),
        ),
        const AppPlainValueRow(label: '只读值', value: '示例值'),
        const AppPlainValueRow(
          label: '左对齐值',
          value: '可选内容',
          valueAlignment: AppPlainRowValueAlignment.start,
        ),
      ],
    );
  }

  Widget _buttonsPreview() {
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

  Widget _segmentedControlPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.space12,
      children: [
        AppSegmentedControl<int>(
          segments: const [
            AppSegment(value: 0, label: '本月'),
            AppSegment(value: 1, label: '年度'),
            AppSegment(value: 2, label: '自定义'),
          ],
          selected: _selectedSegment,
          onChanged: (value) => setState(() => _selectedSegment = value),
        ),
        AppSlidingSegmentedControl<int>(
          segments: const [
            AppSegment(value: 0, label: '支出'),
            AppSegment(value: 1, label: '收入'),
            AppSegment(value: 2, label: '对比'),
          ],
          selected: _selectedSlidingSegment,
          onChanged: (value) => setState(() => _selectedSlidingSegment = value),
        ),
      ],
    );
  }

  Widget _popupMenuPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.space12,
      children: [
        Row(
          children: [
            AppPopupMenuButton(
              tooltip: '图表设置',
              icon: RemixIcons.settings_3_line,
              items: [
                AppPopupMenuChoice(
                  label: '柱状图',
                  icon: RemixIcons.bar_chart_line,
                  selected: _selectedMenuOption == 0,
                  onPressed: () => setState(() => _selectedMenuOption = 0),
                ),
                AppPopupMenuChoice(
                  label: '曲线',
                  icon: RemixIcons.line_chart_line,
                  selected: _selectedMenuOption == 1,
                  onPressed: () => setState(() => _selectedMenuOption = 1),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.space12),
            Text(_selectedMenuOption == 0 ? '当前：柱状图' : '当前：曲线'),
          ],
        ),
        Row(
          children: [
            AppPopupMenuButton(
              tooltip: '视图设置',
              icon: RemixIcons.settings_3_line,
              items: [
                AppPopupMenuToggle(
                  label: '显示图例',
                  icon: RemixIcons.eye_line,
                  value: _menuSwitchOn,
                  onChanged: (value) => setState(() => _menuSwitchOn = value),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.space12),
            Text(_menuSwitchOn ? '图例：显示' : '图例：隐藏'),
          ],
        ),
        Row(
          children: [
            AppPopupMenuButton(
              tooltip: '更多操作',
              icon: RemixIcons.more_2_fill,
              items: [
                AppPopupMenuAction(
                  label: '刷新数据',
                  icon: RemixIcons.refresh_line,
                  onPressed: () => setState(() => _menuActionCount += 1),
                ),
                const AppPopupMenuAction(
                  label: '暂不可用',
                  icon: RemixIcons.forbid_line,
                  onPressed: null,
                ),
                AppPopupMenuControl(
                  label: '显示密度',
                  child: AppSlidingSegmentedControl<int>(
                    segments: const [
                      AppSegment(value: 0, label: '紧凑'),
                      AppSegment(value: 1, label: '舒展'),
                    ],
                    selected: _menuDensity,
                    onChanged: (value) => setState(() => _menuDensity = value),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.space12),
            Text('刷新次数：$_menuActionCount'),
          ],
        ),
      ],
    );
  }

  Widget _selectMenuPreview() {
    return Row(
      children: [
        AppSelectMenu<int>(
          options: const [
            AppSelectOption(value: 0, label: '按月', icon: Icons.calendar_month),
            AppSelectOption(value: 1, label: '按年', icon: Icons.date_range),
          ],
          value: _settingsSelectValue,
          tooltip: '选择周期',
          onChanged: (value) => setState(() => _settingsSelectValue = value),
          triggerBuilder: (context, selected) => DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space12,
                vertical: AppSpacing.space8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected.icon != null) ...[
                    Icon(selected.icon, size: AppSpacing.space20),
                    const SizedBox(width: AppSpacing.space6),
                  ],
                  Text(selected.label),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space12),
        Text('当前：${_settingsSelectValue == 0 ? '按月' : '按年'}'),
      ],
    );
  }

  Widget _surfacePreview() {
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

  Widget _textFormRowPreview() {
    return AppPlainFormSection(
      children: [
        AppPlainTextFormRow(
          label: '默认状态',
          controller: _inputController,
          hintText: '请输入内容',
        ),
        AppPlainTextFormRow(
          label: '必填状态',
          controller: _requiredInputController,
          requiredIndicator: true,
          hintText: '请输入内容',
          supportingText: '带必填标识与辅助说明',
        ),
        AppPlainTextFormRow(
          label: '只读状态',
          controller: _readOnlyInputController,
          readOnly: true,
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

  Widget _selectFormRowPreview() {
    return AppPlainFormSection(
      children: [
        const AppPlainSelectFormRow<String>(
          label: '未选状态',
          value: null,
          placeholder: '请选择选项',
        ),
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

  Widget _choiceFormRowsPreview() {
    return AppPlainFormSection(
      children: [
        AppPlainSelectMenuFormRow<int>(
          label: '默认选择',
          value: _selectedCycle,
          options: const [
            AppSelectOption(value: 0, label: '每月'),
            AppSelectOption(value: 1, label: '每周'),
          ],
          onChanged: (value) => setState(() => _selectedCycle = value),
        ),
        AppPlainSelectMenuFormRow<int>(
          label: '错误状态',
          value: _selectedCycle,
          options: const [
            AppSelectOption(value: 0, label: '每月'),
            AppSelectOption(value: 1, label: '每周'),
          ],
          requiredIndicator: true,
          validator: (_) => '请选择账期',
          autovalidateMode: AutovalidateMode.always,
          onChanged: (value) => setState(() => _selectedCycle = value),
        ),
        const AppPlainSelectMenuFormRow<int>(
          label: '禁用状态',
          value: 0,
          options: [
            AppSelectOption(value: 0, label: '每月'),
            AppSelectOption(value: 1, label: '每周'),
          ],
          enabled: false,
        ),
        AppPlainSegmentedFormRow<int>(
          label: '默认分段',
          value: _selectedTermUnit,
          segments: const [
            AppSegment(value: 0, label: '期'),
            AppSegment(value: 1, label: '月'),
          ],
          onChanged: (value) => setState(() => _selectedTermUnit = value),
        ),
        const AppPlainSegmentedFormRow<int>(
          label: '禁用分段',
          value: 0,
          segments: [
            AppSegment(value: 0, label: '期'),
            AppSegment(value: 1, label: '月'),
          ],
          onChanged: null,
        ),
      ],
    );
  }

  Widget _switchRowPreview() {
    return AppPlainFormSection(
      children: [
        AppPlainSwitchRow(
          label: _switchValue ? '开启状态' : '关闭状态',
          value: _switchValue,
          onChanged: (value) => setState(() => _switchValue = value),
        ),
        AppPlainSwitchRow(
          label: '带描述状态',
          description: '描述文案补充说明开关的影响范围',
          value: _describedSwitchValue,
          onChanged: (value) => setState(() => _describedSwitchValue = value),
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

  Widget _moneyFormRowPreview() {
    return AppPlainFormSection(
      children: [
        MoneyPlainFormRow(
          label: '必填状态',
          controller: _moneyController,
          requiredIndicator: true,
          hintText: '0.00',
        ),
        MoneyPlainFormRow(
          label: '辅助说明',
          controller: _moneyHintController,
          hintText: '0.00',
          supportingText: '仅允许数字与两位小数',
        ),
      ],
    );
  }

  Widget _businessFormRowsPreview() {
    return AppPlainFormSection(
      children: [
        AccountPlainFormRow(
          label: '账户',
          account: findAccountById(_selectedAccountId, _sampleAccounts),
          placeholder: '请选择账户',
          selectedId: _selectedAccountId,
          onTap: (onSelected) async {
            final picked = await showAccountPickerSheet(
              context: context,
              title: '选择账户',
              accounts: _sampleAccounts,
              selectedId: _selectedAccountId,
            );
            if (picked == null || !mounted) return;
            onSelected(picked);
          },
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedAccountId = value);
          },
        ),
        AppPlainSelectMenuFormRow<int>(
          label: '菜单选择',
          value: _selectedCycle,
          options: const [
            AppSelectOption(value: 0, label: '每月'),
            AppSelectOption(value: 1, label: '每周'),
          ],
          onChanged: (value) => setState(() => _selectedCycle = value),
        ),
        ValueWithUnitPlainFormRow<int>(
          label: '数值单位',
          controller: _termValueController,
          unit: _selectedTermUnit,
          unitOptions: const [
            AppSelectOption(value: 0, label: '期'),
            AppSelectOption(value: 1, label: '月'),
          ],
          onUnitChanged: (value) => setState(() => _selectedTermUnit = value),
          hintText: '请输入数值',
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _transactionAmountPanelPreview() {
    return _ShowcaseState(
      label: '支出语义（金额由数字键盘驱动，备注可输入）',
      child: _PreviewBackdrop(
        child: TransactionAmountInput(
          amountController: _panelAmountController,
          noteController: _panelNoteController,
          semantic: MoneySemantic.expense,
          amountValidator: validatePositiveMoneyText,
        ),
      ),
    );
  }

  Widget _iconChoiceGridPreview() {
    final specs = businessIconSpecsForUsage(
      BusinessIconUsage.expenseCategory,
    ).take(10);
    return IconChoiceGrid(
      choices: [
        for (final spec in specs)
          IconChoiceGridItem(
            iconKey: spec.iconKey,
            label: spec.label,
            iconBuilder: (context, size) =>
                BusinessIcon(iconKey: spec.iconKey, size: size),
          ),
      ],
      selectedKey: _selectedIconKey,
      onChanged: (value) => setState(() => _selectedIconKey = value),
      maxVisibleRows: 2,
      tileMainExtent: 132,
    );
  }

  Widget _iconCatalogPickerPreview() {
    return IconCatalogPicker(
      usage: BusinessIconUsage.expenseCategory,
      selectedKey: _selectedIconKey,
      onChanged: (value) => setState(() => _selectedIconKey = value),
    );
  }

  Widget _categoryGridPickerPreview() {
    return CategoryGridPicker(
      nodes: _sampleCategoryNodes,
      selectedRootId: _selectedCategoryRootId,
      selectedCategoryId: _selectedCategoryId,
      emptyLabel: '暂无分类',
      onRootSelected: (root) => setState(() {
        _selectedCategoryRootId = root.id;
        _selectedCategoryId = root.id;
      }),
      onChildSelected: (root, child) => setState(() {
        _selectedCategoryRootId = root.id;
        _selectedCategoryId = child.id;
      }),
      onAddRoot: () => _showMessage('新增一级分类'),
      onAddChild: (_) => _showMessage('新增子分类'),
    );
  }

  Widget _cascadeMultiSelectPreview() {
    return Row(
      children: [
        Expanded(child: Text('已选 ${_selectedCascadeValues.length} 项')),
        OutlinedButton.icon(
          onPressed: () async {
            final selected = await showAppCascadeMultiSelectSheet<String>(
              context: context,
              title: '选择项目',
              sections: const [
                AppCascadeSelectionSection(
                  label: '示例分组',
                  nodes: [
                    AppCascadeSelectionNode(
                      value: 'parent',
                      label: '父级项目',
                      children: [
                        AppCascadeSelectionNode(
                          value: 'child',
                          label: '子级项目',
                          children: [
                            AppCascadeSelectionNode(
                              value: 'grandchild',
                              label: '孙级项目',
                            ),
                          ],
                        ),
                      ],
                    ),
                    AppCascadeSelectionNode(value: 'sibling', label: '同级项目'),
                  ],
                ),
              ],
              selectedValues: _selectedCascadeValues,
            );
            if (selected == null || !mounted) return;
            setState(() => _selectedCascadeValues = selected);
          },
          icon: const Icon(RemixIcons.node_tree),
          label: const Text('打开'),
        ),
      ],
    );
  }

  Widget _submitButtonPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space12,
      children: [
        _ShowcaseState(
          label: '默认状态',
          child: AppSubmitButton(
            label: '主要按钮',
            onPressed: () => _showMessage('已触发主要按钮'),
          ),
        ),
        _ShowcaseState(
          label: '危险操作',
          child: AppSubmitButton(
            label: '危险按钮',
            tone: AppSubmitButtonTone.danger,
            onPressed: () => _showMessage('已触发危险按钮'),
          ),
        ),
        const _ShowcaseState(
          label: '加载状态',
          child: AppSubmitButton(label: '加载按钮', loading: true, onPressed: null),
        ),
        const _ShowcaseState(
          label: '禁用状态',
          child: AppSubmitButton(label: '禁用按钮', onPressed: null),
        ),
      ],
    );
  }

  Widget _chipsPreview() {
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

  Widget _progressIndicatorsPreview() {
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    return Column(
      spacing: AppSpacing.space16,
      children: [
        _ProgressSample(label: '默认 60%', value: 0.6, color: colors.primary),
        _ProgressSample(
          label: '成功 30%',
          value: 0.3,
          color: financeColors.success,
        ),
        _ProgressSample(
          label: '警告 80%',
          value: 0.8,
          color: financeColors.warning,
        ),
        _ProgressSample(
          label: '危险 50%',
          value: 0.5,
          color: financeColors.danger,
        ),
      ],
    );
  }

  Widget _categoryProgressPreview() {
    return Column(
      children: [
        CategoryProgressListItem(
          title: '餐饮',
          progress: .68,
          color: Theme.of(context).extension<AppThemeExtension>()!.expense,
          trailing: const Text('68%'),
          onTap: () => _showMessage('打开餐饮分类'),
        ),
        CategoryProgressListItem(
          title: '交通',
          progress: .32,
          color: Theme.of(context).extension<AppThemeExtension>()!.income,
          trailing: const Text('32%'),
          onTap: () => _showMessage('打开交通分类'),
        ),
      ],
    );
  }

  Widget _analyticsChartsPreview() {
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    return Column(
      spacing: AppSpacing.space16,
      children: [
        _PreviewBackdrop(
          child: AnalysisChartCard(
            title: '收支趋势',
            showExpandIcon: true,
            expandedReservedHeight:
                AppChartGeometry.interactiveLegendReservedHeight,
            chart: _showcaseCartesianChart(financeColors),
            expandedChartBuilder: (height) =>
                _showcaseCartesianChart(financeColors, height: height),
          ),
        ),
        AppDonutChart(
          slices: [
            AppDonutSlice(
              label: '餐饮',
              value: 60,
              formattedValue: '600.00',
              color: financeColors.chart1,
            ),
            AppDonutSlice(
              label: '交通',
              value: 40,
              formattedValue: '400.00',
              color: financeColors.chart2,
            ),
          ],
          centerLabel: '总支出',
          centerValue: '1,000.00',
        ),
        const AppChartEmptyState(message: '区间内暂无数据'),
      ],
    );
  }

  Widget _showcaseCartesianChart(
    AppThemeExtension financeColors, {
    double? height,
  }) {
    return AppCartesianChart(
      data: AppCartesianChartData(
        axisPoints: const [
          AppChartAxisPoint(x: 0, label: '1日'),
          AppChartAxisPoint(x: 1, label: '8日'),
          AppChartAxisPoint(x: 2, label: '15日'),
          AppChartAxisPoint(x: 3, label: '22日'),
        ],
        series: [
          AppChartSeries(
            label: '收入',
            color: financeColors.income,
            points: const [
              AppChartPoint(x: 0, value: 1200, formattedValue: '1,200.00'),
              AppChartPoint(x: 1, value: 1800, formattedValue: '1,800.00'),
              AppChartPoint(x: 2, value: 1500, formattedValue: '1,500.00'),
              AppChartPoint(x: 3, value: 2400, formattedValue: '2,400.00'),
            ],
          ),
          AppChartSeries(
            label: '支出',
            color: financeColors.expense,
            points: const [
              AppChartPoint(x: 0, value: 800, formattedValue: '800.00'),
              AppChartPoint(x: 1, value: 1400, formattedValue: '1,400.00'),
              AppChartPoint(x: 2, value: 900, formattedValue: '900.00'),
              AppChartPoint(x: 3, value: 1600, formattedValue: '1,600.00'),
            ],
          ),
        ],
      ),
      form: AppCartesianChartForm.line,
      showLegend: true,
      height: height ?? AppChartGeometry.primaryPlotHeight,
    );
  }

  Widget _dropdownPreview() {
    return Row(
      children: [
        AppDropdown<String>(
          tooltip: '选择粒度',
          options: const [
            AppSelectOption(value: '年', label: '年'),
            AppSelectOption(value: '月', label: '月'),
            AppSelectOption(value: '日', label: '日'),
          ],
          value: _dropdownValue,
          onChanged: (value) => setState(() => _dropdownValue = value),
        ),
        const SizedBox(width: AppSpacing.space12),
        Text(
          '当前：$_dropdownValue',
          style: context.appTextStyles.formValueEmphasis,
        ),
      ],
    );
  }

  Widget _settingsRowsPreview() {
    return Column(
      children: [
        AppSettingsSwitchRow(
          label: '显示余额',
          description: '在账户列表中显示余额',
          value: _switchValue,
          onChanged: (value) => setState(() => _switchValue = value),
        ),
        const Divider(height: AppListTokens.dividerThickness),
        AppSettingsSelectRow<int>(
          label: '下拉灵敏度',
          description: '选择下拉触发所需的距离',
          value: _settingsSelectValue,
          options: const [
            AppSelectOption(value: 0, label: '灵敏'),
            AppSelectOption(value: 1, label: '稳妥'),
          ],
          onChanged: (value) => setState(() => _settingsSelectValue = value),
        ),
      ],
    );
  }

  Widget _datePickerPanelPreview() {
    final range = _panelRange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space8,
      children: [
        AppDatePickerPanel(
          granularity: AppDatePickerGranularity.date,
          mode: AppDatePickerMode.range,
          initialValue: _selectedDate,
          onRangeChanged: (picked, _) => setState(() => _panelRange = picked),
        ),
        Text(
          range == null
              ? '点选起止日期，点击标题可切换月份 / 年份视图'
              : '${range.start.year}.${range.start.month}.${range.start.day} - '
                    '${range.end.year}.${range.end.month}.${range.end.day}',
          style: context.appTextStyles.formValueEmphasis,
        ),
      ],
    );
  }

  Widget _datePickerPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.space8,
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
        Text(
          '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日',
          style: context.appTextStyles.formValueEmphasis,
        ),
      ],
    );
  }

  Widget _timePickerPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.space8,
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
        Text(
          '${_selectedTime.hour.toString().padLeft(2, '0')}:'
          '${_selectedTime.minute.toString().padLeft(2, '0')}',
          style: context.appTextStyles.formValueEmphasis,
        ),
      ],
    );
  }

  Widget _monthPickerPreview() {
    return AppMonthSelector(
      visibleMonth: _visibleMonth,
      onPreviousMonth: () => setState(
        () => _visibleMonth = DateTime(
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
      onNextMonth: () => setState(
        () => _visibleMonth = DateTime(
          _visibleMonth.year,
          _visibleMonth.month + 1,
        ),
      ),
    );
  }

  Widget _treeSelectPreview() {
    return OutlinedButton.icon(
      onPressed: () async {
        final selected = await showModalBottomSheet<Account>(
          context: context,
          isScrollControlled: true,
          builder: (context) => TreeSelect(nodes: _sampleCategoryNodes),
        );
        if (selected != null && mounted) _showMessage('已选择 ${selected.name}');
      },
      icon: const Icon(Icons.account_tree_outlined),
      label: const Text('打开树形选择'),
    );
  }

  Widget _swipeActionPreview() {
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

  Widget _statusFeedbackPreview() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space8,
      children: [
        AppStatusBanner(
          message: '操作成功的提示文案',
          tone: AppStatusBannerTone.success,
        ),
        AppStatusBanner(
          message: '需要注意的提示文案',
          tone: AppStatusBannerTone.warning,
        ),
        AppStatusBanner(message: '操作失败的提示文案', tone: AppStatusBannerTone.danger),
        AppStatusBanner(message: '普通提示的文案内容', tone: AppStatusBannerTone.info),
      ],
    );
  }

  Widget _snackBarPreview() {
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

  Widget _moneyTextPreview() {
    return Wrap(
      spacing: AppSpacing.space16,
      runSpacing: AppSpacing.space12,
      children: [
        _ShowcaseState(
          inline: true,
          label: '收入状态',
          child: MoneyText(
            money: const Money(minorUnits: 128000),
            semantic: MoneySemantic.income,
            showSign: true,
            style: context.appTextStyles.amountPrimary,
          ),
        ),
        _ShowcaseState(
          inline: true,
          label: '支出状态',
          child: MoneyText(
            money: const Money(minorUnits: -6800),
            semantic: MoneySemantic.expense,
            showSign: true,
            style: context.appTextStyles.amountPrimary,
          ),
        ),
        _ShowcaseState(
          inline: true,
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

  Widget _adaptiveMoneyTextPreview() {
    final textStyles = context.appTextStyles;
    const sampleMoney = Money(minorUnits: 1234567890);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.space12,
      children: [
        _ShowcaseState(
          inline: true,
          label: '宽度充足显示完整金额',
          child: _PreviewBox(
            width: 200,
            child: SummaryMoneyText(
              money: sampleMoney,
              style: textStyles.amountList,
              maxWidth: 180,
            ),
          ),
        ),
        _ShowcaseState(
          inline: true,
          label: '宽度不足回退紧凑金额',
          child: _PreviewBox(
            width: 112,
            child: SummaryMoneyText(
              money: sampleMoney,
              style: textStyles.amountList,
              maxWidth: 92,
            ),
          ),
        ),
        _ShowcaseState(
          inline: true,
          label: '原价与实付对比',
          child: ComparedMoneyText(
            originalPreciseText: '128.00',
            originalCompactText: '128',
            actualPreciseText: '96.00',
            actualCompactText: '96',
            originalStyle: textStyles.transactionSupporting,
            actualStyle: textStyles.transactionAmount,
            maxWidth: 160,
          ),
        ),
      ],
    );
  }

  Widget _billRowsPreview() {
    const summary = BillSummaryRowPresentation(
      id: 'bill',
      title: '2026年07月',
      amount: Money(minorUnits: 320000),
      supportingTexts: [BillSummarySupportingText(text: '2 条明细')],
      status: BillStatusBadgePresentation(
        label: '已出账',
        tone: BillStatusTone.warning,
      ),
    );
    const item = BillItemRowPresentation(
      id: 'item',
      leadingIcon: RemixIcons.shopping_bag_3_line,
      title: '消费',
      supportingTexts: ['还款 2026-07-25'],
      amount: Money(minorUnits: 120000),
      status: BillStatusBadgePresentation(
        label: '待还',
        tone: BillStatusTone.warning,
      ),
    );
    return _PreviewBackdrop(
      child: AppSurface(
        border: true,
        child: Column(
          children: [
            BillSummaryRow(
              presentation: summary,
              onTap: () => _showMessage('打开账单详情'),
            ),
            const Divider(height: AppSpacing.space2),
            BillItemRow(
              presentation: item,
              onTap: () => _showMessage('打开账单明细'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _businessIconsPreview() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.space12,
      children: [
        _ShowcaseState(
          inline: true,
          label: '图标（Remix 与 SVG 资源）',
          child: Wrap(
            spacing: AppSpacing.space12,
            children: [
              BusinessIcon(iconKey: 'meal', size: 28),
              BusinessIcon(iconKey: 'metro', size: 28),
              BusinessIcon(iconKey: 'salary', size: 28),
              BusinessIcon(iconKey: 'alipay', size: 28),
            ],
          ),
        ),
        _ShowcaseState(
          inline: true,
          label: '图标气泡',
          child: Wrap(
            spacing: AppSpacing.space16,
            children: [
              BusinessIconBubble(
                size: 40,
                label: '未选中',
                child: BusinessIcon(iconKey: 'meal', size: 24),
              ),
              BusinessIconBubble(
                size: 40,
                selected: true,
                label: '选中',
                child: BusinessIcon(iconKey: 'meal', size: 24),
              ),
            ],
          ),
        ),
        _ShowcaseState(
          inline: true,
          label: '分类头像',
          child: Wrap(
            spacing: AppSpacing.space16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CategoryAvatar(iconKey: 'meal'),
              CategoryAvatar(iconKey: 'shopping', size: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _accountEndpointPreview() {
    final style = context.appTextStyles.transactionSupporting;
    const endpoint = AccountEndpoint(label: '现金账户', iconKey: 'cash');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.space12,
      children: [
        _ShowcaseState(
          inline: true,
          label: '默认（尾随排布）',
          child: _PreviewBox(
            width: 176,
            child: AccountEndpointView(endpoint: endpoint, style: style),
          ),
        ),
        _ShowcaseState(
          inline: true,
          label: '紧凑前置',
          child: _PreviewBox(
            width: 176,
            child: AccountEndpointView.compactLeading(
              endpoint: endpoint,
              style: style,
            ),
          ),
        ),
        _ShowcaseState(
          inline: true,
          label: '紧凑尾随',
          child: _PreviewBox(
            width: 176,
            child: AccountEndpointView.compactTrailing(
              endpoint: endpoint,
              style: style,
            ),
          ),
        ),
      ],
    );
  }

  Widget _accountTypeTagsPreview() {
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

  Widget _transactionPurposeBadgesPreview() {
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

  Widget _cashflowSummaryPreview() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space12,
      children: [
        _ShowcaseState(
          label: '含环比说明',
          child: _PreviewBackdrop(
            child: CashflowSummaryCard(summary: _sampleCashflowSummary),
          ),
        ),
        _ShowcaseState(
          label: '仅金额',
          child: _PreviewBackdrop(
            child: CashflowSummaryCard(
              summary: _sampleCashflowSummary,
              showCaptions: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _transactionRowsPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space12,
      children: [
        AppSurface(
          border: true,
          child: Column(
            children: [
              for (
                var index = 0;
                index < _sampleTransactionRows.length;
                index++
              ) ...[
                TransactionRow(
                  presentation: _sampleTransactionRows[index],
                  enableQuickEdit: false,
                  onTap: () => _showMessage('打开交易详情'),
                ),
                if (index < _sampleTransactionRows.length - 1)
                  const Divider(height: AppSpacing.space2),
              ],
            ],
          ),
        ),
        _ShowcaseState(
          label: '批量选择',
          child: AppSurface(
            border: true,
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < _sampleTransactionRows.length;
                  index++
                ) ...[
                  TransactionRow(
                    presentation: _sampleTransactionRows[index].copyWith(
                      selectable: true,
                      selected: index == 0,
                    ),
                    enableQuickEdit: false,
                    onTap: () => _showMessage('切换选中状态'),
                    onSelectionChanged: (_) => _showMessage('切换选中状态'),
                  ),
                  if (index < _sampleTransactionRows.length - 1)
                    const Divider(height: AppSpacing.space2),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _transactionProgressBadgesPreview() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.space12,
      children: [
        _ShowcaseState(
          inline: true,
          label: '宽度充足显示全部徽章',
          child: _PreviewBox(
            child: TransactionProgressBadges(badges: _sampleTransactionBadges),
          ),
        ),
        _ShowcaseState(
          inline: true,
          label: '宽度不足聚合为 +N',
          child: _PreviewBox(
            width: 132,
            child: TransactionProgressBadges(badges: _sampleTransactionBadges),
          ),
        ),
      ],
    );
  }

  Widget _transactionDayCardPreview() {
    return _PreviewBackdrop(
      child: TransactionDayCard(
        group: TransactionDayGroup(
          date: DateTime(2026, 5, 20),
          rows: _sampleTransactionRows,
          incomeMinor: 800000,
          expenseMinor: 6800,
        ),
        onRowTap: (_) => _showMessage('打开交易详情'),
        onRowQuickEdit: (_) => _showMessage('打开快捷编辑'),
      ),
    );
  }

  Widget _transactionFeedPreview() {
    return SizedBox(
      height: 360,
      child: TransactionFeedScrollView(
        groups: [
          TransactionDayGroup(
            date: DateTime(2026, 5, 20),
            rows: _sampleTransactionRows,
            incomeMinor: 800000,
            expenseMinor: 6800,
          ),
        ],
        hasMore: true,
        onLoadMore: () => _showMessage('已请求加载更多'),
      ),
    );
  }

  Widget _emptyTransactionPreview() {
    return const EmptyTransactionCard(message: '暂无交易');
  }

  Widget _pageHeaderPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space12,
      children: [
        _PreviewBackdrop(
          child: AppPageHeader(
            title: '一级页标题',
            showBackButton: false,
            actions: [
              AppHeaderIconButton(
                icon: RemixIcons.add_line,
                tooltip: '新建',
                onPressed: () => _showMessage('新建'),
              ),
              AppPopupMenuButton(
                tooltip: '更多操作',
                icon: RemixIcons.more_2_fill,
                items: [
                  AppPopupMenuAction(
                    label: '页面设置',
                    icon: RemixIcons.settings_3_line,
                    onPressed: () => _showMessage('页面设置'),
                  ),
                ],
              ),
            ],
          ),
        ),
        _PreviewBackdrop(
          child: AppPageHeader(
            title: '二级页标题文案很长时会省略',
            subtitle: '页面说明文案',
            onBack: () => _showMessage('返回'),
            actions: [
              AppHeaderIconButton(
                icon: RemixIcons.edit_line,
                tooltip: '编辑',
                onPressed: () => _showMessage('编辑'),
              ),
              const AppHeaderIconButton(
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

  Widget _formSectionPreview() {
    return const AppFormSection(
      title: '分组标题',
      description: '这是分组的说明文案',
      children: [
        AppPlainValueRow(label: '字段名称', value: '字段内容'),
        AppPlainValueRow(label: '另一字段', value: '另一内容'),
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
    final searchable = [
      category,
      title,
      componentNames,
      ...keywords,
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }
}

class _ShowcaseState extends StatelessWidget {
  const _ShowcaseState({
    required this.label,
    required this.child,
    this.inline = false,
  });

  final String label;
  final Widget child;

  /// 行内示例左对齐并使用更小的标签间距；默认示例横向拉伸。
  final bool inline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: inline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.stretch,
      spacing: inline ? AppSpacing.space4 : AppSpacing.space6,
      children: [
        Text(label, style: context.appTextStyles.listSupporting),
        child,
      ],
    );
  }
}

class _SampleTile extends StatelessWidget {
  const _SampleTile({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.space48 * 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.space4,
        children: [
          child,
          Text(label, style: context.appTextStyles.listSupporting),
        ],
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.space8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}

class _PreviewBackdrop extends StatelessWidget {
  const _PreviewBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
      ),
      child: child,
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
    return _SampleTile(
      label: label,
      child: Container(
        height: AppSpacing.space48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        ),
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
    return _SampleTile(
      label: label,
      child: Container(
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
    );
  }
}
