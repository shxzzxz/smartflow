import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/intake/recognition/command/recognize_payment_screenshot.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/domain/intake/recognition/port/payment_screenshot_ocr.dart';
import 'package:smartflow/domain/intake/recognition/recognized_payment.dart';
import 'package:smartflow/domain/intake/recognition/recognition_error_code.dart';
import 'package:smartflow/domain/intake/recognition/service/payment_screenshot_parser.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule_catalog.dart';

void main() {
  Future<RecognizedPayment> recognize(
    List<RecognizedTextBlock> blocks,
    List<RecognitionRule> rules,
  ) => RecognizePaymentScreenshot(
    ocr: _Ocr(() async => blocks),
    parser: const PaymentScreenshotParser(),
    loadRules: () async => RecognitionRuleCatalog(rules: rules),
  )('image');

  test(
    'reliable payment method is matched without falling back after no keyword hit',
    () async {
      final result =
          await recognize(_payment(method: '银行卡(1234)', product: '零钱咖啡'), [
            _rule('change', RecognitionRuleKind.account, '零钱'),
            _rule('coffee', RecognitionRuleKind.category, '咖啡'),
          ]);
      expect(result.accountRule, isNull);
      expect(result.categoryRule!.ruleId, 'coffee');
      expect(result.accountMatchingText, '银行卡(1234)');
    },
  );

  test(
    'missing payment region uses full text while category uses its reliable region',
    () async {
      final result = await recognize(_payment(product: '零钱咖啡'), [
        _rule('change', RecognitionRuleKind.account, '零钱'),
        _rule('coffee', RecognitionRuleKind.category, '咖啡'),
      ]);
      expect(result.accountRule!.ruleId, 'change');
      expect(result.categoryRule!.ruleId, 'coffee');
    },
  );

  test(
    'category matching does not inspect account and status when merchant/product were extracted',
    () async {
      final result =
          await recognize(_payment(method: '银行卡(1234)', product: '虚构商品'), [
            _rule('bank', RecognitionRuleKind.category, '银行卡'),
            _rule('success', RecognitionRuleKind.category, '支付成功'),
          ]);
      expect(result.categoryRule, isNull);
    },
  );

  test(
    'category matching can use full text when semantic merchant/product regions are absent',
    () async {
      final result = await recognize(
        [
          _block('支付宝', 20),
          _block('支付成功', 80),
          _block('-10.00', 145, height: 60),
          _block('付款方式 银行卡', 260),
          _block('备注 咖啡', 320),
        ],
        [_rule('coffee', RecognitionRuleKind.category, '咖啡')],
      );
      expect(result.counterparty, isNull);
      expect(result.product, isNull);
      expect(result.categoryRule!.ruleId, 'coffee');
    },
  );

  test('screenshot branding does not activate source-scoped rules', () async {
    for (final brand in ['付款凭证', '微信支付', '支付宝', '抖音支付']) {
      final result = await recognize(_payment(brand: brand, method: '零钱'), [
        for (final source in RecognitionRuleSource.values) ...[
          _rule(
            'scoped-account-${source.name}',
            RecognitionRuleKind.account,
            '零钱',
          ).copyWith(source: source),
          _rule(
            'scoped-category-${source.name}',
            RecognitionRuleKind.category,
            '咖啡',
          ).copyWith(source: source),
        ],
        _rule(
          'all-account',
          RecognitionRuleKind.account,
          '零钱',
        ).copyWith(priority: 80),
        _rule(
          'all-category',
          RecognitionRuleKind.category,
          '咖啡',
        ).copyWith(priority: 80),
      ]);
      expect(result.accountRule!.ruleId, 'all-account', reason: brand);
      expect(result.categoryRule!.ruleId, 'all-category', reason: brand);
    }
  });

  test(
    'source-scoped rules alone do not provide screenshot suggestions',
    () async {
      final result = await recognize(_payment(brand: '微信支付', method: '零钱'), [
        _rule(
          'wechat-account',
          RecognitionRuleKind.account,
          '零钱',
        ).copyWith(source: RecognitionRuleSource.wechat),
        _rule(
          'wechat-category',
          RecognitionRuleKind.category,
          '咖啡',
        ).copyWith(source: RecognitionRuleSource.wechat),
      ]);
      expect(result.accountRule, isNull);
      expect(result.categoryRule, isNull);
    },
  );

  test(
    'low-confidence regions trigger full-text matching and visible review',
    () async {
      final blocks = _payment(product: '零钱咖啡');
      blocks.add(_block('付款方式 未知卡', 480, confidence: .6));
      final result = await recognize(blocks, [
        _rule('change', RecognitionRuleKind.account, '零钱'),
      ]);
      expect(result.paymentMethodReliable, isFalse);
      expect(result.accountRule!.ruleId, 'change');
      expect(result.needsReview, isTrue);
    },
  );

  test('each recognition loads current rule order', () async {
    var loads = 0;
    final command = RecognizePaymentScreenshot(
      ocr: _Ocr(() async => _payment(product: '咖啡')),
      parser: const PaymentScreenshotParser(),
      loadRules: () async {
        loads++;
        return RecognitionRuleCatalog(
          rules: [
            _rule(
              loads == 1 ? 'first' : 'second',
              RecognitionRuleKind.category,
              '咖啡',
            ),
          ],
        );
      },
    );
    expect((await command('a')).categoryRule!.ruleId, 'first');
    expect((await command('b')).categoryRule!.ruleId, 'second');
    expect(loads, 2);
  });

  test('OCR failures propagate and do not run rule inference', () async {
    for (final failure in [
      InfrastructureException(RecognitionErrorCode.ocrFailed),
      StateError('OCR defect'),
      Exception('OCR execution failed'),
    ]) {
      var loads = 0;
      final command = RecognizePaymentScreenshot(
        ocr: _Ocr(() async => throw failure),
        parser: const PaymentScreenshotParser(),
        loadRules: () async {
          loads++;
          return RecognitionRuleCatalog(rules: const []);
        },
      );
      await expectLater(command('image'), throwsA(same(failure)));
      expect(loads, 0);
    }
  });
}

RecognitionRule _rule(String id, RecognitionRuleKind kind, String keyword) =>
    RecognitionRule(
      id: id,
      kind: kind,
      keywords: [keyword],
      priority: 100,
      targetAccountId: id,
    );

List<RecognizedTextBlock> _payment({
  String brand = '交易详情',
  String? method,
  String product = '咖啡',
}) => [
  _block(brand, 20),
  _block('示例商户', 80),
  _block('-10.00', 145, height: 60),
  _block('支付成功', 240),
  _block('支付时间 2026-04-05 13:20:11', 300),
  _block('商品说明 $product', 360),
  if (method != null) _block('付款方式 $method', 420),
];

RecognizedTextBlock _block(
  String text,
  double top, {
  double height = 30,
  double confidence = .99,
}) => RecognizedTextBlock(
  text: text,
  confidence: confidence,
  left: 20,
  top: top,
  right: 300,
  bottom: top + height,
);

class _Ocr implements PaymentScreenshotOcr {
  const _Ocr(this.action);
  final Future<List<RecognizedTextBlock>> Function() action;
  @override
  Future<List<RecognizedTextBlock>> recognize(String shareId) => action();
}
