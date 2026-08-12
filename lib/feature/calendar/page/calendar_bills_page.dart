import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/finance/money_text.dart';
import '../presentation/calendar_bills_presentation.dart';
import '../view_model/calendar_bills_view_model.dart';

class CalendarDayBillsPage extends ConsumerWidget {
  const CalendarDayBillsPage({required this.date, super.key});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CalendarBillsPageBody(
      state: ref.watch(calendarDayBillsViewModelProvider(date)),
    );
  }
}

class CalendarMonthBillsPage extends ConsumerWidget {
  const CalendarMonthBillsPage({required this.month, super.key});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CalendarBillsPageBody(
      state: ref.watch(calendarMonthBillsViewModelProvider(month)),
    );
  }
}

class _CalendarBillsPageBody extends StatelessWidget {
  const _CalendarBillsPageBody({required this.state});

  final CalendarBillsPageState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      CalendarBillsPageLoading(:final title) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      CalendarBillsPageError(:final title, :final message) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text(message)),
      ),
      CalendarBillsPageLoaded(:final title, :final emptyMessage, :final rows) =>
        Scaffold(
          appBar: AppBar(title: Text(title)),
          body: _CalendarBillList(rows: rows, emptyMessage: emptyMessage),
        ),
    };
  }
}

class _CalendarBillList extends StatelessWidget {
  const _CalendarBillList({required this.rows, required this.emptyMessage});

  final List<CalendarBillRowPresentation> rows;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return Center(child: Text(emptyMessage));
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space16),
      children: [
        AppSurface(
          child: Column(
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                _CalendarBillRow(row: rows[index]),
                if (index < rows.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CalendarBillRow extends StatelessWidget {
  const _CalendarBillRow({required this.row});

  final CalendarBillRowPresentation row;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => context.push('/bills/${row.billId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space12,
        ),
        child: Row(
          children: [
            if (row.showBillIcon) ...[
              Icon(RemixIcons.bill_line, color: colors.primary),
              const SizedBox(width: AppSpacing.space12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.accountName, style: context.appTextStyles.listTitle),
                  const SizedBox(height: AppSpacing.space4),
                  Wrap(
                    spacing: AppSpacing.space8,
                    children: [
                      for (final text in row.supportingTexts)
                        Text(
                          text,
                          style: context.appTextStyles.listSupporting.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space12),
            MoneyText(
              money: row.amount,
              style: context.appTextStyles.amountList,
              semantic: MoneySemantic.liability,
            ),
            const SizedBox(width: AppSpacing.space4),
            Icon(RemixIcons.arrow_right_s_line, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
