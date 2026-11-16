import '../../../../domain/intake/import/import_models.dart'
    show ImportCategoryKind;
import '../../../../domain/intake/recognition/port/payment_screenshot_ocr.dart';
import '../../../../domain/intake/recognition/recognized_payment.dart';
import '../../../../domain/intake/recognition/service/payment_screenshot_parser.dart';
import '../../../../domain/intake/rules/recognition_rule.dart';
import '../../../../domain/intake/rules/recognition_rule_catalog.dart';

class RecognizePaymentScreenshot {
  const RecognizePaymentScreenshot({
    required PaymentScreenshotOcr ocr,
    required PaymentScreenshotParser parser,
    required Future<RecognitionRuleCatalog> Function() loadRules,
  }) : _ocr = ocr,
       _parser = parser,
       _loadRules = loadRules;

  final PaymentScreenshotOcr _ocr;
  final PaymentScreenshotParser _parser;
  final Future<RecognitionRuleCatalog> Function() _loadRules;

  Future<RecognizedPayment> call(String shareId) async {
    final payment = _parser.parse(await _ocr.recognize(shareId));
    if (!payment.isOrdinary) return payment;
    final catalog = await _loadRules();
    final categoryKind = switch (payment.direction) {
      RecognizedPaymentDirection.expense => ImportCategoryKind.expense,
      RecognizedPaymentDirection.income => ImportCategoryKind.income,
      null => null,
    };
    return payment.withRuleMatches(
      account: catalog.match(
        text: payment.accountMatchingText,
        kind: RecognitionRuleKind.account,
      ),
      category: catalog.match(
        text: payment.categoryMatchingText,
        categoryKind: categoryKind,
      ),
    );
  }
}
