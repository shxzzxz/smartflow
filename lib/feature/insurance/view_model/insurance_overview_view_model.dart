import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/insurance/insurance_query_api.dart';
import '../../../core/money/money.dart';

part 'insurance_overview_view_model.g.dart';

@riverpod
class InsuranceOverviewViewModel extends _$InsuranceOverviewViewModel {
  /// 年度保费口径尚未接入，先固定在视图模型内，后续替换为查询投影。
  static const _placeholderAnnualPremium = Money(minorUnits: 1200000);

  @override
  Future<InsuranceOverviewViewState> build() async {
    final overview = await ref
        .watch(insuranceCoverageQueryServiceProvider)
        .insuranceOverview();
    return InsuranceOverviewViewState(
      overview: overview,
      annualPremium: _placeholderAnnualPremium,
    );
  }
}

class InsuranceOverviewViewState {
  const InsuranceOverviewViewState({
    required this.overview,
    required this.annualPremium,
  });

  final InsuranceOverview overview;
  final Money annualPremium;
}
