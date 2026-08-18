import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/finance/bill_item_row.dart';
import '../../../widget/business/finance/bill_summary_row.dart';
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
    return switch (row) {
      CalendarBillDueRowPresentation due => _CalendarBillDueRow(row: due),
      CalendarBillSummaryRowPresentation(:final summary) => BillSummaryRow(
        presentation: summary,
        onTap: () => context.push('/bills/${summary.id}'),
      ),
    };
  }
}

class _CalendarBillDueRow extends StatelessWidget {
  const _CalendarBillDueRow({required this.row});

  final CalendarBillDueRowPresentation row;

  @override
  Widget build(BuildContext context) {
    return BillItemRow(
      presentation: row.presentation,
      onTap: () => context.push('/bills/${row.billId}'),
    );
  }
}
