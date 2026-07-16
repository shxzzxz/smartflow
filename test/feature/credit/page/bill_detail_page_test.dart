import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/feature/credit/page/bill_detail_page.dart';
import 'package:smartflow/feature/credit/view_model/bill_detail_view_model.dart';

void main() {
  testWidgets('shows all bill actions for a settled empty bill', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final detail = BillDetailReadModel(
      summary: BillSummaryReadModel(
        id: 'bill',
        accountId: 'account',
        period: BillPeriod(year: 2026, month: 7),
        status: BillStatus.settled,
        expectedPrincipal: Money(minorUnits: 0),
        expectedInterest: Money(minorUnits: 0),
        expectedFee: Money(minorUnits: 0),
        pendingPrincipal: Money(minorUnits: 0),
        itemCount: 0,
        overdueItemCount: 0,
      ),
      items: const [],
      repayments: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billDetailViewModelProvider(
            'bill',
          ).overrideWith(() => _FixedBillDetailViewModel(detail)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const BillDetailPage(billId: 'bill'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final settledStatus = tester.widget<Text>(find.text('已了结'));
    final successColor =
        AppTheme.light().extension<AppThemeExtension>()!.success;
    expect(settledStatus.style?.color, successColor);
    expect(find.text('还款'), findsOneWidget);
    expect(find.text('账单分期'), findsOneWidget);
    expect(find.text('刷新'), findsOneWidget);
  });
}

class _FixedBillDetailViewModel extends BillDetailViewModel {
  _FixedBillDetailViewModel(this.detail);

  final BillDetailReadModel detail;

  @override
  Future<BillDetailReadModel?> build(String billId) async => detail;
}
