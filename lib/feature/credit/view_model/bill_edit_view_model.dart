import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/credit/credit_query_api.dart' as credit_query;
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/bill_query_providers.dart';
import 'bill_edit_form_state.dart';

part 'bill_edit_view_model.g.dart';

final _logger = Logger('feature.credit.bill_edit');

@riverpod
class BillEditViewModel extends _$BillEditViewModel {
  @override
  Future<BillEditFormState> build(String billId) async {
    final detail = await ref.watch(billDetailProvider(billId).future);
    final summary = detail?.summary;
    final consumption = detail?.items
        .where((item) => item.itemType == credit_query.BillItemType.consumption)
        .firstOrNull;
    final startDate = consumption?.startInclusive ?? summary?.windowStartDate;
    final billingDate = consumption?.endInclusive ?? summary?.windowBillingDate;
    final repaymentDate =
        consumption?.repaymentDate ?? summary?.windowRepaymentDate;
    if (summary == null || startDate == null || billingDate == null) {
      return const BillEditFormState();
    }
    return BillEditFormState(
      billItemId: consumption?.id,
      startDate: startDate,
      billingDate: billingDate,
      repaymentDate: repaymentDate,
    );
  }

  void setStartDate(DateTime value) {
    _updateLoaded((state) => state.copyWith(startDate: value));
  }

  void setBillingDate(DateTime value) {
    _updateLoaded((state) => state.copyWith(billingDate: value));
  }

  Future<SubmitOutcome> submit() async {
    final state = _loadedOrNull();
    if (state == null) {
      return const SubmitOutcome.failure(
        UiError(code: 'credit.bill.not_loaded', message: '账单尚未加载'),
      );
    }
    if (!state.startDate!.isBefore(state.billingDate!)) {
      return SubmitOutcome.failure(
        UiError(
          code: CreditErrorCode.billWindowInvalid.code,
          message: '起始日必须早于出账日',
        ),
      );
    }
    _setLoaded(state.copyWith(submitting: true));
    try {
      return await guardSubmit(_logger, 'Bill window edit submit', () async {
        final service = ref.read(creditBillGenerationAppServiceProvider);
        if (state.billItemId case final itemId?) {
          await service.updateConsumptionWindow(
            billId: billId,
            billItemId: itemId,
            startInclusive: state.startDate!,
            endInclusive: state.billingDate!,
          );
        } else {
          await service.updateBillWindow(
            billId: billId,
            startDate: state.startDate!,
            billingDate: state.billingDate!,
          );
        }
        ref.invalidate(billDetailProvider(billId));
        ref.invalidateSelf();
      });
    } finally {
      final current = _loadedOrNull();
      if (current != null) {
        _setLoaded(current.copyWith(submitting: false));
      }
    }
  }

  BillEditFormState? _loadedOrNull() {
    final value = state.asData?.value;
    return value != null && value.loaded ? value : null;
  }

  void _updateLoaded(
    BillEditFormState Function(BillEditFormState state) update,
  ) {
    final current = _loadedOrNull();
    if (current == null) return;
    _setLoaded(update(current));
  }

  void _setLoaded(BillEditFormState state) {
    this.state = AsyncData(state);
  }
}
