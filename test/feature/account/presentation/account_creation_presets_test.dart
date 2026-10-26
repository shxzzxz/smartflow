import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/feature/account/presentation/account_creation_presets.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  test('defines grouped account creation presets', () {
    expect(accountCreationGroups.map((group) => group.label), [
      '资金账户',
      '信贷账户',
      '往来',
    ]);

    expect(
      {
        for (final group in accountCreationGroups)
          group.id: group.presets.map((preset) => preset.label).toList(),
      },
      {
        'fund': ['微信', '支付宝', '中国银行', '工商银行', '建设银行', '农业银行', '招商银行', '资金账户'],
        'credit': ['花呗', '美团月付', '借呗', '房贷', '车贷', '信用账户', '贷款账户'],
        'relations': ['报销', '押金', '应收账户', '应付账户'],
      },
    );
  });

  test('maps account presets to profiles, icons, and creation routes', () {
    final boc = accountCreationPresetForId('boc')!;

    expect(boc.kind, AccountProfileKind.fund);
    expect(boc.iconKey, 'boc_debit_card');
    expect(boc.defaultName, '中国银行');
    expect(boc.routeLocation, '/account/new?preset=boc');
    expect(
      accountCreationPresetForId('huabei')!.kind,
      AccountProfileKind.credit,
    );
    expect(accountCreationPresetForId('jiebei')!.kind, AccountProfileKind.loan);
    expect(
      accountCreationPresetForId('mortgage')!.kind,
      AccountProfileKind.loan,
    );
    expect(
      accountCreationPresetForId('deposit')!.kind,
      AccountProfileKind.receivable,
    );
    expect(
      accountCreationPresetForId('payable')!.kind,
      AccountProfileKind.payable,
    );
    expect(
      accountCreationPresetForId('reimbursement')!.kind,
      AccountProfileKind.reimbursement,
    );
    expect(accountCreationPresetForId('missing'), isNull);

    final allPresets = accountCreationGroups
        .expand((group) => group.presets)
        .toList();
    expect(allPresets.map((preset) => preset.id).toSet(), hasLength(19));
  });
}
