import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../core/money/money.dart';

part 'installment_schedule_draft.freezed.dart';

@freezed
abstract class InstallmentContractDraftRow with _$InstallmentContractDraftRow {
  const InstallmentContractDraftRow._();

  const factory InstallmentContractDraftRow({
    required int periodNo,
    required DateTime date,
    required Money principal,
    required Money interest,
    required Money fee,
    required InstallmentScheduleStatus status,
    String? scheduleId,
  }) = _InstallmentContractDraftRow;

  Money get total => principal + interest + fee;
}

enum InstallmentAmountField { principal, interest, fee }
