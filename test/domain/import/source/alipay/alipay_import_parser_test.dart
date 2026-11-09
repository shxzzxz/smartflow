import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/import/port/import_file_reader.dart';
import 'package:smartflow/domain/import/source/alipay/alipay_import_parser.dart';

void main() {
  test('maps successful expenses and income while filtering other rows', () {
    final result = _parser([
      _expenseRow(),
      _row(
        direction: '收入',
        amount: '23.22',
        status: '交易成功',
        paymentMethod: '',
        category: '转账红包',
        orderId: 'income-1',
      ),
      _row(
        direction: '不计收支',
        amount: '2.01',
        status: '交易成功',
        paymentMethod: '余额宝',
        category: '投资理财',
        orderId: 'ignored-1',
      ),
      _row(
        direction: '支出',
        amount: '28.27',
        status: '交易关闭',
        paymentMethod: '花呗',
        category: '交通出行',
        orderId: 'closed-1',
      ),
      _row(
        direction: '',
        amount: '1.00',
        status: '交易成功',
        paymentMethod: '账户余额',
        category: '其他',
        orderId: 'unknown-1',
      ),
    ]).parse(_bundle());

    expect(result.fatalIssues, isEmpty);
    expect(result.groups, hasLength(2));
    expect(result.filteredRecords, hasLength(3));
    expect(result.filteredRecords.map((record) => record.reasonCode), [
      'alipay_direction_not_supported',
      'alipay_transaction_status_not_supported',
      'alipay_direction_unknown',
    ]);
    expect(result.issues.single.code, 'alipay_direction_unknown');

    final expense = result.groups[0].topLevel as ImportExpenseDraft;
    expect(expense.amount, Money.parse('25.00'));
    expect(expense.category.path, '餐饮美食');
    expect(expense.note, '交易对方：示例早餐店；商品说明：虚构早餐套餐');
    expect(result.groups[0].sourceOperationKey, 'expense-1');
    expect(result.groups[0].sourceOperationFingerprint, hasLength(64));

    final income = result.groups[1].topLevel as ImportIncomeDraft;
    expect(income.amount, Money.parse('23.22'));
    expect(income.receiveAccount.isExplicitNone, isTrue);
    expect(income.receiveAccount.sourceEntityKey, isNull);
    expect(income.category.path, '转账红包');

    final account = result.sourceAccounts.single;
    expect(account.sourceEntityKey, 'account:花呗');
    expect(account.allowedTargetDescriptors, {
      ImportTargetDescriptor.creditAccount,
    });
    expect(
      account.preferredTargetDescriptor,
      ImportTargetDescriptor.creditAccount,
    );
  });

  test('applies account profile constraints from payment methods', () {
    final result = _parser([
      _expenseRow(orderId: 'huabei', paymentMethod: '花呗'),
      _expenseRow(orderId: 'savings', paymentMethod: '示例银行储蓄卡(0001)'),
      _expenseRow(orderId: 'bank', paymentMethod: '示例银行账户(0002)'),
    ]).parse(_bundle());

    final accounts = {
      for (final account in result.sourceAccounts)
        account.sourceEntityKey: account,
    };
    expect(
      accounts['account:花呗']?.preferredTargetDescriptor,
      ImportTargetDescriptor.creditAccount,
    );
    expect(accounts['account:示例银行储蓄卡(0001)']?.allowedTargetDescriptors, {
      ImportTargetDescriptor.fundAccount,
    });
    expect(accounts['account:示例银行账户(0002)']?.allowedTargetDescriptors, {
      ImportTargetDescriptor.fundAccount,
      ImportTargetDescriptor.creditAccount,
    });
  });

  test('keeps only the account segment of decorated payment methods', () {
    final result = _parser([
      _expenseRow(orderId: 'huabei-online', paymentMethod: '花呗&网上消费红包'),
      _expenseRow(orderId: 'huabei-dinner', paymentMethod: '花呗&晚餐到店红包'),
      _expenseRow(
        orderId: 'bank-discount',
        paymentMethod: '中国银行储蓄卡(2485)&优惠&网上消费红包',
      ),
    ]).parse(_bundle());

    expect(
      result.sourceAccounts.map((account) => account.sourceEntityKey).toSet(),
      {'account:花呗', 'account:中国银行储蓄卡(2485)'},
    );
    expect(
      result.groups
          .map(
            (group) =>
                (group.topLevel as ImportExpenseDraft).paidFrom.sourceEntityKey,
          )
          .toList(),
      ['account:花呗', 'account:花呗', 'account:中国银行储蓄卡(2485)'],
    );

    final accounts = {
      for (final account in result.sourceAccounts)
        account.sourceEntityKey: account,
    };
    expect(accounts['account:花呗']?.displayName, '花呗');
    expect(accounts['account:花呗']?.allowedTargetDescriptors, {
      ImportTargetDescriptor.creditAccount,
    });
    expect(accounts['account:中国银行储蓄卡(2485)']?.displayName, '中国银行储蓄卡(2485)');
    expect(accounts['account:中国银行储蓄卡(2485)']?.allowedTargetDescriptors, {
      ImportTargetDescriptor.fundAccount,
    });
  });

  test('filters zero-amount rows without creating candidates or issues', () {
    final result = _parser([
      _expenseRow(orderId: 'zero-expense', amount: '0'),
      _row(
        direction: '收入',
        amount: '0.00',
        status: '交易成功',
        paymentMethod: '账户余额',
        category: '退款',
        orderId: 'zero-income',
      ),
    ]).parse(_bundle());

    expect(result.groups, isEmpty);
    expect(result.filteredRecords.map((record) => record.reasonCode), [
      'alipay_amount_zero',
      'alipay_amount_zero',
    ]);
    expect(result.issues, isEmpty);
    expect(result.sourceEntities, isEmpty);
  });

  test(
    'blocks invalid candidate rows and exposes missing category mapping',
    () {
      final result = _parser([
        _row(
          direction: '支出',
          date: '2025-13-40 99:99:99',
          amount: '-1.00',
          status: '交易成功',
          paymentMethod: '花呗',
          category: '',
          orderId: '',
        ),
      ]).parse(_bundle());

      final group = result.groups.single;
      expect(group.hasBlockingIssues, isTrue);
      expect(
        group.issues.map((issue) => issue.code),
        containsAll([
          'alipay_date_invalid',
          'alipay_amount_invalid',
          'category_missing',
          'alipay_source_operation_key_missing',
        ]),
      );
      expect(result.sourceCategories.single.isReviewPlaceholder, isTrue);
    },
  );

  test('uses the assembler to block duplicate transaction order ids', () {
    final result = _parser([
      _expenseRow(orderId: 'duplicate'),
      _expenseRow(orderId: 'duplicate'),
    ]).parse(_bundle());

    expect(result.groups, hasLength(2));
    expect(
      result.groups.every(
        (group) => group.issues.any(
          (issue) => issue.code == 'duplicate_source_operation_key',
        ),
      ),
      isTrue,
    );
  });

  test('accepts exactly one file and rejects multiple files', () {
    final multiple = _parser([_expenseRow()]).parse(
      ImportBundle(
        files: [
          ImportFilePayload(name: 'a.csv', bytes: Uint8List(0)),
          ImportFilePayload(name: 'b.csv', bytes: Uint8List(0)),
        ],
      ),
    );

    expect(
      multiple.fatalIssues.single.code,
      'alipay_multiple_files_unsupported',
    );
    expect(multiple.groups, isEmpty);
  });
}

AlipayImportParser _parser(List<Map<String, Object?>> rows) {
  return AlipayImportParser(
    reader: _FakeReader(
      ImportTabularFile(
        sheets: [
          ImportTabularSheet(name: '支付宝交易明细', headers: _headers, rows: rows),
        ],
      ),
    ),
  );
}

ImportBundle _bundle() {
  return ImportBundle(
    files: [ImportFilePayload(name: '支付宝交易明细.csv', bytes: Uint8List(0))],
  );
}

Map<String, Object?> _expenseRow({
  String orderId = 'expense-1',
  String paymentMethod = '花呗',
  String amount = '25.00',
}) {
  return _row(
    direction: '支出',
    amount: amount,
    status: '交易成功',
    paymentMethod: paymentMethod,
    category: '餐饮美食',
    orderId: orderId,
  );
}

Map<String, Object?> _row({
  String date = '2025-01-03 08:15:21',
  required String direction,
  required String amount,
  required String status,
  required String paymentMethod,
  required String category,
  required String orderId,
}) {
  return {
    '交易时间': date,
    '交易分类': category,
    '交易对方': '示例早餐店',
    '对方账号': 'shop001@example.com',
    '商品说明': '虚构早餐套餐',
    '收/支': direction,
    '金额': amount,
    '收/付款方式': paymentMethod,
    '交易状态': status,
    '交易订单号': orderId,
    '商家订单号': 'merchant-1',
    '备注': '',
  };
}

const _headers = [
  '交易时间',
  '交易分类',
  '交易对方',
  '对方账号',
  '商品说明',
  '收/支',
  '金额',
  '收/付款方式',
  '交易状态',
  '交易订单号',
  '商家订单号',
  '备注',
];

class _FakeReader implements ImportFileReader {
  const _FakeReader(this.workbook);

  final ImportTabularFile workbook;

  @override
  ImportTabularFile read(ImportFilePayload file) => workbook;
}
