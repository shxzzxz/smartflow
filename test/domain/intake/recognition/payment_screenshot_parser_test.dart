import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/intake/recognition/recognized_payment.dart';
import 'package:smartflow/domain/intake/recognition/service/payment_screenshot_parser.dart';

// Synthetic layout only; private screenshots stay outside tests.
void main() {
  const parser = PaymentScreenshotParser();

  test('terminal status messages after detail fields block prefill', () {
    for (final status in [
      '支付失败，请重新付款',
      '付款失败 请重试',
      '已关闭，无法支付',
      '交易状态 失败',
      '交易状态 取消',
    ]) {
      final result = parser.parse([
        _block('交易详情', 20),
        _block('-12.35', 145, height: 60),
        _block('付款账户 日常银行卡', 260),
        _block(status, 320),
      ]);
      expect(result.scene, PaymentScreenshotScene.unpaid, reason: status);
      expect(result.canPrefill, isFalse);
    }
  });

  test('a cancel button does not make a waiting payment cancelled', () {
    final result = parser.parse([
      _block('交易详情', 20),
      _block('-12.35', 145, height: 60),
      _block('付款账户 日常银行卡', 260),
      _block('待支付', 320),
      _block('取消', 380),
    ]);
    expect(result.scene, PaymentScreenshotScene.expense);
    expect(result.canPrefill, isTrue);
  });

  test(
    'prefixed business type labels supply direction and excluded scenes',
    () {
      for (final label in ['银行交易类型', '资金业务类型', '商品交易类型']) {
        for (final entry in [
          ('工资', PaymentScreenshotScene.income, true),
          ('消费', PaymentScreenshotScene.expense, true),
          ('退款', PaymentScreenshotScene.refund, false),
          ('还款', PaymentScreenshotScene.repayment, false),
        ]) {
          final result = parser.parse([
            _block('交易详情', 20),
            _block('￥42.50', 145, height: 60),
            _block('交易时间 2026-04-05 13:20:11', 260),
            _block(label, 320),
            _block(entry.$1, 355),
          ]);
          expect(result.scene, entry.$2, reason: '$label ${entry.$1}');
          expect(result.product, isNull);
          expect(result.canPrefill, entry.$3);
        }
      }
    },
  );

  test('waiting and processing payment states still prefill', () {
    for (final entry in [
      ('待支付', PaymentScreenshotScene.expense),
      ('未支付', PaymentScreenshotScene.expense),
      ('支付中', PaymentScreenshotScene.expense),
      ('支付处理中', PaymentScreenshotScene.expense),
      ('待收款', PaymentScreenshotScene.income),
      ('收款处理中', PaymentScreenshotScene.income),
    ]) {
      final result = parser.parse([
        _block('交易详情', 20),
        _block('￥12.35', 145, height: 60),
        _block('当前状态 ${entry.$1}', 260),
      ]);
      expect(result.scene, entry.$2, reason: entry.$1);
      expect(result.amount, Money.parse('12.35'));
      expect(result.canPrefill, isTrue);
    }
  });

  test('generic transfer captions do not imply movements of own funds', () {
    for (final entry in [
      ('+12.35', PaymentScreenshotScene.income),
      ('-12.35', PaymentScreenshotScene.expense),
      ('￥12.35', PaymentScreenshotScene.unknown),
    ]) {
      final result = parser.parse([
        _block('转账详情', 20),
        _block(entry.$1, 145, height: 60),
        _block('交易时间 2026-04-05 13:20:11', 260),
      ]);
      expect(result.scene, entry.$2, reason: entry.$1);
      expect(result.canPrefill, isTrue);
    }
  });

  test('no transaction information keeps screenshot review open', () {
    for (final blocks in [
      <RecognizedTextBlock>[],
      [_block('今天的风景', 80)],
      [_block('交易详情', 80)],
    ]) {
      final result = parser.parse(blocks);
      expect(result.scene, PaymentScreenshotScene.unknown);
      expect(result.amount, isNull);
      expect(result.canPrefill, isFalse);
    }
  });

  test('bank income details prefill without a success status', () {
    final result = parser.parse([
      _block('交易详情', 20),
      _block('示例网络科技有限公司', 90),
      _block('+￥42.50', 145, height: 60),
      _block('查看余额,请登录', 240),
      _block('交易卡号 6222********1111', 300),
      _block('交易时间 2026-04-05 13:20:11', 360),
      _block('银行交易类型 工资', 420),
      _block('分类 薪酬>', 480),
    ]);
    expect(result.scene, PaymentScreenshotScene.income);
    expect(result.direction, RecognizedPaymentDirection.income);
    expect(result.amount, Money.parse('42.50'));
    expect(result.occurredAt, DateTime(2026, 4, 5, 13, 20, 11));
    expect(result.counterparty, '示例网络科技有限公司');
    expect(result.categoryName, '薪酬');
    expect(result.canPrefill, isTrue);
  });

  test('signed expenses and payment method clues need no success status', () {
    for (final amount in ['-12.35', '￥12.35']) {
      final result = parser.parse([
        _block('交易详情', 20),
        _block('示例书店', 90),
        _block(amount, 145, height: 60),
        _block('支付方式 日常银行卡', 260),
        _block('商品说明 图书', 320),
      ]);
      expect(result.scene, PaymentScreenshotScene.expense, reason: amount);
      expect(result.amount, Money.parse('12.35'));
      expect(result.product, '图书');
      expect(result.canPrefill, isTrue);
    }
  });

  test(
    'known scenes retain useful details when the actual amount is missing',
    () {
      for (final entry in [
        ('收款成功', PaymentScreenshotScene.income),
        ('支付成功', PaymentScreenshotScene.expense),
        ('自有账户转账', PaymentScreenshotScene.transfer),
      ]) {
        final result = parser.parse([
          _block(entry.$1, 80),
          _block('交易时间 2026-04-05 13:20:11', 240),
          _block('商品说明 示例说明', 300),
        ]);
        expect(result.scene, entry.$2);
        expect(result.amount, isNull);
        expect(result.occurredAt, DateTime(2026, 4, 5, 13, 20, 11));
        expect(result.product, '示例说明');
        expect(result.canPrefill, isTrue, reason: entry.$1);
      }
    },
  );

  test(
    'unknown scenes can pass their extracted fields to the default form',
    () {
      final result = parser.parse([
        _block('交易详情', 20),
        _block('￥12.35', 145, height: 60),
        _block('交易时间 2026-04-05 13:20:11', 260),
        _block('商品说明 图书', 320),
      ]);
      expect(result.scene, PaymentScreenshotScene.unknown);
      expect(result.direction, isNull);
      expect(result.amount, Money.parse('12.35'));
      expect(result.product, '图书');
      expect(result.canPrefill, isTrue);
    },
  );

  test('receipt confirmation takes precedence over transfer metadata', () {
    final result = parser.parse([
      _block('你已收款，资金已存入零钱', 80),
      _block('￥23.40', 145, height: 60),
      _block('零钱余额', 240),
      _block('转账时间', 320),
      _block('2026年4月5日 13:20:11', 320, left: 300),
      _block('收款时间', 380),
      _block('2026年4月5日 13:20:50', 380, left: 300),
    ]);
    expect(result.scene, PaymentScreenshotScene.income);
    expect(result.direction, RecognizedPaymentDirection.income);
    expect(result.amount, Money.parse('23.40'));
    expect(result.occurredAt, DateTime(2026, 4, 5, 13, 20, 50));
    expect(result.paymentMethod, '零钱');
    expect(result.counterparty, isNull);
    expect(result.canPrefill, isTrue);
  });

  test('received transfer detail is income and retains its sender', () {
    final result = parser.parse([
      _block('全部账单', 20),
      _block('转账-来自示例亲友', 90),
      _block('+23.40', 145, height: 60),
      _block('当前状态 已存入零钱', 260),
      _block('转账说明 示例转账', 320),
      _block('转账时间 2026年4月5日 13:20:11', 380),
      _block('收款时间 2026年4月5日 13:20:50', 440),
    ]);
    expect(result.scene, PaymentScreenshotScene.income);
    expect(result.direction, RecognizedPaymentDirection.income);
    expect(result.amount, Money.parse('23.40'));
    expect(result.occurredAt, DateTime(2026, 4, 5, 13, 20, 50));
    expect(result.paymentMethod, '零钱');
    expect(result.counterparty, '示例亲友');
    expect(result.canPrefill, isTrue);
  });

  test(
    'personal receipts prefill while conflicting directions stay unknown',
    () {
      for (final entry in [
        ('+23.40', '待收款', PaymentScreenshotScene.income),
        ('+23.40', '转账成功', PaymentScreenshotScene.income),
        ('-23.40', '已存入零钱', PaymentScreenshotScene.unknown),
      ]) {
        final result = parser.parse([
          _block('转账-来自示例亲友', 90),
          _block(entry.$1, 145, height: 60),
          _block('当前状态 ${entry.$2}', 260),
        ]);
        expect(result.scene, entry.$3);
        expect(result.canPrefill, isTrue);
      }
      final refund = parser.parse([
        _block('退款成功', 80),
        _block('+23.40', 145, height: 60),
        _block('当前状态 已存入零钱', 260),
      ]);
      expect(refund.scene, PaymentScreenshotScene.refund);
      expect(refund.canPrefill, isFalse);
    },
  );

  test('unsigned payment success amounts allow missing detail fields', () {
    final result = parser.parse([
      _block('支付成功', 80),
      _block('￥49.25', 145, height: 60),
      _block('完成', 260),
    ]);
    expect(result.scene, PaymentScreenshotScene.expense);
    expect(result.amount, Money.parse('49.25'));
    expect(result.paymentMethod, isNull);
    expect(result.occurredAt, isNull);
    expect(result.canPrefill, isTrue);
  });

  test('account transfers and withdrawals are not ordinary income', () {
    for (final heading in ['自有账户转账', '转入余额', '提现到账']) {
      final result = parser.parse([
        _block(heading, 80),
        _block('+23.40', 145, height: 60),
        _block('当前状态 已到账', 260),
      ]);
      expect(result.scene, PaymentScreenshotScene.transfer, reason: heading);
      expect(result.canPrefill, isTrue);
    }
  });

  for (final caption in ['预计2026年4月7日 14:00前到账', '时间 预计2026年4月7日 14:00前到账']) {
    test('pending withdrawal ignores estimated time in "$caption"', () {
      final result = parser.parse([
        _block(caption, 80),
        _block('转出金额', 180),
        _block('￥465.75', 180, left: 300),
        _block('到账银行卡', 240),
        _block('示例银行(1234)', 240, left: 300),
        _block('完成', 380),
      ]);
      expect(result.scene, PaymentScreenshotScene.transfer);
      expect(result.occurredAt, isNull);
      expect(result.amount, Money.parse('465.75'));
      expect(result.paymentMethod, '示例银行(1234)');
      expect(result.counterparty, isNull);
      expect(result.transferFromAccount, isNull);
      expect(result.transferToAccount, '示例银行(1234)');
      expect(result.canPrefill, isTrue);
    });
  }

  test('completed withdrawal uses its transfer event and not its balance', () {
    final result = parser.parse([
      _block('详情', 20),
      _block('零钱通转出-到示例银行(1234)', 80),
      _block('-385.50', 145, height: 60),
      _block('当前状态', 240),
      _block('转出资金', 240, left: 300),
      _block('2026-04-05 09:12:00', 280, left: 300),
      _block('基金公司处理中', 340, left: 300),
      _block('资金到账', 400, left: 300),
      _block('2026-04-07 14:00:00', 440, left: 300),
      _block('零钱通余额', 500),
      _block('￥1357.90', 500, left: 300),
      _block('收款账号', 560),
      _block('示例银行', 560, left: 300),
    ]);
    expect(result.scene, PaymentScreenshotScene.transfer);
    expect(result.amount, Money.parse('385.50'));
    expect(result.occurredAt, DateTime(2026, 4, 5, 9, 12));
    expect(result.paymentMethod, '示例银行');
    expect(result.counterparty, isNull);
    expect(result.transferFromAccount, '零钱通');
    expect(result.transferToAccount, '示例银行(1234)');
    expect(result.canPrefill, isTrue);
  });

  test('a receipt account alone does not imply a transfer of own funds', () {
    final result = parser.parse([
      _block('转账-来自示例亲友', 80),
      _block('+23.40', 145, height: 60),
      _block('当前状态 待收款', 240),
      _block('到账银行卡 示例银行(1234)', 300),
    ]);
    expect(result.scene, PaymentScreenshotScene.income);
    expect(result.transferFromAccount, isNull);
    expect(result.transferToAccount, '示例银行(1234)');
    expect(result.canPrefill, isTrue);
  });

  test('withdrawal balance cannot replace a missing transfer amount', () {
    final result = parser.parse([
      _block('零钱通转出', 20),
      _block('零钱通余额', 80),
      _block('￥1357.90', 145, height: 60),
      _block('当前状态 资金到账', 240),
      _block('收款账号 示例银行', 300),
    ]);
    expect(result.scene, PaymentScreenshotScene.transfer);
    expect(result.amount, isNull);
    expect(result.counterparty, isNull);
    expect(result.canPrefill, isTrue);
  });

  test('success and amount in one row exclude fees and reward amounts', () {
    for (final status in ['支付成功', '交易成功']) {
      final result = parser.parse([
        _block('提交订单', 20),
        _block('包装费 ￥0.70', 80),
        _block(status, 145, height: 60),
        _block('￥49.25', 145, left: 300, height: 60),
        _block('支付优惠 -￥0.75', 260),
        _block('支付方式 示例月付', 320),
        _block('领取现金券', 380),
        _block('￥9.00', 440, height: 60),
        _block('完成', 500),
      ]);
      expect(result.scene, PaymentScreenshotScene.expense, reason: status);
      expect(result.amount, Money.parse('49.25'), reason: status);
      expect(result.paymentMethod, '示例月付');
      expect(result.counterparty, isNull);
      expect(result.canPrefill, isTrue);
    }
  });

  test('recognizes scene keywords split into blocks in a labeled row', () {
    final scenes = {
      ('自有账户转', '账'): PaymentScreenshotScene.transfer,
      ('退', '款'): PaymentScreenshotScene.refund,
      ('还', '款'): PaymentScreenshotScene.repayment,
      ('已', '取消'): PaymentScreenshotScene.unpaid,
    };
    for (final entry in scenes.entries) {
      final result = parser.parse([
        _block('支付详情', 20),
        _block('-20.00', 145, height: 60),
        _block('当前状态 支付成功', 240),
        _block('交易类型', 300),
        _block(entry.key.$1, 300, left: 300),
        _block(entry.key.$2, 300, left: 370),
      ]);
      expect(result.scene, entry.value, reason: entry.key.toString());
      expect(result.canPrefill, entry.value == PaymentScreenshotScene.transfer);
    }
  });

  test('recognizes split standalone status below detail fields', () {
    final scenes = {
      ('支付', '成功'): PaymentScreenshotScene.expense,
      ('退款', '成功'): PaymentScreenshotScene.refund,
      ('转账', '成功'): PaymentScreenshotScene.expense,
      ('还款', '成功'): PaymentScreenshotScene.repayment,
    };
    for (final entry in scenes.entries) {
      final result = parser.parse([
        _block('支付详情', 20),
        _block('-20.00', 145, height: 60),
        _block('付款方式 日常账户', 240),
        _block(entry.key.$1, 300),
        _block(entry.key.$2, 300, left: 300),
      ]);
      expect(result.scene, entry.value, reason: entry.key.toString());
    }
  });

  test('scene matching preserves raw fields and excludes their keywords', () {
    final result = parser.parse([
      _block('支付详情', 20),
      _block('-20.00', 145, height: 60),
      _block('当前状态', 240),
      _block('支付', 240, left: 300),
      _block('成功', 240, left: 370),
      _block('支付方式', 300),
      _block('我的 转 账卡', 300, left: 300),
      _block('商品说明', 360),
      _block('退 款政策 说明书', 360, left: 300),
      _block('交易对方 示例 商店', 420),
      _block('支付时间 2026-04-05 13:20:11', 480),
    ]);
    expect(result.scene, PaymentScreenshotScene.expense);
    expect(result.canPrefill, isTrue);
    expect(result.paymentMethod, '我的 转 账卡');
    expect(result.accountMatchingText, '我的 转 账卡');
    expect(result.product, '退 款政策 说明书');
    expect(result.counterparty, '示例 商店');
    expect(result.occurredAt, DateTime(2026, 4, 5, 13, 20, 11));
  });

  test('scene keywords cannot be joined across separate rows', () {
    final result = parser.parse([
      _block('支付详情', 20),
      _block('-20.00', 145, height: 60),
      _block('交易成功', 240),
      _block('转', 300),
      _block('账', 360),
      _block('支付方式 日常账户', 420),
    ]);
    expect(result.scene, PaymentScreenshotScene.expense);
    expect(result.canPrefill, isTrue);
  });

  test(
    'conflicting direction and status preserve values for the default form',
    () {
      for (final entry in [('+20.00', '支付成功'), ('-20.00', '收款成功')]) {
        final result = parser.parse([
          _block('支付详情', 20),
          _block('示例客户', 80),
          _block(entry.$1, 145, height: 60),
          _block(entry.$2, 260),
        ]);
        expect(result.scene, PaymentScreenshotScene.unknown);
        expect(result.canPrefill, isTrue);
        expect(result.needsReview, isTrue);
      }
    },
  );

  test(
    'extracts explicit category names separately from merchants and payment methods',
    () {
      for (final label in ['分类', '交易分类', '收支分类', '商品分类', '账单分类', '本笔消费分类']) {
        final result = parser.parse([
          _block('支付详情', 20),
          _block('示例咖啡店', 90),
          _block('-12.00', 145, height: 60),
          _block('当前状态 支付成功', 240),
          _block('支付时间 2026-04-05 13:20:11', 290),
          _block('支付方式 零钱通', 340),
          _block('商品说明 奶茶', 390),
          _block('$label 茶饮', 440),
        ]);
        expect(result.categoryName, '茶饮', reason: label);
        expect(result.categoryNameReliable, isTrue);
        expect(result.categoryMatchingText, contains('茶饮'));
        expect(result.categoryMatchingText, isNot(contains('零钱通')));
        expect(result.canPrefill, isTrue);
      }
    },
  );

  test(
    'category labels use their value column instead of recommendation text',
    () {
      final result = parser.parse([
        _block('账单详情', 20),
        _block('示例通讯商户', 90),
        _block('-18.00', 145, height: 60),
        _block('交易成功', 240),
        _block('商品说明 服务充值', 300),
        _block('本笔账务分类', 360),
        _block('充值缴费>', 360, left: 300),
        _block('为您推荐 话费+', 420),
      ]);
      expect(result.categoryName, '充值缴费');
      expect(result.categoryMatchingText, '充值缴费\n示例通讯商户\n服务充值');
    },
  );

  test(
    'category words inside products and management headings are not labels',
    () {
      final result = parser.parse([
        _block('支付详情', 20),
        _block('示例书店', 90),
        _block('-18.00', 145, height: 60),
        _block('交易成功', 240),
        _block('商品说明 分类 使用手册', 300),
        _block('分类管理', 360),
        _block('设置', 360, left: 300),
      ]);
      expect(result.categoryName, isNull);
      expect(result.product, '分类 使用手册');
    },
  );

  test(
    'counterparty values continue in their column and stop at the next field',
    () {
      final result = parser.parse([
        _block('支付详情', 20),
        _block('显示名称', 90),
        _block('-18.00', 145, height: 60),
        _block('交易成功', 240),
        _block('收款方全称', 300),
        _block('示例交通集团有限责任公司票务246', 300, left: 300),
        _block('80技术中心', 335, left: 302),
        _block('订单号', 375),
        _block('1234567890', 375, left: 300),
        _block('商品说明 车票', 420),
      ]);
      expect(result.counterparty, '示例交通集团有限责任公司票务24680技术中心');
      expect(result.categoryMatchingText, '示例交通集团有限责任公司票务24680技术中心\n车票');
      expect(result.product, '车票');
    },
  );

  test('wrapped counterparties preserve confidence from every line', () {
    final result = parser.parse([
      _block('支付详情', 20),
      _block('显示名称', 90),
      _block('-18.00', 145, height: 60),
      _block('交易成功', 240),
      _block('收款方全称', 300),
      _block('示例集团有限责任公司', 300, left: 300),
      _block('技术中心', 335, left: 300, confidence: .7),
      _block('商品说明 车票', 390),
    ]);
    expect(result.counterparty, '示例集团有限责任公司技术中心');
    expect(result.categoryMatchingText, '车票');
    expect(result.needsReview, isTrue);
  });

  test('counterparties do not merge distant or differently aligned text', () {
    for (final extra in [
      _block('立即领取积分', 335),
      _block('立即领取积分', 430, left: 300),
    ]) {
      final result = parser.parse([
        _block('支付详情', 20),
        _block('显示名称', 90),
        _block('-18.00', 145, height: 60),
        _block('交易成功', 240),
        _block('收款方全称', 300),
        _block('示例商户', 300, left: 300),
        extra,
      ]);
      expect(result.counterparty, '示例商户');
    }
  });

  test(
    'wrapped counterparty values also work inline and below their label',
    () {
      for (final inline in [true, false]) {
        final result = parser.parse([
          _block('支付详情', 20),
          _block('显示名称', 90),
          _block('-18.00', 145, height: 60),
          _block('交易成功', 240),
          if (inline)
            _block('商户全称 示例集团', 300)
          else ...[
            _block('商户全称', 300),
            _block('示例集团', 335),
          ],
          _block('技术中心', inline ? 335 : 370, left: inline ? 150 : 20),
          _block('商品说明 车票', 420),
        ]);
        expect(result.counterparty, '示例集团技术中心');
        expect(result.product, '车票');
      }
    },
  );

  test(
    'extracts prominent actual debit instead of order price or discount',
    () {
      final result = parser.parse([
        _block('账单详情', 20),
        _block('示例书店', 100),
        _block('−１８.６０', 150, height: 64),
        _block('交易成功', 230),
        _block('订单金额', 290),
        _block('20.00', 290, left: 300),
        _block('优惠', 340),
        _block('-1.40', 340, left: 300),
        _block('支付时间', 400),
        _block('2026-04-05 13:20:11', 400, left: 300),
        _block('付款方式', 450),
        _block('示例银行储蓄卡(1234)', 450, left: 300),
        _block('商品说明', 500),
        _block('图书', 500, left: 300),
      ]);
      expect(result.amount, Money.parse('18.60'));
      expect(result.scene, PaymentScreenshotScene.expense);
      expect(result.direction, RecognizedPaymentDirection.expense);
      expect(result.occurredAt, DateTime(2026, 4, 5, 13, 20, 11));
      expect(result.paymentMethod, '示例银行储蓄卡(1234)');
      expect(result.counterparty, '示例书店');
      expect(result.product, '图书');
      expect(result.accountMatchingText, '示例银行储蓄卡(1234)');
      expect(result.categoryMatchingText, '示例书店\n图书');
      expect(result.categoryRule, isNull);
    },
  );

  test('generic parsing handles Chinese timestamps and receipt accounts', () {
    final expense = parser.parse([
      _block('支付详情', 20),
      _block('示例商店', 90),
      _block('-88.25', 145, height: 66),
      _block('当前状态 支付成功', 260),
      _block('支付时间 2026年2月28日 09:08:07', 310),
      _block('支付方式 零钱', 360),
    ]);
    expect(expense.amount, Money.parse('88.25'));
    expect(expense.occurredAt, DateTime(2026, 2, 28, 9, 8, 7));
    expect(expense.paymentMethod, '零钱');
    final income = parser.parse([
      _block('收款详情', 20),
      _block('示例客户', 90),
      _block('+7.50', 130, height: 66),
      _block('当前状态 已存入零钱', 240),
    ]);
    expect(income.scene, PaymentScreenshotScene.income);
    expect(income.paymentMethod, '零钱');
    final explicit = parser.parse([
      _block('收款详情', 20),
      _block('示例客户', 90),
      _block('+7.50', 130, height: 66),
      _block('当前状态 已存入零钱', 240),
      _block('收款方式 日常账户', 300),
    ]);
    expect(explicit.paymentMethod, '日常账户');
  });

  test('unbranded screenshots use generic field labels', () {
    final result = parser.parse([
      _block('付款凭证', 20),
      _block('示例书店', 90),
      _block('-28.00', 145, height: 60),
      _block('支付成功', 240),
      _block('付款账户 日常银行卡', 300),
      _block('付款时间 2026/04/05 13:20:11', 360),
      _block('商品信息 图书', 420),
    ]);
    expect(result.scene, PaymentScreenshotScene.expense);
    expect(result.amount, Money.parse('28'));
    expect(result.paymentMethod, '日常银行卡');
    expect(result.product, '图书');
    expect(result.canPrefill, isTrue);
  });

  test('reads values below labels and a unique unlabelled timestamp', () {
    final result = parser.parse([
      _block('付款凭证', 20),
      _block('示例商户', 90),
      _block('支付成功', 150),
      _block('扣款金额 12.35', 220),
      _block('付款账户', 290),
      _block('日常银行卡', 325),
      _block('商品信息 书籍', 380),
      _block('2026-04-05 13:20:11', 450),
    ]);
    expect(result.amount, Money.parse('12.35'));
    expect(result.paymentMethod, '日常银行卡');
    expect(result.occurredAt, DateTime(2026, 4, 5, 13, 20, 11));
    expect(result.scene, PaymentScreenshotScene.expense);
  });

  test('explicit counterparty fields take precedence over headline text', () {
    final result = parser.parse([
      _block('支付详情', 20),
      _block('显示名称', 90),
      _block('-9.99', 145, height: 60),
      _block('支付成功', 240),
      _block('商户全称 示例商户全称', 300),
      _block('付款账户 日常账户', 360),
      _block('商品信息 图书', 420),
    ]);
    expect(result.counterparty, '示例商户全称');
    expect(result.paymentMethod, '日常账户');
    expect(result.product, '图书');
    expect(result.amount, Money.parse('9.99'));
  });

  test(
    'order prices and standalone discounts never supply missing actual amount',
    () {
      for (final discount in ['立减 -2.00', '-2.00']) {
        final result = parser.parse([
          _block('支付详情', 20),
          _block('交易成功', 80),
          _block('订单金额 100.00', 150),
          _block(discount, 210, height: 40),
        ]);
        expect(result.amount, isNull);
        expect(result.canPrefill, isFalse);
      }
    },
  );

  test(
    'actual amount labels can establish direction without guessing expense',
    () {
      final received = parser.parse([
        _block('支付凭证', 20),
        _block('交易成功', 80),
        _block('实收金额 20.00', 150),
      ]);
      expect(received.scene, PaymentScreenshotScene.income);
      final unknown = parser.parse([
        _block('支付详情', 20),
        _block('交易成功', 80),
        _block('20.00', 150, height: 60),
      ]);
      expect(unknown.amount, Money.parse('20'));
      expect(unknown.scene, PaymentScreenshotScene.unknown);
      expect(unknown.direction, isNull);
      expect(unknown.canPrefill, isTrue);
    },
  );

  test(
    'failed, cancelled, refund and repayment scenes do not become ordinary',
    () {
      final scenes = {
        '支付失败': PaymentScreenshotScene.unpaid,
        '已取消': PaymentScreenshotScene.unpaid,
        '退款成功': PaymentScreenshotScene.refund,
        '还款成功': PaymentScreenshotScene.repayment,
      };
      for (final entry in scenes.entries) {
        final result = parser.parse([
          _block('支付详情', 20),
          _block(entry.key, 80),
          _block('-50.00', 130, height: 66),
          _block('付款账户 日常账户', 250),
        ]);
        expect(result.scene, entry.value, reason: entry.key);
        expect(result.amount, Money.parse('50'));
        expect(result.paymentMethod, '日常账户');
        expect(result.canPrefill, isFalse, reason: entry.key);
      }
    },
  );

  test('negative transaction status takes precedence over a paid headline', () {
    final result = parser.parse([
      _block('支付详情', 20),
      _block('支付成功', 90),
      _block('-20.00', 145, height: 66),
      _block('当前状态 已取消', 300),
    ]);
    expect(result.scene, PaymentScreenshotScene.unpaid);
    expect(result.canPrefill, isFalse);
  });

  test('brand text does not change generic scene and field interpretation', () {
    for (final heading in ['付款凭证', '微信支付', '支付宝', '抖音支付']) {
      final result = parser.parse([
        _block(heading, 20),
        _block('示例商户', 90),
        _block('-10.00', 145, height: 60),
        _block('支付成功', 240),
        _block('支付方式 日常银行卡', 300),
        _block('商品说明 图书', 360),
      ]);
      expect(result.scene, PaymentScreenshotScene.expense, reason: heading);
      expect(result.amount, Money.parse('10'));
      expect(result.counterparty, '示例商户');
      expect(result.paymentMethod, '日常银行卡');
      expect(result.product, '图书');
      expect(result.canPrefill, isTrue);
    }
  });

  test('product content is not used as evidence of a refund scene', () {
    final result = parser.parse([
      _block('支付详情', 20),
      _block('示例书店', 90),
      _block('-10.00', 145, height: 60),
      _block('交易成功', 260),
      _block('商品说明 退款政策说明书', 310),
    ]);
    expect(result.scene, PaymentScreenshotScene.expense);
  });

  test('ambiguous amounts stay empty while the expense scene can prefill', () {
    final result = parser.parse([
      _block('支付详情', 20),
      _block('-10.00', 90, height: 60),
      _block('-20.00', 180, height: 60),
      _block('支付成功', 300),
    ]);
    expect(result.amount, isNull);
    expect(result.canPrefill, isTrue);
    expect(result.needsReview, isTrue);
  });

  test('invalid dates are omitted and low confidence is retained', () {
    final result = parser.parse([
      _block('支付详情', 20),
      _block('交易成功', 80),
      _block('-3.20', 130, height: 66, confidence: .6),
      _block('支付时间 2026-02-30 10:00:00', 260),
    ]);
    expect(result.occurredAt, isNull);
    expect(result.needsReview, isTrue);
  });
}

RecognizedTextBlock _block(
  String text,
  double top, {
  double left = 20,
  double height = 30,
  double confidence = .99,
}) => RecognizedTextBlock(
  text: text,
  confidence: confidence,
  left: left,
  top: top,
  right: left + 200,
  bottom: top + height,
);
