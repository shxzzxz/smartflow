import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/intake/import/import_models.dart';
import 'package:smartflow/domain/intake/import/port/import_file_reader.dart';
import 'package:smartflow/domain/intake/import/source/wechat/wechat_import_parser.dart';

void main() {
  test(
    'extracts category evidence without source categories or internal targets',
    () {
      final result = _parser([
        _row(
          counterparty: '瑞幸咖啡',
          product: '拿铁',
          direction: '支出',
          status: '支付成功',
        ),
      ]).parse(_bundle());
      final category =
          (result.groups.single.topLevel as ImportExpenseDraft).category;
      expect(result.sourceCategories, isEmpty);
      expect(category.sourceEntityKey, isNull);
      expect(category.isInferred, isTrue);
      expect(category.kind, ImportCategoryKind.expense);
      expect(category.matchingText, '瑞幸咖啡\n拿铁\n商户消费\n支付成功');
      expect(result.groups.single.issues, isEmpty);
    },
  );

  test('classification evidence excludes payment-account and note text', () {
    final result = _parser([
      _row(
        counterparty: '示例商户',
        product: '虚构商品',
        direction: '支出',
        status: '支付成功',
        paymentMethod: '瑞幸账户',
        note: '咖啡备注',
      ),
    ]).parse(_bundle());
    final category = result.inferredCategories.single;
    expect(category.matchingText, isNot(contains('瑞幸')));
    expect(category.matchingText, isNot(contains('咖啡备注')));
    expect(category.matchingText, contains('虚构商品'));
  });

  test(
    'retains account text and source constraints for later account parsing',
    () {
      final result = _parser([
        _row(
          counterparty: '瑞幸咖啡',
          product: '拿铁',
          direction: '支出',
          status: '支付成功',
          paymentMethod: '示例银行储蓄卡(1234)',
        ),
      ]).parse(_bundle());
      final expense = result.groups.single.topLevel as ImportExpenseDraft;
      final account = result.sourceAccounts.single;
      expect(expense.paidFrom.displayName, '示例银行储蓄卡(1234)');
      expect(account.displayName, expense.paidFrom.displayName);
      expect(account.allowedTargetDescriptors, {
        ImportTargetDescriptor.fundAccount,
      });
      expect(result.sourceCategories, isEmpty);
    },
  );

  test('maps directions and writes only the product into the note', () {
    final result = _parser([
      _row(
        transactionType: '商户消费',
        counterparty: '示例面馆',
        product: '牛肉面',
        direction: '支出',
        status: '支付成功',
        note: '来源备注不写入交易备注',
      ),
      _row(
        transactionType: '转账',
        counterparty: '示例公司',
        product: '工资',
        direction: '收入',
        status: '已到账',
        note: '来源备注不写入交易备注',
        transactionId: 'second',
      ),
    ]).parse(_bundle());
    expect(result.groups, hasLength(2));
    expect(result.groups[0].topLevel, isA<ImportExpenseDraft>());
    expect(result.groups[0].topLevel.note, '牛肉面');
    expect(result.groups[1].topLevel, isA<ImportIncomeDraft>());
    expect(result.groups[1].topLevel.note, '工资');
    expect(result.inferredCategories.map((category) => category.kind), [
      ImportCategoryKind.expense,
      ImportCategoryKind.income,
    ]);
  });

  test('uses WeChat change as receiving account when status confirms it', () {
    final result = _parser([
      _row(
        transactionType: '转账',
        counterparty: '演示好友',
        product: '虚构转账',
        direction: '收入',
        status: '已存入零钱',
        paymentMethod: '/',
      ),
    ]).parse(_bundle());
    final income = result.groups.single.topLevel as ImportIncomeDraft;
    expect(income.receiveAccount.sourceEntityKey, 'account:零钱');
    expect(income.receiveAccount.displayName, '零钱');
  });

  test(
    'each record keeps its own category candidate even with identical text',
    () {
      final result = _parser([
        _row(product: '拿铁', direction: '支出', status: '支付成功'),
        _row(
          product: '拿铁',
          direction: '支出',
          status: '支付成功',
          transactionId: 'second',
        ),
      ]).parse(_bundle());
      expect(result.inferredCategories, hasLength(2));
      expect(
        result.inferredCategories
            .map((category) => category.referenceKey)
            .toSet(),
        hasLength(2),
      );
      expect(result.sourceCategories, isEmpty);
    },
  );

  test('retains refund and income evidence for shared classification', () {
    final result = _parser([
      _row(
        transactionType: '示例商户-退款',
        counterparty: '示例公司',
        product: '工资',
        direction: '收入',
        status: '已全额退款',
        paymentMethod: '示例银行储蓄卡(0001)',
      ),
    ]).parse(_bundle());
    final income = result.groups.single.topLevel as ImportIncomeDraft;
    expect(income.category.kind, ImportCategoryKind.income);
    expect(income.category.matchingText, contains('退款'));
    expect(income.category.matchingText, contains('工资'));
    expect(result.sourceCategories, isEmpty);
  });
}

WechatImportParser _parser(List<Map<String, Object?>> rows) =>
    WechatImportParser(
      reader: _FakeReader(
        ImportTabularFile(
          sheets: [
            ImportTabularSheet(name: '微信支付账单', headers: _headers, rows: rows),
          ],
        ),
      ),
    );

ImportBundle _bundle() {
  return ImportBundle(
    files: [ImportFilePayload(name: '微信支付账单流水文件.xlsx', bytes: Uint8List(0))],
  );
}

Map<String, Object?> _row({
  String transactionType = '商户消费',
  String counterparty = '示例商户',
  String product = '虚构商品',
  required String direction,
  required String status,
  String paymentMethod = '零钱',
  String note = '/',
  String transactionId = '9000000000000000000000000001',
}) {
  return {
    '交易时间': DateTime(2025, 12, 24, 12, 15),
    '交易类型': transactionType,
    '交易对方': counterparty,
    '商品': product,
    '收/支': direction,
    '金额(元)': 1.23,
    '支付方式': paymentMethod,
    '当前状态': status,
    '交易单号': transactionId,
    '商户单号': '/',
    '备注': note,
  };
}

const _headers = [
  '交易时间',
  '交易类型',
  '交易对方',
  '商品',
  '收/支',
  '金额(元)',
  '支付方式',
  '当前状态',
  '交易单号',
  '商户单号',
  '备注',
];

class _FakeReader implements ImportFileReader {
  const _FakeReader(this.workbook);

  final ImportTabularFile workbook;

  @override
  ImportTabularFile read(ImportFilePayload file) => workbook;
}
