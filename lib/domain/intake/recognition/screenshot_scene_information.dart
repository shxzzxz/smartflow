import '../../../core/money/money.dart';
import 'recognized_payment.dart';

class ScreenshotTextValue {
  const ScreenshotTextValue(this.text, this.confidence, {this.label});
  final String text;
  final double confidence;
  final String? label;
  bool get isReliable => text.isNotEmpty && confidence >= 0.8;
}

class ScreenshotAmount {
  const ScreenshotAmount({
    required this.amount,
    required this.text,
    required this.confidence,
    this.direction,
  });
  final Money amount;
  final String text;
  final double confidence;
  final RecognizedPaymentDirection? direction;
}

/// Information extracted from a screenshot after its scene is recognized.
class ScreenshotSceneInformation {
  const ScreenshotSceneInformation({
    this.scene = PaymentScreenshotScene.unknown,
    this.direction,
    this.amount,
    this.occurredAt,
    this.counterparty,
    this.product,
    this.paymentMethod,
    this.categoryName,
    this.needsReview = false,
  });
  final PaymentScreenshotScene scene;
  final RecognizedPaymentDirection? direction;
  final Money? amount;
  final DateTime? occurredAt;
  final ScreenshotTextValue? counterparty;
  final ScreenshotTextValue? product;
  final ScreenshotTextValue? paymentMethod;
  final ScreenshotTextValue? categoryName;
  final bool needsReview;
}
