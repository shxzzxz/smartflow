import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import '../application/accounting/accounting_api.dart';
import 'package:smartflow/application/credit/credit_api.dart';
import '../features/accounts/pages/account_detail_page.dart';
import '../features/accounts/pages/account_form_page.dart';
import '../features/accounts/pages/accounts_page.dart';
import '../features/categories/pages/categories_page.dart';
import '../features/categories/pages/category_form_page.dart';
import '../features/calendar/pages/calendar_page.dart';
import '../features/home/pages/home_page.dart';
import '../features/credit/pages/installment_contract_edit_page.dart';
import '../features/credit/pages/installment_detail_page.dart';
import '../features/credit/pages/installment_form_page.dart';
import '../features/credit/pages/installment_repayment_form_page.dart';
import '../features/credit/pages/repayment_form_page.dart';
import '../features/placeholder/pages/placeholder_page.dart';
import '../features/profile/pages/installment_guide_page.dart';
import '../features/profile/pages/profile_page.dart';
import '../features/profile/pages/software_version_page.dart';
import '../features/transactions/pages/refund_form_page.dart';
import '../features/transactions/pages/reimbursement_close_form_page.dart';
import '../features/transactions/pages/reimbursement_receipt_form_page.dart';
import '../features/transactions/pages/transaction_detail_page.dart';
import '../features/transactions/pages/transaction_form_page.dart';

final appRouter = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/accounts',
          builder: (context, state) => const AccountsPage(),
        ),
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const CalendarPage(),
        ),
        GoRoute(
          path: '/statistics',
          builder: (context, state) => const PlaceholderPage(title: '统计'),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
      ],
    ),
    GoRoute(
      path: '/transactions/new',
      builder: (context, state) {
        final mode = switch (state.uri.queryParameters['mode']) {
          'income' => TransactionFormInitialMode.income,
          'transfer' => TransactionFormInitialMode.transfer,
          'borrowing' => TransactionFormInitialMode.borrowing,
          _ => TransactionFormInitialMode.expense,
        };
        return TransactionFormPage(
          initialMode: mode,
          initialFromAccountId: int.tryParse(
            state.uri.queryParameters['fromAccountId'] ?? '',
          ),
          initialToAccountId: int.tryParse(
            state.uri.queryParameters['toAccountId'] ?? '',
          ),
        );
      },
    ),
    GoRoute(
      path: '/transactions/:id',
      builder:
          (context, state) => TransactionDetailPage(
            transactionId: int.parse(state.pathParameters['id']!),
          ),
    ),
    GoRoute(
      path: '/transactions/:id/edit',
      builder:
          (context, state) => TransactionFormPage(
            editTransactionId: int.parse(state.pathParameters['id']!),
          ),
    ),
    GoRoute(
      path: '/transactions/:id/repayment/edit',
      builder:
          (context, state) => RepaymentFormPage.edit(
            editTransactionId: int.parse(state.pathParameters['id']!),
          ),
    ),
    GoRoute(
      path: '/transactions/:id/refund',
      builder:
          (context, state) => RefundFormPage(
            parentTransactionId: int.parse(state.pathParameters['id']!),
          ),
    ),
    GoRoute(
      path: '/transactions/:id/reimburse-receipt',
      builder:
          (context, state) => ReimbursementReceiptFormPage(
            advanceTransactionId: int.parse(state.pathParameters['id']!),
          ),
    ),
    GoRoute(
      path: '/transactions/:id/reimburse-close',
      builder:
          (context, state) => ReimbursementCloseFormPage(
            advanceTransactionId: int.parse(state.pathParameters['id']!),
          ),
    ),
    GoRoute(
      path: '/accounts/new',
      builder: (context, state) => const AccountFormPage(),
    ),
    GoRoute(
      path: '/accounts/:id',
      builder:
          (context, state) => AccountDetailPage(
            accountId: int.parse(state.pathParameters['id']!),
          ),
    ),
    GoRoute(
      path: '/accounts/:id/edit',
      builder:
          (context, state) => AccountFormPage(
            accountId: int.parse(state.pathParameters['id']!),
          ),
    ),
    GoRoute(
      path: '/accounts/:id/repayment',
      builder:
          (context, state) => RepaymentFormPage(
            liabilityAccountId: int.parse(state.pathParameters['id']!),
          ),
    ),
    GoRoute(
      path: '/accounts/:id/installments/new',
      builder: (context, state) {
        final lockedSourceType = switch (state.uri.queryParameters['source']) {
          'disbursement' => InstallmentSourceType.disbursement,
          'bill' => InstallmentSourceType.billConversion,
          _ => null,
        };
        return InstallmentFormPage(
          liabilityAccountId: int.parse(state.pathParameters['id']!),
          lockedSourceType: lockedSourceType,
        );
      },
    ),
    GoRoute(
      path: '/installments/:contractId',
      builder:
          (context, state) => InstallmentDetailPage(
            contractId: int.parse(state.pathParameters['contractId']!),
          ),
    ),
    GoRoute(
      path: '/installments/:contractId/edit',
      builder:
          (context, state) => InstallmentContractEditPage(
            contractId: int.parse(state.pathParameters['contractId']!),
          ),
    ),
    GoRoute(
      path: '/installments/:contractId/repay',
      builder: (context, state) {
        final contractId = int.parse(state.pathParameters['contractId']!);
        final mode = switch (state.uri.queryParameters['mode']) {
          'extra' => InstallmentRepaymentMode.extraPrincipal,
          'settle' => InstallmentRepaymentMode.earlySettlement,
          _ => InstallmentRepaymentMode.scheduled,
        };
        final scheduleId = int.tryParse(
          state.uri.queryParameters['scheduleId'] ?? '',
        );
        return InstallmentRepaymentFormPage(
          contractId: contractId,
          mode: mode,
          scheduleId: scheduleId,
        );
      },
    ),
    GoRoute(
      path: '/categories',
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
      path: '/categories/new',
      builder: (context, state) {
        final type = switch (state.uri.queryParameters['type']) {
          'income' => AccountType.income,
          'expense' => AccountType.expense,
          _ => AccountType.expense,
        };
        final parentId = int.tryParse(
          state.uri.queryParameters['parentId'] ?? '',
        );
        return CategoryFormPage(initialType: type, initialParentId: parentId);
      },
    ),
  ],
);
