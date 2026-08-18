import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/widget/business/finance/bill_summary_row.dart';

import '../presentation/account_credit_summary_presentation.dart';

class AccountBillList extends StatelessWidget {
  const AccountBillList({required this.bills, super.key});

  final List<BillSummaryReadModel> bills;

  @override
  Widget build(BuildContext context) {
    return BillSummaryList(
      items: [
        for (final bill in bills) billAccountSummaryRowPresentation(bill),
      ],
      emptyMessage: '暂无账单',
      onTap: (summary) => context.push('/bills/${summary.id}'),
    );
  }
}
