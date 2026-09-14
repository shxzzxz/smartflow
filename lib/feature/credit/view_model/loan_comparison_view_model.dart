import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'loan_configuration_view_model.dart';

part 'loan_comparison_view_model.g.dart';

class LoanComparisonState {
  const LoanComparisonState({this.first, this.second});
  final LoanConfiguration? first, second;
}

@riverpod
class LoanComparisonViewModel extends _$LoanComparisonViewModel {
  @override
  LoanComparisonState build({LoanConfiguration? initial}) =>
      LoanComparisonState(first: initial);

  void setConfiguration(int index, LoanConfiguration configuration) {
    assert(index == 0 || index == 1);
    state = index == 0
        ? LoanComparisonState(first: configuration, second: state.second)
        : LoanComparisonState(first: state.first, second: configuration);
  }

  void copyFirstToSecond() {
    if (state.first == null) return;
    state = LoanComparisonState(first: state.first, second: state.first);
  }
}
