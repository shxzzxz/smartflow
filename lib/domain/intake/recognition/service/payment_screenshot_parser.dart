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
  final labeledText = normalizeScreenshotText(
    labeled?.text ?? '',
  ).replaceAll(RegExp(r'[¥￥\s]'), '');
  final signedLabelDirection = labeledText.startsWith('+')
      ? RecognizedPaymentDirection.income
      : labeledText.startsWith('-')
      ? RecognizedPaymentDirection.expense
      : null;
  final type = document.sceneTypeField(allowBelow: true)?.text ?? '';
  final incomingType = RegExp(r'收入|收款|工资|薪酬|奖金').hasMatch(type);
  final outgoingType = RegExp(r'支出|付款|消费|扣款').hasMatch(type);
  final typeDirection = incomingType == outgoingType
      ? null
      : incomingType
      ? RecognizedPaymentDirection.income
      : RecognizedPaymentDirection.expense;
  final direction =
      headline?.direction ??
      signedLabelDirection ??
      labeledDirection ??
      typeDirection;
  final directionConflict =
      [
        headline?.direction,
        signedLabelDirection,
        labeledDirection,
        typeDirection,
      ].whereType<RecognizedPaymentDirection>().toSet().length >
      1;
  final scene = _classifyScene(
    document.sceneSignals(allowBelow: true),
    direction,
    hasPaymentMethod: _paymentMethodLabels.any(document.hasLabel),
    hasReceiptMethod: _receiptMethodLabels.any(document.hasLabel),
    ownTransfer: _hasOwnTransferSignals(document),
    directionConflict: directionConflict,
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
  var method = document.field(switch (scene.scene) {
    PaymentScreenshotScene.income => const [
      ..._receiptMethodLabels,
      '交易卡号',
      '支付渠道',
    ],
    PaymentScreenshotScene.expense => const [
      ..._paymentMethodLabels,
      '交易卡号',
      '支付渠道',
    ],
    _ => const [
      ..._paymentMethodLabels,
      ..._receiptMethodLabels,
      '交易卡号',
      '支付渠道',
    ],
  }, allowBelow: true);
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
  final transferAccounts = _extractTransferAccounts(document);
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
) {
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
  from ??= document.field(const [
    '转出账户',
    '转出账号',
    '付款账户',
    '支付账户',
    '付款账号',
  ], allowBelow: true);
  // A complete title retains the card suffix for explicit user keyword rules.
  if (to?.isReliable != true) {
    to =
        document.field(const [
          '转入账户',
          '转入账号',
          '到账银行卡',
          '收款账号',
          '收款账户',
        ], allowBelow: true) ??
        to;
  }
  return (from: from, to: to);
}

const _paymentMethodLabels = ['付款方式', '支付方式', '付款账户', '支付账户', '付款账号'];
const _receiptMethodLabels = ['收款方式', '收款账户', '收款账号', '到账银行卡'];

bool _hasOwnTransferSignals(ScreenshotTextDocument document) {
  final signals = document.sceneSignals(allowBelow: true);
  return RegExp(
        r'提现|自有账户转账|本人账户转账|自己账户转账|同名账户转账|账户间转账|(?:零钱通|零钱|余额宝|余额).*?(?:转入|转出|划转)|(?:转入|转出)(?:零钱通|零钱|余额宝|余额)',
      ).hasMatch(signals) ||
      document.hasLabel('转出金额') && document.hasLabel('到账银行卡');
}

PaymentScreenshotScene _classifyScene(
  String signals,
  RecognizedPaymentDirection? direction, {
  required bool hasPaymentMethod,
  required bool hasReceiptMethod,
  required bool ownTransfer,
  required bool directionConflict,
}) {
  if (RegExp(
    r'支付失败|交易失败|付款失败|收款失败|转账失败|提现失败|扣款失败|已关闭|已取消|交易取消',
  ).hasMatch(signals)) {
    return PaymentScreenshotScene.unpaid;
  }
  if (RegExp(r'退款|退回').hasMatch(signals)) return PaymentScreenshotScene.refund;
  if (RegExp(r'还款|还贷').hasMatch(signals)) {
    return PaymentScreenshotScene.repayment;
  }
  if (ownTransfer) return PaymentScreenshotScene.transfer;
  final incoming = RegExp(
    r'收款成功|已收款|实收|已到账|已存入零钱|收款到账|待收款|等待收款|收款中|收款处理中',
  ).hasMatch(signals);
  final outgoing = RegExp(
    r'支付成功|付款成功|支付完成|扣款成功|待支付|等待付款|未支付|支付中|付款中|支付处理中|付款处理中',
  ).hasMatch(signals);
  if (directionConflict ||
      incoming && direction == RecognizedPaymentDirection.expense ||
      outgoing && direction == RecognizedPaymentDirection.income ||
      incoming && outgoing) {
    return PaymentScreenshotScene.unknown;
  }
  final resolved =
      direction ??
      (incoming
          ? RecognizedPaymentDirection.income
          : outgoing
          ? RecognizedPaymentDirection.expense
          : hasReceiptMethod && !hasPaymentMethod
          ? RecognizedPaymentDirection.income
          : hasPaymentMethod && !hasReceiptMethod
          ? RecognizedPaymentDirection.expense
          : null);
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
