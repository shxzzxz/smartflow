import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:smartflow/application/credit/credit_query_api.dart';

import '../presentation/account_credit_summary_presentation.dart';
import 'account_credit_summary_list.dart';

class AccountBillList extends StatelessWidget {
  const AccountBillList({required this.bills, super.key});

  final List<BillSummaryReadModel> bills;

  @override
  Widget build(BuildContext context) {
    return AccountCreditSummaryList(
      items: [for (final bill in bills) billAccountCreditSummary(bill)],
      emptyMessage: '暂无账单',
      onTap: (summary) => context.push('/bills/${summary.id}'),
    );
  }
}
