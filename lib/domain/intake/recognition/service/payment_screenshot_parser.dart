import '../recognized_payment.dart';
import '../screenshot_scene_information.dart';
import 'screenshot_text_document.dart';

/// Generic scene recognition and information extraction over one OCR document.
class PaymentScreenshotParser {
  const PaymentScreenshotParser();

  RecognizedPayment parse(List<RecognizedTextBlock> blocks) {
    final document = ScreenshotTextDocument(blocks);
    final scene = _recognizeScene(document);
    final facts = _extractSceneInformation(document, scene);
    final categoryValues =
        [facts.categoryName, facts.counterparty, facts.product]
            .whereType<ScreenshotTextValue>()
            .where((value) => value.isReliable)
            .toList();
    return RecognizedPayment(
      scene: facts.scene,
      direction: facts.direction,
      amount: facts.amount,
      occurredAt: facts.occurredAt,
      counterparty: facts.counterparty?.text,
      product: facts.product?.text,
      paymentMethod: facts.paymentMethod?.text,
      paymentMethodReliable: facts.paymentMethod?.isReliable == true,
      transferFromAccount: facts.transferFromAccount?.text,
      transferFromAccountReliable:
          facts.transferFromAccount?.isReliable == true,
      transferToAccount: facts.transferToAccount?.text,
      transferToAccountReliable: facts.transferToAccount?.isReliable == true,
      categoryName: facts.categoryName?.text,
      categoryNameReliable: facts.categoryName?.isReliable == true,
      accountMatchingText: facts.paymentMethod?.isReliable == true
          ? facts.paymentMethod!.text
          : document.text,
      categoryMatchingText: categoryValues.isEmpty
          ? document.text
          : categoryValues.map((value) => value.text).join('\n'),
      needsReview:
          facts.needsReview ||
          facts.occurredAt == null ||
          facts.amount == null ||
          facts.scene == PaymentScreenshotScene.unknown,
    );
  }
}

_SceneRecognition _recognizeScene(ScreenshotTextDocument document) {
  final headline = document.headlineAmount();
  final labeled = document.field(const [
    '实付金额',
    '实际支付',
    '支付金额',
    '实付款',
    '实收金额',
    '实际到账',
    '到账金额',
    '扣款金额',
    '付款金额',
    '收款金额',
    '转出金额',
    '交易金额',
  ], allowBelow: true);
  final labeledDirection = labeled == null
      ? null
      : RegExp(r'实收|收款|到账').hasMatch(labeled.label ?? '')
      ? RecognizedPaymentDirection.income
      : RegExp(r'实付|实际支付|支付金额|实付款|扣款|付款').hasMatch(labeled.label ?? '')
      ? RecognizedPaymentDirection.expense
      : null;
  final direction = headline?.direction ?? labeledDirection;
  final scene = _classifyScene(
    document.sceneSignals(allowBelow: true),
    direction,
    labeledDirection,
    hasPaymentMethod: document.hasLabel('付款方式') || document.hasLabel('支付方式'),
  );
  return _SceneRecognition(
    scene: scene,
    direction: switch (scene) {
      PaymentScreenshotScene.expense => RecognizedPaymentDirection.expense,
      PaymentScreenshotScene.income => RecognizedPaymentDirection.income,
      _ => direction,
    },
    headlineAmount: headline,
    labeledAmount: labeled,
  );
}

ScreenshotSceneInformation _extractSceneInformation(
  ScreenshotTextDocument document,
  _SceneRecognition scene,
) {
  final labeledValue = parseScreenshotAmount(scene.labeledAmount?.text);
  final amount =
      scene.headlineAmount?.amount ??
      (labeledValue != null && labeledValue.minorUnits > 0
          ? labeledValue
          : null);
  final time =
      (scene.scene == PaymentScreenshotScene.transfer
          ? document.field(const ['转出时间', '转出资金', '当前状态转出资金'], allowBelow: true)
          : null) ??
      document.field(const [
        '支付时间',
        '交易时间',
        '收款时间',
        '付款时间',
        '入账时间',
        '时间',
      ], allowBelow: true);
  final occurredAt = parseScreenshotDate(time?.text) ?? document.uniqueTime();
  final counterparty =
      document.field(
        const ['商户全称', '收款方全称', '交易对方', '商户名称', '收款方', '付款方', '商家', '商户'],
        allowBelow: true,
        allowWrapped: true,
      ) ??
      document.headlineCounterparty(scene.headlineAmount);
  final product = document.field(const [
    '商品说明',
    '商品名称',
    '商品信息',
    '商品',
    '交易说明',
    '交易备注',
  ], allowBelow: true);
  var method = document.field(const [
    '付款方式',
    '支付方式',
    '收款方式',
    '付款账户',
    '支付账户',
    '收款账户',
    '收款账号',
    '到账银行卡',
    '支付渠道',
  ], allowBelow: true);
  if (method == null) {
    var status = document.field(const [
      '当前状态',
      '交易状态',
      '支付状态',
      '状态',
    ], allowBelow: true);
    status ??= document.headerRows
        .where((row) => row.text.replaceAll(' ', '').contains('已存入零钱'))
        .map((row) => ScreenshotTextValue(row.text, row.confidence))
        .firstOrNull;
    if (status != null && status.text.replaceAll(' ', '').contains('已存入零钱')) {
      method = ScreenshotTextValue('零钱', status.confidence);
    }
  }
  final categoryName = document.categoryField();
  final transferAccounts = _extractTransferAccounts(document, scene.scene);
  return ScreenshotSceneInformation(
    scene: scene.scene,
    direction: scene.direction,
    amount: amount,
    occurredAt: occurredAt,
    counterparty: counterparty,
    product: product,
    paymentMethod: method,
    transferFromAccount: transferAccounts.from,
    transferToAccount: transferAccounts.to,
    categoryName: categoryName,
    needsReview:
        (scene.headlineAmount?.confidence ??
                scene.labeledAmount?.confidence ??
                1) <
            0.8 ||
        time != null && !time.isReliable ||
        [
          counterparty,
          product,
          method,
          transferAccounts.from,
          transferAccounts.to,
          categoryName,
        ].any((value) => value != null && !value.isReliable) ||
        time == null &&
            document.rows.any(
              (row) =>
                  row.confidence < 0.8 && parseScreenshotDate(row.text) != null,
            ),
  );
}

({ScreenshotTextValue? from, ScreenshotTextValue? to}) _extractTransferAccounts(
  ScreenshotTextDocument document,
  PaymentScreenshotScene scene,
) {
  if (scene != PaymentScreenshotScene.transfer) return (from: null, to: null);
  ScreenshotTextValue? from;
  ScreenshotTextValue? to;
  for (final row in document.headerRows) {
    final title = RegExp(
      r'^(.+?)\s*转\s*出\s*[-－—]?\s*到\s*(.+)$',
    ).firstMatch(row.text);
    if (title == null) continue;
    from = ScreenshotTextValue(title[1]!.trim(), row.confidence);
    to = ScreenshotTextValue(title[2]!.trim(), row.confidence);
    break;
  }
  final bank = document.field(const ['到账银行卡'], allowBelow: true);
  if (from == null && !(document.hasLabel('转出金额') && bank != null)) {
    return (from: null, to: null);
  }
  // A complete title retains the card suffix for explicit user keyword rules.
  if (to?.isReliable != true) {
    to = bank ?? document.field(const ['收款账号', '收款账户'], allowBelow: true) ?? to;
  }
  return (from: from, to: to);
}

PaymentScreenshotScene _classifyScene(
  String signals,
  RecognizedPaymentDirection? direction,
  RecognizedPaymentDirection? labeledDirection, {
  required bool hasPaymentMethod,
}) {
  if (RegExp(
    r'支付失败|交易失败|付款失败|支付中|待支付|等待付款|未支付|已关闭|已取消|交易取消',
  ).hasMatch(signals)) {
    return PaymentScreenshotScene.unpaid;
  }
  if (RegExp(r'退款|退回').hasMatch(signals)) return PaymentScreenshotScene.refund;
  if (RegExp(r'还款|还贷').hasMatch(signals)) {
    return PaymentScreenshotScene.repayment;
  }
  final received = RegExp(r'收款成功|已收款|实收|已到账|已存入零钱|收款到账').hasMatch(signals);
  final paid = RegExp(r'支付成功|付款成功|支付完成|扣款成功').hasMatch(signals);
  final receivedTransfer =
      received &&
      direction != RecognizedPaymentDirection.expense &&
      !paid &&
      RegExp(r'转账-?来自').hasMatch(signals);
  if (RegExp(r'转账|转入|转出|提现').hasMatch(signals) && !receivedTransfer) {
    return PaymentScreenshotScene.transfer;
  }
  if (received && direction == RecognizedPaymentDirection.expense ||
      paid && direction == RecognizedPaymentDirection.income ||
      received && paid) {
    return PaymentScreenshotScene.unknown;
  }
  final resolved =
      direction ??
      (received
          ? RecognizedPaymentDirection.income
          : paid
          ? RecognizedPaymentDirection.expense
          : hasPaymentMethod
          ? RecognizedPaymentDirection.expense
          : null);
  final successful =
      received || paid || signals.contains('交易成功') || labeledDirection != null;
  if (!successful) return PaymentScreenshotScene.unknown;
  return switch (resolved) {
    RecognizedPaymentDirection.expense => PaymentScreenshotScene.expense,
    RecognizedPaymentDirection.income => PaymentScreenshotScene.income,
    null => PaymentScreenshotScene.unknown,
  };
}

class _SceneRecognition {
  const _SceneRecognition({
    required this.scene,
    this.direction,
    this.headlineAmount,
    this.labeledAmount,
  });

  final PaymentScreenshotScene scene;
  final RecognizedPaymentDirection? direction;
  final ScreenshotAmount? headlineAmount;
  final ScreenshotTextValue? labeledAmount;
}
