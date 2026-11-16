import '../../../core/money/money.dart';
import '../rules/recognition_rule_catalog.dart' show RecognitionRuleMatch;

enum RecognizedPaymentDirection { expense, income }

enum PaymentScreenshotScene {
  expense,
  income,
  refund,
  transfer,
  repayment,
  unpaid,
  unknown,
}

/// OCR output retains layout and confidence for semantic-region extraction.
class RecognizedTextBlock {
  const RecognizedTextBlock({
    required this.text,
    required this.confidence,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
  final String text;
  final double confidence;
  final double left;
  final double top;
  final double right;
  final double bottom;
  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;
}

/// A possibly incomplete suggestion; recognition never creates ledger data.
class RecognizedPayment {
  const RecognizedPayment({
    this.direction,
    this.amount,
    PaymentScreenshotScene? scene,
    this.occurredAt,
    this.counterparty,
    this.product,
    this.paymentMethod,
    this.paymentMethodReliable = true,
    this.categoryName,
    this.categoryNameReliable = true,
    this.accountMatchingText = '',
    this.categoryMatchingText = '',
    this.categoryPath = const [],
    this.accountRule,
    this.categoryRule,
    this.needsReview = false,
  }) : scene =
           scene ??
           (direction == RecognizedPaymentDirection.expense
               ? PaymentScreenshotScene.expense
               : direction == RecognizedPaymentDirection.income
               ? PaymentScreenshotScene.income
               : PaymentScreenshotScene.unknown);

  final PaymentScreenshotScene scene;
  final RecognizedPaymentDirection? direction;
  final Money? amount;
  final DateTime? occurredAt;
  final String? counterparty;
  final String? product;
  final String? paymentMethod;
  final bool paymentMethodReliable;
  final String? categoryName;
  final bool categoryNameReliable;
  final String accountMatchingText;
  final String categoryMatchingText;
  final List<String> categoryPath;
  final RecognitionRuleMatch? accountRule;
  final RecognitionRuleMatch? categoryRule;
  final bool needsReview;

  bool get isOrdinary =>
      scene == PaymentScreenshotScene.expense ||
      scene == PaymentScreenshotScene.income;
  bool get canPrefill =>
      (scene == PaymentScreenshotScene.expense &&
              direction == RecognizedPaymentDirection.expense ||
          scene == PaymentScreenshotScene.income &&
              direction == RecognizedPaymentDirection.income) &&
      amount != null &&
      amount!.minorUnits > 0;

  RecognizedPayment withRuleMatches({
    RecognitionRuleMatch? account,
    RecognitionRuleMatch? category,
  }) => RecognizedPayment(
    scene: scene,
    direction: direction,
    amount: amount,
    occurredAt: occurredAt,
    counterparty: counterparty,
    product: product,
    paymentMethod: paymentMethod,
    paymentMethodReliable: paymentMethodReliable,
    categoryName: categoryName,
    categoryNameReliable: categoryNameReliable,
    accountMatchingText: accountMatchingText,
    categoryMatchingText: categoryMatchingText,
    categoryPath: category == null || category.isFallback
        ? const []
        : category.path,
    accountRule: account,
    categoryRule: category,
    needsReview: needsReview,
  );
}
