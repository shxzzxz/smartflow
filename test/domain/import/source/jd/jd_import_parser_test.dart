import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/import/port/import_file_reader.dart';
import 'package:smartflow/domain/import/source/jd/jd_import_parser.dart';

void main() {
  test('imports only expense and income directions with JD facts', () {
    final result = _parser([
      _row(
        direction: '支出',
        amount: '25.00',
        status: '自动扣款成功',
        paymentMethod: '示例银行储蓄卡(0001)',
        category: '家居家装',
        transactionId: 'expense-1',
        merchantOrderId: 'merchant-1',
        note: '虚构家居用品订单',
      ),
      _row(
        direction: '收入',
        amount: '23.22',
        status: '赎回成功',
        paymentMethod: '余额',
        category: '其他',
        transactionId: 'income-1',
        merchantOrderId: 'merchant-2',
        note: '虚构小金库收益',
      ),
      _row(
        direction: '不计收支',
        amount: '9.99(已全额退款)',
        status: '交易成功',
        paymentMethod: '示例银行储蓄卡(0001)',
        category: '其他',
        transactionId: 'ignored-1',
        merchantOrderId: 'merchant-3',
      ),
      _row(
        direction: '',
        amount: '1.00',
        status: '交易成功',
        paymentMethod: '余额',
        category: '其他',
        transactionId: 'unknown-1',
        merchantOrderId: 'merchant-4',
      ),
    ]).parse(_bundle());

    expect(result.fatalIssues, isEmpty);
    expect(result.groups, hasLength(2));
    expect(result.filteredRecords.map((record) => record.reasonCode), [
      'jd_direction_not_supported',
      'jd_direction_unknown',
    ]);
    expect(result.issues.single.code, 'jd_direction_unknown');

    final expense = result.groups[0].topLevel as ImportExpenseDraft;
    expect(expense.amount, Money.parse('25.00'));
    expect(expense.category.path, '家居家装');
    expect(expense.note, '虚构家居用品订单');
    expect(result.groups[0].sourceOperationKey, '["expense-1","merchant-1"]');
    expect(result.groups[0].sourceOperationFingerprint, hasLength(64));

    final income = result.groups[1].topLevel as ImportIncomeDraft;
    expect(income.amount, Money.parse('23.22'));
    expect(income.category.path, '其他');
    expect(income.note, '虚构小金库收益');
    expect(income.receiveAccount.sourceEntityKey, 'account:余额');
  });

  test('filters JD Xiaojinku payment methods before parsing facts', () {
    final result = _parser([
      _row(
        direction: '收入',
        amount: '199.99',
        status: '赎回成功',
        paymentMethod: '京东小金库',
        category: '投资理财',
        transactionId: 'xiaojinku-income',
        merchantOrderId: 'merchant-xiaojinku-income',
      ),
      _row(
        direction: '支出',
        date: 'invalid-date',
        amount: 'invalid-amount',
        status: '买入成功',
        paymentMethod: ' 京东小金库 ',
        category: '',
        transactionId: '',
        merchantOrderId: '',
      ),
    ]).parse(_bundle());

    expect(result.fatalIssues, isEmpty);
    expect(result.groups, isEmpty);
    expect(result.sourceAccounts, isEmpty);
    expect(result.issues, isEmpty);
    expect(result.filteredRecords.map((record) => record.reasonCode), [
      'jd_xiaojinku_payment_method',
      'jd_xiaojinku_payment_method',
    ]);
  });

  test('maps 先享后付 to payable and applies other account profiles', () {
    final result = _parser([
      _row(
        direction: '支出',
        amount: '10.00',
        status: '交易成功',
        paymentMethod: '先享后付',
        category: '其他',
        transactionId: 'payable',
        merchantOrderId: 'merchant-payable',
      ),
      _row(
        direction: '支出',
        amount: '11.00',
        status: '交易成功',
        paymentMethod: '余额',
        category: '数码电器',
        transactionId: 'fund',
        merchantOrderId: 'merchant-fund',
      ),
      _row(
        direction: '支出',
        amount: '12.00',
        status: '交易成功',
        paymentMethod: '示例银行(0002)',
        category: '食品酒饮',
        transactionId: 'bank',
        merchantOrderId: 'merchant-bank',
      ),
      _row(
        direction: '支出',
        amount: '13.00',
        status: '交易成功',
        paymentMethod: '某未知方式',
        category: '生活服务',
        transactionId: 'unknown-payment',
        merchantOrderId: 'merchant-unknown-payment',
      ),
    ]).parse(_bundle());

    final accounts = {
      for (final account in result.sourceAccounts)
        account.sourceEntityKey: account,
    };
    expect(accounts['account:先享后付']?.allowedTargetDescriptors, {
      ImportTargetDescriptor.payableAccount,
    });
    expect(
      accounts['account:先享后付']?.preferredTargetDescriptor,
      ImportTargetDescriptor.payableAccount,
    );
    expect(accounts['account:余额']?.allowedTargetDescriptors, {
      ImportTargetDescriptor.fundAccount,
    });
    expect(accounts['account:示例银行(0002)']?.allowedTargetDescriptors, {
      ImportTargetDescriptor.fundAccount,
    });
    expect(accounts['account:某未知方式']?.allowedTargetDescriptors, {
      ImportTargetDescriptor.fundAccount,
      ImportTargetDescriptor.payableAccount,
      ImportTargetDescriptor.creditAccount,
    });
    expect(
      accounts['account:某未知方式']?.preferredTargetDescriptor,
      ImportTargetDescriptor.fundAccount,
    );
  });

  test('filters before parsing a non-income direction amount suffix', () {
    final result = _parser([
      _row(
        direction: '不计收支',
        amount: '9.99(已全额退款)',
        status: '交易成功',
        paymentMethod: '示例银行储蓄卡(0001)',
        category: '其他',
        transactionId: 'filtered-refund',
        merchantOrderId: 'merchant-filtered-refund',
      ),
      _row(
        direction: '支出',
        amount: '9.99(已全额退款)',
        status: '交易成功',
        paymentMethod: '示例银行储蓄卡(0001)',
        category: '其他',
        transactionId: 'invalid-refund',
        merchantOrderId: 'merchant-invalid-refund',
      ),
    ]).parse(_bundle());

    expect(
      result.filteredRecords.single.reasonCode,
      'jd_direction_not_supported',
    );
    expect(result.issues, isEmpty);
    expect(result.groups.single.hasBlockingIssues, isTrue);
    expect(
      result.groups.single.issues.map((issue) => issue.code),
      contains('jd_amount_invalid'),
    );
  });

  test('filters zero amounts and blocks invalid candidate facts', () {
    final result = _parser([
      _row(
        direction: '支出',
        amount: '0.00',
        status: '交易成功',
        paymentMethod: '余额',
        category: '其他',
        transactionId: 'zero',
        merchantOrderId: 'merchant-zero',
      ),
      _row(
        direction: '支出',
        date: '2025-13-40 99:99:99',
        amount: '-1.00',
        status: '交易成功',
        paymentMethod: '先享后付',
        category: '',
        transactionId: '',
        merchantOrderId: '',
      ),
    ]).parse(_bundle());

    expect(result.filteredRecords.single.reasonCode, 'jd_amount_zero');
    final group = result.groups.single;
    expect(group.hasBlockingIssues, isTrue);
    expect(
      group.issues.map((issue) => issue.code),
      containsAll([
        'jd_date_invalid',
        'jd_amount_invalid',
        'category_missing',
        'jd_source_operation_key_missing',
      ]),
    );
    expect(result.sourceCategories.single.isReviewPlaceholder, isTrue);
  });

  test('uses the composite order identity for duplicate detection', () {
    final sameParent = _parser([
      _row(
        direction: '支出',
        amount: '10.00',
        status: '交易成功',
        paymentMethod: '余额',
        category: '数码电器',
        transactionId: 'same-parent',
        merchantOrderId: 'merchant-a',
      ),
      _row(
        direction: '支出',
        amount: '11.00',
        status: '交易成功',
        paymentMethod: '余额',
        category: '数码电器',
        transactionId: 'same-parent',
        merchantOrderId: 'merchant-b',
      ),
    ]).parse(_bundle());
    expect(
      sameParent.groups.every(
        (group) => group.issues.every(
          (issue) => issue.code != 'duplicate_source_operation_key',
        ),
      ),
      isTrue,
    );

    final duplicates = _parser([
      _row(
        direction: '支出',
        amount: '10.00',
        status: '交易成功',
        paymentMethod: '余额',
        category: '数码电器',
        transactionId: 'duplicate',
        merchantOrderId: 'merchant-duplicate',
      ),
      _row(
        direction: '收入',
        amount: '11.00',
        status: '交易成功',
        paymentMethod: '余额',
        category: '其他',
        transactionId: 'duplicate',
        merchantOrderId: 'merchant-duplicate',
      ),
    ]).parse(_bundle());
    expect(
      duplicates.groups.every(
        (group) => group.issues.any(
          (issue) => issue.code == 'duplicate_source_operation_key',
        ),
      ),
      isTrue,
    );
  });

  test('accepts exactly one file and rejects multiple files', () {
    final noFiles = _parser(const []).parse(ImportBundle(files: const []));
    expect(noFiles.fatalIssues.single.code, 'jd_no_input_files');

    final multiple = _parser([_expenseRow()]).parse(
      ImportBundle(
        files: [
          ImportFilePayload(name: 'a.csv', bytes: Uint8List(0)),
          ImportFilePayload(name: 'b.csv', bytes: Uint8List(0)),
        ],
      ),
    );
    expect(multiple.fatalIssues.single.code, 'jd_multiple_files_unsupported');
    expect(multiple.groups, isEmpty);
  });
}

JdImportParser _parser(List<Map<String, Object?>> rows) {
  return JdImportParser(
    reader: _FakeReader(
      ImportTabularFile(
        sheets: [
          ImportTabularSheet(name: '京东商城交易流水', headers: _headers, rows: rows),
        ],
      ),
    ),
  );
}

ImportBundle _bundle() {
  return ImportBundle(
    files: [ImportFilePayload(name: '京东交易流水.csv', bytes: Uint8List(0))],
  );
}

Map<String, Object?> _expenseRow() {
  return _row(
    direction: '支出',
    amount: '25.00',
    status: '交易成功',
    paymentMethod: '余额',
    category: '其他',
    transactionId: 'expense-1',
    merchantOrderId: 'merchant-1',
  );
}

Map<String, Object?> _row({
  String date = '2025-01-03 08:15:21',
  required String direction,
  required String amount,
  required String status,
  required String paymentMethod,
  required String category,
  required String transactionId,
  required String merchantOrderId,
  String note = '虚构交易说明',
}) {
  return {
    '交易时间': date,
    '商户名称': '示例商户',
    '交易说明': note,
    '金额': amount,
    '收/付款方式': paymentMethod,
    '交易状态': status,
    '收/支': direction,
    '交易分类': category,
    '交易订单号': transactionId,
    '商家订单号': merchantOrderId,
    '备注': '',
  };
}

const _headers = [
  '交易时间',
  '商户名称',
  '交易说明',
  '金额',
  '收/付款方式',
  '交易状态',
  '收/支',
  '交易分类',
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
