import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/import/service/yimu_file_handlers.dart';
import 'package:smartflow/domain/import/service/yimu_file_type.dart';
import 'package:smartflow/domain/import/port/yimu_workbook_reader.dart';

void main() {
  test('each file handler validates its own template structure', () {
    final issues = const YimuBillFileHandler().validate(
      fileName: '账单.xls',
      sheet: YimuSheet(
        name: '账单',
        headers: const ['日期', '收支类型', '金额'],
        rows: const [
          {'日期': '2026-07-01', '收支类型': '支出', '金额': '1'},
        ],
      ),
    );

    expect(issues.single.code, 'unsupported_headers');
    expect(issues.single.fileType, YimuFileType.bill.descriptor);
    expect(issues.single.isFatal, isTrue);
  });

  test('normalizes bill rows into typed source facts', () {
    final fact = const YimuBillFileHandler().handle(
      fileIndex: 2,
      fileName: '账单.xls',
      sheet: YimuSheet(
        name: '账单',
        headers: const ['日期', '收支类型', '金额', '类别', '账户'],
        rows: const [
          {
            '日期': '2026/07/01',
            '入账日期': '2026/07/02',
            '收支类型': '支出',
            '金额': '12.30',
            '类别': '食品餐饮',
            '二级分类': '午餐',
            '账户': '现金',
            '交易ID': 'B-1',
            '备注': '工作日午餐',
          },
        ],
      ),
    );

    final record = fact.records.single as YimuBillRecord;
    expect(record.rowNumber, 2);
    expect(record.kind, '支出');
    expect(record.occurredAt, DateTime(2026, 7, 1));
    expect(record.postedAt, DateTime(2026, 7, 2));
    expect(record.amount, Money.parse('12.30'));
    expect(record.categoryPath, '食品餐饮 / 午餐');
    expect(record.accountName, '现金');
    expect(record.note, '工作日午餐');
    expect(record.sourceOperationKey, 'bill:b-1');
    expect(record.issues, isEmpty);
    expect(fact.issues, isEmpty);
  });

  test('keeps normalized fallbacks and row issues for invalid fields', () {
    final fact = const YimuBillFileHandler().handle(
      fileIndex: 0,
      fileName: '账单.xls',
      sheet: YimuSheet(
        name: '账单',
        rows: const [
          {
            '日期': 'not-a-date',
            '收支类型': '收入',
            '金额': 'not-a-money',
            '类别': '工资',
            '账户': '现金',
          },
        ],
      ),
    );

    final record = fact.records.single as YimuBillRecord;
    expect(record.occurredAt, DateTime(1970, 1, 1));
    expect(record.postedAt, DateTime(1970, 1, 1));
    expect(record.amount, Money.zero());
    expect(
      record.issues.map((issue) => issue.code),
      containsAll(<String>['date_invalid', '金额_invalid']),
    );
    expect(fact.issues, containsAll(record.issues));
  });

  test('normalizes movement accounts and fee without exposing row maps', () {
    final fact = const YimuTransferFileHandler().handle(
      fileIndex: 1,
      fileName: '转账.xls',
      sheet: YimuSheet(
        name: '转账',
        rows: const [
          {
            '日期': '2026-07-03',
            '类型': '转账',
            '转出账户': '现金',
            '转入账户': '银行卡',
            '金额': '100',
            '手续费': '1.20',
            '备注': '存款',
            '操作ID': 'T-1',
          },
        ],
      ),
    );

    final record = fact.records.single as YimuTransferRecord;
    expect(record.kind, '转账');
    expect(record.fromAccountName, '现金');
    expect(record.toAccountName, '银行卡');
    expect(record.amount, Money.parse('100'));
    expect(record.feeAmount, Money.parse('1.20'));
    expect(record.sourceOperationKey, 'transfer:t-1');
    expect(record.issues, isEmpty);
  });

  test('keeps debt records distinct for loan-specific parse units', () {
    final fact = const YimuDebtFileHandler().handle(
      fileIndex: 0,
      fileName: '债务.xls',
      sheet: YimuSheet(
        name: '债务',
        rows: const [
          {
            '日期': '2026-07-04',
            '类型': '借入',
            '转出账户': '无账户',
            '转入账户': '房贷',
            '金额': '1000',
          },
        ],
      ),
    );

    expect(fact.records.single, isA<YimuDebtRecord>());
    final record = fact.records.single as YimuDebtRecord;
    expect(record.fromAccountName, '无账户');
    expect(record.toAccountName, '房贷');
    expect(record.kind, '借入');
  });
}
