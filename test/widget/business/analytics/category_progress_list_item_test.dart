import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/chart.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/widget/business/analytics/category_progress_list_item.dart';

void main() {
  testWidgets('aligns fixed comparison and amount columns across rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 296,
              child: Builder(
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _row(
                      context: context,
                      id: 'large',
                      title: '餐饮',
                      comparison: '↑97 · +8%',
                      amount: '1,234.56',
                      percentage: '86.1%',
                    ),
                    _row(
                      context: context,
                      id: 'small',
                      title: '一个很长很长的分类名称用于观察省略',
                      comparison: '持平',
                      amount: '1.2万',
                      percentage: '13.9%',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final largeComparison = tester.getRect(
      find.byKey(const ValueKey('comparison-large')),
    );
    final smallComparison = tester.getRect(
      find.byKey(const ValueKey('comparison-small')),
    );
    final largeTrailing = tester.getRect(
      find.byKey(const ValueKey('trailing-large')),
    );
    final smallTrailing = tester.getRect(
      find.byKey(const ValueKey('trailing-small')),
    );

    expect(
      largeComparison.left,
      moreOrLessEquals(smallComparison.left, epsilon: .01),
    );
    expect(
      largeTrailing.right,
      moreOrLessEquals(smallTrailing.right, epsilon: .01),
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _row({
  required BuildContext context,
  required String id,
  required String title,
  required String comparison,
  required String amount,
  required String percentage,
}) {
  return CategoryProgressListItem(
    title: title,
    progress: .4,
    color: Theme.of(context).colorScheme.primary,
    titleWidth: AppChartGeometry.categoryNameColumnWidth,
    titleTrailingGap: AppSpacing.space4,
    titleTrailing: Text(
      comparison,
      key: ValueKey('comparison-$id'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: context.appTextStyles.listSupporting,
    ),
    trailingGap: AppSpacing.space4,
    trailingWidth: AppChartGeometry.categoryAmountColumnWidth,
    trailing: Column(
      key: ValueKey('trailing-$id'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(amount, style: context.appTextStyles.amountList),
        const SizedBox(height: 2),
        Text(percentage, style: context.appTextStyles.listSupporting),
      ],
    ),
    onTap: () {},
  );
}
