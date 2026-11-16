import '../recognized_payment.dart';

abstract interface class PaymentScreenshotOcr {
  Future<List<RecognizedTextBlock>> recognize(String shareId);
}
