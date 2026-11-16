import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../app/capture_intake_provider.dart';
import '../../../app/provider.dart';
import '../../../app/recognition_rules_provider.dart';
import '../../../application/intake/intake_recognition_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
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
  CaptureReviewViewModel(this.sessionKey);

  final Object sessionKey;

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
    final transactionQuery = ref.read(transactionQueryServiceProvider);
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
        final occurredAt = payment.occurredAt ?? DateTime.now();
        final duplicate = payment.occurredAt == null
            ? false
            : await _hasDuplicate(payment, transactionQuery);
        final notices = <String>[
          '截图识别完成，请核对后保存。',
          if (payment.occurredAt == null) '未识别到交易时间，暂填当前时间。',
          if (payment.needsReview && payment.occurredAt != null)
            '部分文字识别不确定，请重点核对金额和时间。',
          if (settlement == null)
            '请选择付款或收款账户${payment.paymentMethod == null ? '。' : '（截图：${payment.paymentMethod}）。'}',
          if (categoryId == null) '请选择分类。',
          if (duplicate) '已有相同时间、金额和方向的交易，可能重复，请核对。',
        ];
        final noteParts = <String>{
          if (payment.product != null) payment.product!,
          if (counterpartyId == null && payment.counterparty != null)
            payment.counterparty!,
        };
        return CaptureReviewResult(
          payment: payment,
          reviewMessage: notices.join('\n'),
          prefill: TransactionFormPrefill(
            amount: payment.amount!,
            occurredAt: occurredAt,
            note: noteParts.join(' · '),
            reviewMessage: notices.join('\n'),
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

  Future<bool> _hasDuplicate(
    RecognizedPayment payment,
    TransactionQueryService query,
  ) async {
    final time = payment.occurredAt!;
    final transactions = await query.findTransactions(
      TransactionListQuery(
        occurredFrom: time,
        occurredUntil: time.add(const Duration(seconds: 1)),
        limit: null,
        scope: TransactionScopeFilter.all,
      ),
    );
    final purpose = payment.direction == RecognizedPaymentDirection.expense
        ? BusinessPurpose.dailyExpense
        : BusinessPurpose.dailyIncome;
    return transactions.any(
      (tx) =>
          tx.businessPurpose == purpose && tx.primaryAmount == payment.amount,
    );
  }
}

String _compact(String value) => value
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAll('（', '(')
    .replaceAll('）', ')')
    .toLowerCase();

String _manualReviewMessage(RecognizedPayment payment) {
  final message = switch (payment.scene) {
    PaymentScreenshotScene.unpaid => '截图中的交易未成功，不生成记账建议。请核对交易状态。',
    PaymentScreenshotScene.refund => '识别为退款，请从原交易发起退款。',
    PaymentScreenshotScene.transfer => '识别为转账，请核对转出、转入账户后手动记录。',
    PaymentScreenshotScene.repayment => '识别为还款，请从对应负债账户或账单发起还款。',
    PaymentScreenshotScene.expense ||
    PaymentScreenshotScene.income => '未能确定实际交易金额，请使用完整截图或手动填写。',
    PaymentScreenshotScene.unknown => '未能确定记账场景或收支方向，请选择场景手动记账。',
  };
  return [
    message,
    if (payment.amount != null) '识别金额：${payment.amount!.format()}',
    if (payment.paymentMethod != null) '截图账户：${payment.paymentMethod!}',
  ].join('\n');
}
