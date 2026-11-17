import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../app/capture_intake_provider.dart';
import '../../../app/provider.dart';
import '../../../app/recognition_rules_provider.dart';
import '../../../application/intake/intake_recognition_api.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../../transaction/presentation/transaction_form_prefill.dart';

class CaptureReviewResult {
  const CaptureReviewResult({
    required this.payment,
    required this.reviewMessage,
    this.prefill,
    this.manualAction,
  });

  final RecognizedPayment payment;
  final TransactionFormPrefill? prefill;
  final String reviewMessage;
  final CaptureManualAction? manualAction;
}

enum CaptureManualAction {
  expense,
  income,
  transfer,
  transactions,
  accounts,
  chooseScene,
}

final captureReviewViewModelProvider = NotifierProvider.autoDispose
    .family<CaptureReviewViewModel, CaptureReviewState, Object>(
      CaptureReviewViewModel.new,
    );

class CaptureReviewState {
  const CaptureReviewState({
    this.recognizing = false,
    this.pickingImage = false,
    this.error,
    this.review,
  });

  final bool recognizing;
  final bool pickingImage;
  final UiError? error;
  final CaptureReviewResult? review;
}

class CaptureReviewViewModel extends Notifier<CaptureReviewState> {
  CaptureReviewViewModel(this.sessionKey, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Object sessionKey;
  final DateTime Function() _now;

  @override
  CaptureReviewState build() => const CaptureReviewState();

  Future<UiActionOutcome<String?>?> pickImage() async {
    if (state.recognizing || state.pickingImage) return null;
    state = const CaptureReviewState(pickingImage: true);
    final picker = ref.read(paymentScreenshotImagePickerProvider);
    final outcome = await guardUiAction(
      Logger('feature.capture'),
      'Select payment screenshot',
      picker.pickImage,
    );
    if (ref.mounted) {
      state = CaptureReviewState(
        error: outcome is UiActionFailure<String?> ? outcome.error : null,
      );
    }
    return outcome;
  }

  Future<UiActionOutcome<CaptureReviewResult>?> recognize(
    String shareId,
  ) async {
    if (state.recognizing || state.pickingImage) return null;
    state = const CaptureReviewState(recognizing: true);
    final recognizer = ref.read(recognizePaymentScreenshotProvider);
    final rules = ref.read(recognitionRulesAppServiceProvider);
    final counterpartyQuery = ref.read(counterpartyApplicationServiceProvider);
    final duplicateQuery = ref.read(paymentDuplicateQueryServiceProvider);
    final outcome = await guardUiAction(
      Logger('feature.capture'),
      'Recognize payment screenshot',
      () async {
        final payment = await recognizer(shareId);
        if (!payment.canPrefill) {
          return CaptureReviewResult(
            payment: payment,
            reviewMessage: _manualReviewMessage(payment),
            manualAction: switch (payment.scene) {
              PaymentScreenshotScene.expense => CaptureManualAction.expense,
              PaymentScreenshotScene.income => CaptureManualAction.income,
              PaymentScreenshotScene.transfer => CaptureManualAction.transfer,
              PaymentScreenshotScene.refund => CaptureManualAction.transactions,
              PaymentScreenshotScene.repayment => CaptureManualAction.accounts,
              _ => CaptureManualAction.chooseScene,
            },
          );
        }
        if (payment.scene == PaymentScreenshotScene.transfer) {
          final mapping = await rules.resolveTransfer(payment);
          return CaptureReviewResult(
            payment: payment,
            reviewMessage: '',
            prefill: TransactionFormPrefill(
              amount: payment.amount!,
              occurredAt: payment.occurredAt ?? _now(),
              note: payment.product ?? '',
              reviewMessage: '',
              fromAccountId: mapping.fromAccountId,
              toAccountId: mapping.toAccountId,
            ),
          );
        }
        final mapping = await rules.resolvePayment(payment);
        final counterparties = await counterpartyQuery.listCounterparties();
        final settlement = mapping.settlementAccountId;
        final categoryId = mapping.categoryId;
        final counterpartyMatches = counterparties
            .where(
              (item) =>
                  _compact(item.name) == _compact(payment.counterparty ?? ''),
            )
            .toList();
        final counterpartyId = counterpartyMatches.length == 1
            ? counterpartyMatches.single.id
            : null;
        final occurredAt = payment.occurredAt ?? _now();
        final duplicate = await duplicateQuery.hasPossibleDuplicate(payment);
        final reviewMessage = duplicate ? '可能重复，请核对。' : '';
        final noteParts = <String>{
          if (payment.product != null) payment.product!,
          if (counterpartyId == null && payment.counterparty != null)
            payment.counterparty!,
        };
        return CaptureReviewResult(
          payment: payment,
          reviewMessage: reviewMessage,
          prefill: TransactionFormPrefill(
            amount: payment.amount!,
            occurredAt: occurredAt,
            note: noteParts.join(' · '),
            reviewMessage: reviewMessage,
            settlementAccountId: settlement,
            categoryId: categoryId,
            counterpartyId: counterpartyId,
          ),
        );
      },
    );
    if (ref.mounted) {
      state = CaptureReviewState(
        error: outcome is UiActionFailure<CaptureReviewResult>
            ? outcome.error
            : null,
        review: outcome is UiActionSuccess<CaptureReviewResult>
            ? outcome.value
            : null,
      );
    }
    return outcome;
  }
}

String _compact(String value) => value
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAll('（', '(')
    .replaceAll('）', ')')
    .toLowerCase();

String _manualReviewMessage(RecognizedPayment payment) {
  return switch (payment.scene) {
    PaymentScreenshotScene.unpaid => '交易未成功，无法记账。',
    PaymentScreenshotScene.refund => '退款请从原交易发起。',
    PaymentScreenshotScene.transfer => '请手动记录转账。',
    PaymentScreenshotScene.repayment => '请前往账户记录还款。',
    PaymentScreenshotScene.expense ||
    PaymentScreenshotScene.income => '未识别到实际金额，请手动填写。',
    PaymentScreenshotScene.unknown => '未识别到收支场景，请手动记账。',
  };
}
