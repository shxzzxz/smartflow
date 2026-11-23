import 'dart:convert';

import 'package:logging/logging.dart';

import '../../../../domain/intake/import/import_models.dart'
    show ImportCategoryKind;
import '../../../../domain/intake/recognition/port/payment_screenshot_ocr.dart';
import '../../../../domain/intake/recognition/recognized_payment.dart';
import '../../../../domain/intake/recognition/service/payment_screenshot_parser.dart';
import '../../../../domain/intake/rules/recognition_rule.dart';
import '../../../../domain/intake/rules/recognition_rule_catalog.dart';

final _logger = Logger('application.intake.recognition');

class RecognizePaymentScreenshot {
  const RecognizePaymentScreenshot({
    required PaymentScreenshotOcr ocr,
    required PaymentScreenshotParser parser,
    required Future<RecognitionRuleCatalog> Function() loadRules,
    Future<RecognizedPayment> Function(RecognizedPayment)? resolveScene,
  }) : _ocr = ocr,
       _parser = parser,
       _loadRules = loadRules,
       _resolveScene = resolveScene;

  final PaymentScreenshotOcr _ocr;
  final PaymentScreenshotParser _parser;
  final Future<RecognitionRuleCatalog> Function() _loadRules;
  final Future<RecognizedPayment> Function(RecognizedPayment)? _resolveScene;

  Future<RecognizedPayment> call(String shareId) async {
    final parsed = _parser.parse(await _ocr.recognize(shareId));
    final payment = await _resolveScene?.call(parsed) ?? parsed;
    _logger.info(() {
      final fields = {
        'imageId': shareId,
        'scene': payment.scene.name,
        'direction': payment.direction?.name,
        'amount': payment.amount?.toString(),
        'occurredAt': payment.occurredAt?.toIso8601String(),
        'counterparty': payment.counterparty,
        'product': payment.product,
        'paymentMethod': payment.paymentMethod,
        'paymentMethodReliable': payment.paymentMethodReliable,
        'transferFromAccount': payment.transferFromAccount,
        'transferFromAccountReliable': payment.transferFromAccountReliable,
        'transferToAccount': payment.transferToAccount,
        'transferToAccountReliable': payment.transferToAccountReliable,
        'categoryName': payment.categoryName,
        'categoryNameReliable': payment.categoryNameReliable,
        'accountMatchingText': payment.accountMatchingText,
        'categoryMatchingText': payment.categoryMatchingText,
        'canPrefill': payment.canPrefill,
        'needsReview': payment.needsReview,
      };
      return 'Screenshot OCR parsed: ${jsonEncode(fields)}';
    });
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
