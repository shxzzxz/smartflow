import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/feature/credit/presentation/installment_stage_presentation.dart';
import 'package:smartflow/feature/credit/view_model/installment_terms_draft.dart';

void main() {
  test('presents automatic end dates and rate units without a widget', () {
    final stage = InstallmentStageDraft(
      id: 'stage-1',
      firstDate: DateTime(2026, 2, 28),
      inputs: const {
        StageInput.periods: '3',
        StageInput.interval: '1',
        StageInput.rate: '1.5',
      },
    );

    final presentation = presentInstallmentStageSummary(
      stage: stage,
      index: 0,
      stages: [stage],
      productMode: false,
      borrowingDate: DateTime(2026, 1, 15),
    );

    expect(presentation.endDate, DateTime(2026, 4, 28));
    expect(presentation.lines.first, contains('年利率 1.5%'));
    expect(presentation.lines.last, '2026-01-15 → 2026-04-28');
  });

  test('uses placeholders for incomplete stages and handles deferment', () {
    final stage = InstallmentStageDraft(
      id: 'stage-1',
      inputs: const {StageInput.interval: '1'},
    );
    final deferment = InstallmentStageDraft(
      id: 'stage-2',
      deferment: true,
      untilDate: DateTime(2026, 3, 1),
    );

    final incomplete = presentInstallmentStageSummary(
      stage: stage,
      index: 0,
      stages: [stage],
      productMode: false,
      borrowingDate: DateTime(2026, 1, 1),
    );
    final deferred = presentInstallmentStageSummary(
      stage: deferment,
      index: 1,
      stages: [stage, deferment],
      productMode: false,
      borrowingDate: DateTime(2026, 1, 1),
    );

    expect(incomplete.lines, contains('等额本息 · 年利率 0%'));
    expect(incomplete.lines.last, '2026-01-01 → 结束日期待确定');
    expect(deferred.lines, ['不还款、不计息', '起点待确定 → 2026-03-01']);
  });
}
