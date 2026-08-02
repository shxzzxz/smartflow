import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
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

  Future<void> refreshDisplayedBillsForAccount({
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
}

class CreditBillGenerationAppServiceImpl
    implements CreditBillGenerationAppService {
  CreditBillGenerationAppServiceImpl({
    required CreditAccountRepository creditAccounts,
    required CreditLedgerPort ledger,
    required InstallmentRepository installments,
    required RepaymentRepository repayments,
    required BillRepository bills,
    required CreditBillSourceRepository billSources,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
    SettlementJudgementService judgement = const SettlementJudgementService(),
    CreditBillGenerationService? generationService,
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
             billSources: billSources,
             idGenerator: idGenerator,
             judgement: judgement,
           );

  final CreditAccountRepository _creditAccounts;
  final CreditLedgerPort _ledger;
  final TransactionRunner _runner;
  final CreditBillGenerationService _generation;

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
    return _runner.run<void>(() async {
      await _generation.refreshBill(billId);
    });
  }

  @override
  Future<void> refreshDisplayedBillsForAccount({
    required String accountId,
    required DateTime now,
  }) async {
    final account = await _creditAccounts.findByAccountId(accountId);
    if (account == null) return;
    return _runner.run<void>(() async {
      await _generation.refreshDisplayedBillsForAccount(
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
}
