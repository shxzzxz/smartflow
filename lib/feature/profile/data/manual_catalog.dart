import '../model/manual_article.dart';

const manualCategories = <String>['全部', '开始使用', '账务基础', '信贷与分期'];

const manualArticles = <ManualArticle>[
  ManualArticle(
    slug: 'getting-started',
    title: 'SmartFlow 的记账方式',
    summary: '先理解账户、分类和交易之间的关系，再开始记录财务事实。',
    category: '开始使用',
    keywords: ['复式记账', '入门', '记账'],
    assetPath: 'assets/manual/getting-started.md',
  ),
  ManualArticle(
    slug: 'record-expense',
    title: '如何记录一笔支出',
    summary: '用一笔普通支出了解金额、账户和分类各自表达什么。',
    category: '开始使用',
    keywords: ['支出', '记账', '交易'],
    assetPath: 'assets/manual/record-expense.md',
  ),
  ManualArticle(
    slug: 'ledger-concepts',
    title: '账户、分类、交易和分录',
    summary: 'SmartFlow 中最常用的四个账务核心概念。',
    category: '账务基础',
    keywords: ['账户', '分类', '交易', '分录', '余额'],
    assetPath: 'assets/manual/ledger-concepts.md',
  ),
  ManualArticle(
    slug: 'credit-bills',
    title: '账单如何生成',
    summary: '了解信用账户的出账周期、入账日期和账单明细。',
    category: '信贷与分期',
    keywords: ['账单', '信用账户', '出账日', '入账日期'],
    assetPath: 'assets/manual/credit-bills.md',
  ),
  ManualArticle(
    slug: 'installment-contracts',
    title: '分期合同与还款计划',
    summary: '分期合同、期次计划和实际还款分别负责什么。',
    category: '信贷与分期',
    keywords: ['分期', '合同', '还款计划', '期次'],
    assetPath: 'assets/manual/installment-contracts.md',
  ),
  ManualArticle(
    slug: 'credit-metrics',
    title: '计息方式和关键指标',
    summary: '理解计息方式、利率换算、舍入、等额本息固定额算法、计划重算，以及 IRR、APR 和 EAR。',
    category: '信贷与分期',
    keywords: ['计息', '利率', '舍入', '重算', 'IRR', 'APR', 'EAR', '利息'],
    assetPath: 'assets/manual/credit-metrics.md',
  ),
  ManualArticle(
    slug: 'loan-calculator',
    title: '贷款计算器',
    summary: '不落库地试算还款计划、年化指标与提前还款。',
    category: '信贷与分期',
    keywords: ['计算器', '还款计划', '提前还款', '气球贷', '助学贷款'],
    assetPath: 'assets/manual/loan-calculator.md',
  ),
];

ManualArticle? findManualArticle(String slug) {
  for (final article in manualArticles) {
    if (article.slug == slug) {
      return article;
    }
  }
  return null;
}
