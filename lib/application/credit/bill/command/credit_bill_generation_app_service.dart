import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/bill_generation_suppression_repository.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/credit_bill_source_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/bill/credit_bill_generation_service.dart';
import 'package:smartflow/domain/credit/service/settlement/settlement_judgement_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';

abstract interface class CreditBillGenerationAppService {
  Future<void> generateDueBills({required DateTime now});

  Future<void> generateDueBillsForAccount({
    required String accountId,
    required DateTime now,
  });

  Future<void> generateBillForPeriod({
    required String accountId,
    required BillPeriod period,
    required DateTime now,
  });

  Future<void> refreshBill(String billId);

  Future<void> refreshCurrentAndFutureBillsForAccount({
    required String accountId,
    required DateTime now,
  });

  /// 删除无还款记录的账单。
  Future<void> deleteBill(String billId);

  /// 调整账单起始日 / 出账日；区间不得与相邻账单重叠。
  Future<void> updateBillWindow({
    required String billId,
    required DateTime startDate,
    required DateTime billingDate,
  });

  Future<void> updateConsumptionWindow({
    required String billId,
    required String billItemId,
    required DateTime startInclusive,
    required DateTime endInclusive,
  });
}

class CreditBillGenerationAppServiceImpl
    implements CreditBillGenerationAppService {
  CreditBillGenerationAppServiceImpl({
    required CreditAccountRepository creditAccounts,
    required CreditLedgerPort ledger,
    required InstallmentRepository installments,
    required RepaymentRepository repayments,
    required BillRepository bills,
    required BillGenerationSuppressionRepository suppressions,
    required CreditBillSourceRepository billSources,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
    SettlementJudgementService judgement = const SettlementJudgementService(),
    CreditBillGenerationService? generationService,
    DateTime Function()? now,
  }) : _creditAccounts = creditAccounts,
       _ledger = ledger,
       _runner = transactionRunner,
       _generation =
           generationService ??
           CreditBillGenerationService(
             creditAccounts: creditAccounts,
             installments: installments,
             repayments: repayments,
             bills: bills,
             suppressions: suppressions,
             billSources: billSources,
             idGenerator: idGenerator,
             judgement: judgement,
             now: now,
           );

  final CreditAccountRepository _creditAccounts;
  final CreditLedgerPort _ledger;
  final TransactionRunner _runner;
  final CreditBillGenerationService _generation;
  final _refreshes = <String, Future<void>>{};

  @override
  Future<void> generateDueBills({required DateTime now}) async {
    final accounts = await _creditAccounts.listAll();
    for (final account in accounts) {
      await generateDueBillsForAccount(accountId: account.accountId, now: now);
    }
  }

  @override
  Future<void> generateDueBillsForAccount({
    required String accountId,
    required DateTime now,
  }) async {
    final creditAccount = await _creditAccounts.findByAccountId(accountId);
    if (creditAccount == null) return;
    await _runner.run<void>(() async {
      final ledgerAccount = await _ledger.findAccount(accountId);
      if (ledgerAccount == null || ledgerAccount.isArchived) return;
      await _generation.generateDueBillsForAccount(
        account: creditAccount,
        now: now,
      );
    });
  }

  @override
  Future<void> generateBillForPeriod({
    required String accountId,
    required BillPeriod period,
    required DateTime now,
  }) async {
    final account = await _creditAccounts.findByAccountId(accountId);
    if (account == null) return;
    return _runner.run<void>(() async {
      await _generation.generateBillForPeriod(
        account: account,
        period: period,
        now: now,
      );
    });
  }

  @override
  Future<void> refreshBill(String billId) {
    final existing = _refreshes[billId];
    if (existing != null) return existing;
    late final Future<void> refresh;
    refresh = _runner
        .run<void>(() async {
          await _generation.refreshBill(billId);
        })
        .whenComplete(() {
          if (identical(_refreshes[billId], refresh)) _refreshes.remove(billId);
        });
    _refreshes[billId] = refresh;
    return refresh;
  }

  @override
  Future<void> refreshCurrentAndFutureBillsForAccount({
    required String accountId,
    required DateTime now,
  }) async {
    final account = await _creditAccounts.findByAccountId(accountId);
    if (account == null) return;
    return _runner.run<void>(() async {
      await _generation.refreshCurrentAndFutureBillsForAccount(
        account: account,
        now: now,
      );
    });
  }

  @override
  Future<void> deleteBill(String billId) {
    return _runner.run<void>(() async {
      await _generation.deleteBill(billId);
    });
  }

  @override
  Future<void> updateBillWindow({
    required String billId,
    required DateTime startDate,
    required DateTime billingDate,
  }) {
    return _runner.run<void>(() async {
      await _generation.updateBillWindow(
        billId: billId,
        startDate: startDate,
        billingDate: billingDate,
      );
    });
  }

  @override
  Future<void> updateConsumptionWindow({
    required String billId,
    required String billItemId,
    required DateTime startInclusive,
    required DateTime endInclusive,
  }) {
    return _runner.run<void>(() async {
      await _generation.updateConsumptionWindow(
        billId: billId,
        billItemId: billItemId,
        startInclusive: startInclusive,
        endInclusive: endInclusive,
      );
    });
  }
}
