import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/application/ledger/ledger_api.dart';
import 'package:smartflow/feature/home/widget/transaction_progress_badges.dart';

void main() {
  testWidgets('formats badge amounts without trailing zeroes', (tester) async {
    await tester.pumpWidget(
      _TestHost(
        item: _item(
          refundedTotal: const Money(minorUnits: 30),
          reimbursementReceivedTotal: const Money(minorUnits: 23),
        ),
      ),
    );

    expect(find.text('退 0.3'), findsOneWidget);
    expect(find.text('报 0.23'), findsOneWidget);
    expect(find.text('退 0.30'), findsNothing);
  });

  testWidgets('keeps badges in a single horizontal row', (tester) async {
    await tester.pumpWidget(
      SizedBox(
        width: 120,
        child: _TestHost(
          item: _item(
            isExcludedFromStats: true,
            isExcludedFromBudget: true,
            refundedTotal: const Money(minorUnits: 30),
            reimbursementReceivedTotal: const Money(minorUnits: 23),
            reimbursementGapIncome: const Money(minorUnits: 100),
            reimbursementGapExpense: const Money(minorUnits: 101),
            repaymentInterest: const Money(minorUnits: 200),
            repaymentFee: const Money(minorUnits: 201),
          ),
        ),
      ),
    );

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scrollView.scrollDirection, Axis.horizontal);

    final labels = [
      '不计统计',
      '不计预算',
      '退 0.3',
      '报 0.23',
      '利 2',
      '费 2.01',
      '差收 1',
      '差支 1.01',
    ];
    final top = tester.getTopLeft(find.text(labels.first)).dy;
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
      expect(tester.getTopLeft(find.text(label)).dy, top);
    }
  });
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.item});

  final TransactionListItem item;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(child: TransactionProgressBadges(item: item)),
      ),
    );
  }
}

TransactionListItem _item({
  bool isExcludedFromStats = false,
  bool isExcludedFromBudget = false,
  Money? refundedTotal,
  Money? reimbursementReceivedTotal,
  Money? reimbursementGapIncome,
  Money? reimbursementGapExpense,
  Money? repaymentInterest,
  Money? repaymentFee,
}) {
  final details = <TransactionDetailRecord>[];
  var lineNo = 1;
  if (repaymentInterest != null) {
    details.add(
      TransactionDetailRecord(
        id: lineNo,
        transactionId: 1,
        lineNo: lineNo++,
        type: TransactionDetailType.repaymentInterest,
        amount: repaymentInterest,
      ),
    );
  }
  if (repaymentFee != null) {
    details.add(
      TransactionDetailRecord(
        id: lineNo,
        transactionId: 1,
        lineNo: lineNo++,
        type: TransactionDetailType.repaymentFee,
        amount: repaymentFee,
      ),
    );
  }

  return TransactionListItem(
    id: 1,
    rootTransactionId: 1,
    businessPurpose: BusinessPurpose.dailyExpense,
    businessState: BusinessState.current,
    occurredAt: DateTime(2026, 5, 12, 8, 30),
    primaryAmount: const Money(minorUnits: 1000),
    entries: const [],
    details: details,
    isExcludedFromStats: isExcludedFromStats,
    isExcludedFromBudget: isExcludedFromBudget,
    refundedTotal: refundedTotal,
    reimbursementReceivedTotal: reimbursementReceivedTotal,
    reimbursementGapIncome: reimbursementGapIncome,
    reimbursementGapExpense: reimbursementGapExpense,
  );
}
