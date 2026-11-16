import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule_target.dart';
import 'package:smartflow/domain/intake/rules/recognition_target_resolution.dart';
import 'package:smartflow/domain/intake/rules/settlement_account_aliases.dart';

void main() {
  RecognitionRuleTarget account(String id, String name) =>
      RecognitionRuleTarget(
        id: id,
        kind: RecognitionRuleKind.account,
        path: [name],
      );

  test('exact names normalize full-width text and preserve the whole name', () {
    final accounts = [
      account('short', '邮储6620'),
      account('full', '邮储银行储蓄卡(6620)'),
    ];
    expect(matchSettlementAccountName(' 邮储银行 储蓄卡（６６２０） ', accounts), 'full');
    expect(matchSettlementAccountName('银行卡（6620）', accounts), isNull);
  });

  test('bank aliases match arbitrary names and choose the first account', () {
    final accounts = [account('first', '邮储620'), account('second', '中国邮政储蓄银行')];
    expect(matchSettlementAccountAlias('邮储银行储蓄卡（6620）', accounts), 'first');
    expect(
      matchSettlementAccountAlias('邮政储蓄银行', accounts.reversed.toList()),
      'second',
    );
    expect(matchSettlementAccountAlias('农业银行', accounts), isNull);
  });

  test(
    'longer product aliases prevent balance products from matching cash',
    () {
      final accounts = [
        account('wechat', '微信零钱'),
        account('alipay', '支付宝余额'),
        account('fund', '零钱通'),
        account('yuebao', '余额宝'),
      ];
      expect(matchSettlementAccountAlias('微信零钱通', accounts), 'fund');
      expect(
        matchSettlementAccountAlias(
          '支付宝余额宝',
          accounts,
          source: RecognitionRuleSource.alipay,
        ),
        'yuebao',
      );
      expect(
        matchSettlementAccountAlias(
          '余额',
          accounts,
          source: RecognitionRuleSource.alipay,
        ),
        'alipay',
      );
      expect(matchSettlementAccountAlias('余额', accounts), isNull);
      expect(
        matchSettlementAccountAlias('零钱通', accounts.take(2).toList()),
        isNull,
      );
      expect(
        matchSettlementAccountAlias('余额宝', accounts.take(2).toList()),
        isNull,
      );
    },
  );
}
