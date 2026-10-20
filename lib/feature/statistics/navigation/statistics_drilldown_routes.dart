import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../presentation/statistics_presentation.dart';
import '../view_model/statistics_view_model.dart';

void openStatisticsCategoryDetail(
  BuildContext context, {
  required StatisticsBreakdownItem item,
  required StatisticsCategoryKind categoryKind,
  required DateTime from,
  required DateTime until,
}) {
  context.push(
    Uri(
      path: '/statistics/category',
      queryParameters: {
        'categoryId': item.id,
        'categoryKind': categoryKind.name,
        'from': from.toIso8601String(),
        'until': until.toIso8601String(),
      },
    ).toString(),
  );
}

void openStatisticsCategoryTransactions(
  BuildContext context, {
  required StatisticsBreakdownItem item,
  required DateTime from,
  required DateTime until,
}) {
  context.push(
    Uri(
      path: '/statistics/transactions',
      queryParameters: {
        'categoryId': item.id,
        if (item.isUnsubdivided) 'categoryScope': 'own',
        'from': from.toIso8601String(),
        'until': until.toIso8601String(),
        'title': item.title,
        'scope': StatisticsDrilldownScope.cashflow.name,
      },
    ).toString(),
  );
}

void openStatisticsTagTransactions(
  BuildContext context, {
  required StatisticsBreakdownItem item,
  required DateTime from,
  required DateTime until,
}) {
  context.push(
    Uri(
      path: '/statistics/transactions',
      queryParameters: {
        if (item.id == untaggedTagItemId) 'untagged': '1' else 'tagId': item.id,
        'from': from.toIso8601String(),
        'until': until.toIso8601String(),
        'title': item.title,
        'accountType': item.accountType.name,
        'scope': StatisticsDrilldownScope.cashflow.name,
      },
    ).toString(),
  );
}
