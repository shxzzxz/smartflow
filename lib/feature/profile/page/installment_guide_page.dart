import 'package:flutter/material.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';

class InstallmentGuidePage extends StatelessWidget {
  const InstallmentGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '使用说明'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  AppSpacing.space16,
                  AppSpacing.space16,
                  AppSpacing.space32,
                ),
                children: const [
                  _GuideSection(
                    title: '分期方式',
                    description: '决定每期"本金 / 利息 / 手续费"的拆分规则。',
                    items: [
                      _GuideItem(
                        term: '等额本息',
                        body:
                            '每期还款总额相同（前 N−1 期一致）。利息逐期递减，本金逐期递增，'
                            '早期主要在付利息。各家机构求"固定额"的公式略有差异；'
                            '如需对齐机构账单，可在合同里手工填写"还款固定额"。',
                      ),
                      _GuideItem(
                        term: '等额本金',
                        body:
                            '每期本金固定（总本金 ÷ 期数），加上当期利息。每期总额逐期递减，'
                            '利息合计在三种主流方式中最低。',
                      ),
                      _GuideItem(
                        term: '先息后本',
                        body:
                            '前 N−1 期只付利息，末期一次性还清本金 + 末期利息。'
                            '前期现金流压力最小，但利息总额最高。',
                      ),
                      _GuideItem(
                        term: '一次性手续费',
                        body:
                            '无利息，按"本金 ÷ 期数 + 总手续费 ÷ 期数"逐期均分。'
                            '常见于信用卡账单分期、消费金融产品。',
                      ),
                      _GuideItem(
                        term: '自定义',
                        body:
                            '逐期手工填写本金 / 利息 / 手续费。适合不规则还款计划、'
                            '或从外部账单逐期录入。',
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.space16),
                  _GuideSection(
                    title: '计息方式',
                    description: '决定每期利息按"实际天数"还是"整月"计算。',
                    items: [
                      _GuideItem(
                        term: '按日计息',
                        body:
                            '每期利息 = 余额 × 日利率 × 当期实际天数。'
                            '月份天数差异（28 / 30 / 31）会影响每期利息；'
                            '借款日到首期还款日的实际天数也直接计入第 1 期。\n'
                            '等额本息下用"现金流折现"反推每期固定额，'
                            '退化到所有期 30 天时与标准月供公式一致。',
                      ),
                      _GuideItem(
                        term: '按月计息',
                        body:
                            '每期利息 = 余额 × 月利率，与天数无关。'
                            '每期都按整一个月计息，首期偏长 / 末期偏短都不影响。\n'
                            '等额本息下用标准月供公式 A = P · r · (1+r)ⁿ / ((1+r)ⁿ − 1)。',
                      ),
                    ],
                    footnote:
                        '消费分期 / 信用卡分期通常按月计息；'
                        '银行贷款、抵押贷款多按日计息。如不确定，按合同披露口径选择。',
                  ),
                  SizedBox(height: AppSpacing.space16),
                  _GuideSection(
                    title: '关键指标',
                    description: '衡量"借这笔钱的真实成本"。它们位于合同详情页和编辑页顶部。',
                    items: [
                      _GuideItem(
                        term: '月 IRR（月内部收益率）',
                        body:
                            '把"借款入账 → 各期还款"看作一组现金流，求出让现值为 0 的月化收益率。'
                            '它综合了利息、手续费、时间因素，是最接近"真实月成本"的指标。',
                      ),
                      _GuideItem(
                        term: '名义年化 APR',
                        body: '月 IRR × 12 的简单年化。**不考虑复利**，常用于机构对外报价。',
                      ),
                      _GuideItem(
                        term: '有效年化 EAR',
                        body:
                            '(1 + 月 IRR)¹² − 1，考虑"利上加利"的复利效应。'
                            'EAR 通常比 APR 略高，反映一整年滚动下来的真实资金成本。',
                      ),
                    ],
                    footnote:
                        '看 IRR / EAR 比看合同里的"名义月利率"更接近真实成本——'
                        '它会把手续费、不规则天数、提前还款一并算进去。',
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

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.title,
    required this.description,
    required this.items,
    this.footnote,
  });

  final String title;
  final String description;
  final List<_GuideItem> items;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: styles.pageTitle),
            const SizedBox(height: AppSpacing.space6),
            Text(
              description,
              style: styles.listSupporting.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.space12),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.space12),
              items[i],
            ],
            if (footnote != null) ...[
              const SizedBox(height: AppSpacing.space12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space12,
                  vertical: AppSpacing.space10,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  footnote!,
                  style: styles.listSupporting.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuideItem extends StatelessWidget {
  const _GuideItem({required this.term, required this.body});

  final String term;
  final String body;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(term, style: styles.formLabel.copyWith(color: colors.onSurface)),
        const SizedBox(height: AppSpacing.space4),
        Text(
          body,
          style: styles.listSupporting.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}
