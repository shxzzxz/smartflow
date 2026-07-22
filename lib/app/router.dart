import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import '../application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import '../feature/account/page/account_detail_page.dart';
import '../feature/account/page/account_bills_page.dart';
import '../feature/account/page/account_form_page.dart';
import '../feature/account/page/accounts_page.dart';
import '../feature/category/page/categories_page.dart';
import '../feature/category/page/category_form_page.dart';
import '../feature/calendar/page/calendar_page.dart';
import '../feature/home/page/home_page.dart';
import '../feature/credit/page/installment_contract_edit_page.dart';
import '../feature/credit/page/bill_conversion_installment_form_page.dart';
import '../feature/credit/page/bill_detail_page.dart';
import '../feature/credit/page/bill_repayment_form_page.dart';
import '../feature/credit/page/installment_detail_page.dart';
import '../feature/credit/page/installment_form_page.dart';
import '../feature/credit/page/installment_repayment_form_page.dart';
import '../feature/credit/page/repayment_form_page.dart';
import '../feature/credit/page/unattributed_repayment_form_page.dart';
import '../feature/placeholder/page/placeholder_page.dart';
import '../feature/statistics/page/statistics_page.dart';
import '../feature/statistics/page/statistics_transactions_page.dart';
import '../feature/statistics/view_model/statistics_view_model.dart';
import '../feature/profile/page/installment_guide_page.dart';
import '../feature/profile/page/profile_page.dart';
import '../feature/profile/page/software_version_page.dart';
import '../feature/transaction/page/refund_form_page.dart';
import '../feature/transaction/page/reimbursement_close_form_page.dart';
import '../feature/transaction/page/reimbursement_edit_form_page.dart';
import '../feature/transaction/page/reimbursement_receipt_form_page.dart';
import '../feature/transaction/page/transaction_detail_page.dart';
import '../feature/transaction/page/transaction_form_page.dart';

final appRouter = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/account',
          builder: (context, state) => const AccountsPage(),
        ),
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const CalendarPage(),
        ),
        GoRoute(
          path: '/statistics',
          builder: (context, state) => const StatisticsPage(),
        ),
        GoRoute(
          path: '/statistics/transactions',
          builder: (context, state) {
            final query = state.uri.queryParameters;
            final from = DateTime.tryParse(query['from'] ?? '');
            final until = DateTime.tryParse(query['until'] ?? '');
            final scope = switch (query['scope']) {
              'balance' => StatisticsDrilldownScope.balance,
              _ => StatisticsDrilldownScope.cashflow,
            };
            if (until == null) {
              return const PlaceholderPage(title: '统计流水参数无效');
            }
            return StatisticsTransactionsPage(
              title: query['title'] ?? '统计流水',
              accountIdsKey: query['accountIds'] ?? '',
              occurredFrom: from,
              occurredUntil: until,
              scope: scope,
            );
          },
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
      ],
    ),
    GoRoute(
      path: '/transaction/new',
      builder: (context, state) {
        final mode = switch (state.uri.queryParameters['mode']) {
          'income' => TransactionFormInitialMode.income,
          'transfer' => TransactionFormInitialMode.transfer,
          'borrowing' => TransactionFormInitialMode.borrowing,
          _ => TransactionFormInitialMode.expense,
        };
        return TransactionFormPage(
          initialMode: mode,
          initialFromAccountId: state.uri.queryParameters['fromAccountId'],
          initialToAccountId: state.uri.queryParameters['toAccountId'],
        );
      },
    ),
    GoRoute(
      path: '/transaction/:id',
      builder:
          (context, state) =>
              TransactionDetailPage(transactionId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/transaction/:id/edit',
      builder:
          (context, state) => TransactionFormPage(
            editTransactionId: state.pathParameters['id']!,
          ),
    ),
    GoRoute(
      path: '/transaction/:id/repayment/edit',
      builder:
          (context, state) => RepaymentFormPage.edit(
            editTransactionId: state.pathParameters['id']!,
          ),
    ),
    GoRoute(
      path: '/transaction/:id/refund',
      builder:
          (context, state) =>
              RefundFormPage(parentTransactionId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/transaction/:id/refund/edit',
      builder:
          (context, state) => RefundFormPage.edit(
            editTransactionId: state.pathParameters['id']!,
          ),
    ),
    GoRoute(
      path: '/transaction/:id/reimburse-receipt',
      builder:
          (context, state) => ReimbursementReceiptFormPage(
            advanceTransactionId: state.pathParameters['id']!,
          ),
    ),
    GoRoute(
      path: '/transaction/:id/reimburse-close',
      builder:
          (context, state) => ReimbursementCloseFormPage(
            advanceTransactionId: state.pathParameters['id']!,
          ),
    ),
    GoRoute(
      path: '/transaction/:id/reimbursement/edit',
      builder:
          (context, state) => ReimbursementEditFormPage(
            transactionId: state.pathParameters['id']!,
          ),
    ),
    GoRoute(
      path: '/account/new',
      builder: (context, state) => const AccountFormPage(),
    ),
    GoRoute(
      path: '/account/:id',
      builder:
          (context, state) =>
              AccountDetailPage(accountId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/account/:id/edit',
      builder:
          (context, state) =>
              AccountFormPage(accountId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/account/:id/bills',
      builder:
          (context, state) =>
              AccountBillsPage(accountId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/account/:id/repayment',
      builder:
          (context, state) => RepaymentFormPage(
            liabilityAccountId: state.pathParameters['id']!,
          ),
    ),
    GoRoute(
      path: '/account/:id/unattributed-repayment',
      builder:
          (context, state) => UnattributedRepaymentFormPage(
            accountId: state.pathParameters['id']!,
          ),
    ),
    GoRoute(
      path: '/account/:id/installments/new',
      builder: (context, state) {
        final lockedSourceType = switch (state.uri.queryParameters['source']) {
          'disbursement' => InstallmentSourceType.disbursement,
          _ => null,
        };
        return InstallmentFormPage(
          liabilityAccountId: state.pathParameters['id']!,
          lockedSourceType: lockedSourceType,
        );
      },
    ),
    GoRoute(
      path: '/bills/:billId',
      builder:
          (context, state) =>
              BillDetailPage(billId: state.pathParameters['billId']!),
    ),
    GoRoute(
      path: '/bills/:billId/repay',
      builder:
          (context, state) =>
              BillRepaymentFormPage(billId: state.pathParameters['billId']!),
    ),
    GoRoute(
      path: '/repayments/:repaymentId/edit',
      builder:
          (context, state) => BillRepaymentFormPage.edit(
            repaymentId: state.pathParameters['repaymentId']!,
            resultTransactionId: state.uri.queryParameters['transactionId'],
          ),
    ),
    GoRoute(
      path: '/bills/:billId/installment',
      builder:
          (context, state) => BillConversionInstallmentFormPage(
            billId: state.pathParameters['billId']!,
          ),
    ),
    GoRoute(
      path: '/installments/:contractId',
      builder:
          (context, state) => InstallmentDetailPage(
            contractId: state.pathParameters['contractId']!,
          ),
    ),
    GoRoute(
      path: '/installments/:contractId/edit',
      builder:
          (context, state) => InstallmentContractEditPage(
            contractId: state.pathParameters['contractId']!,
          ),
    ),
    GoRoute(
      path: '/installments/:contractId/repay',
      builder:
          (context, state) => InstallmentRepaymentFormPage(
            contractId: state.pathParameters['contractId']!,
          ),
    ),
    GoRoute(
      path: '/category',
      builder: (context, state) => const CategoriesPage(),
    ),
    GoRoute(
      path: '/profile/software-version',
      builder: (context, state) => const SoftwareVersionPage(),
    ),
    GoRoute(
      path: '/profile/installment-guide',
      builder: (context, state) => const InstallmentGuidePage(),
    ),
    GoRoute(
      path: '/category/new',
      builder: (context, state) {
        final type = switch (state.uri.queryParameters['type']) {
          'income' => AccountType.income,
          'expense' => AccountType.expense,
          _ => AccountType.expense,
        };
        final parentId = state.uri.queryParameters['parentId'];
        return CategoryFormPage(initialType: type, initialParentId: parentId);
      },
    ),
    GoRoute(
      path: '/category/:id/edit',
      builder:
          (context, state) =>
              CategoryFormPage(categoryId: state.pathParameters['id']!),
    ),
  ],
);
