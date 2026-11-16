import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/capture_intake_provider.dart';
import 'package:smartflow/application/intake/intake_recognition_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/capture/page/capture_review_page.dart';
import 'package:smartflow/feature/capture/view_model/capture_review_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/presentation/transaction_form_prefill.dart';

void main() {
  testWidgets(
    'ordinary screenshot income opens the income form for confirmation',
    (tester) async {
      await _openReview(
        tester,
        CaptureReviewResult(
          payment: RecognizedPayment(
            direction: RecognizedPaymentDirection.income,
            amount: Money.parse('10'),
          ),
          reviewMessage: '请核对后保存。',
          prefill: TransactionFormPrefill(
            amount: Money.parse('10'),
            occurredAt: DateTime(2026, 4, 5),
            note: '',
            reviewMessage: '请核对后保存。',
          ),
        ),
      );
      expect(find.text('form:income'), findsOneWidget);
      expect(find.byType(CaptureReviewPage), findsNothing);
    },
  );

  final cases = [
    (
      PaymentScreenshotScene.unknown,
      CaptureManualAction.chooseScene,
      '手动记账',
      'form:expense',
    ),
    (
      PaymentScreenshotScene.transfer,
      CaptureManualAction.transfer,
      '手动记录转账',
      'form:transfer',
    ),
    (
      PaymentScreenshotScene.refund,
      CaptureManualAction.transactions,
      '前往交易记录',
      '交易记录',
    ),
    (
      PaymentScreenshotScene.repayment,
      CaptureManualAction.accounts,
      '前往账户还款',
      '账户',
    ),
  ];
  for (final entry in cases) {
    testWidgets(
      'manual review preserves ${entry.$1.name} until the user acts',
      (tester) async {
        await _openReview(
          tester,
          CaptureReviewResult(
            payment: RecognizedPayment(
              scene: entry.$1,
              amount: Money.parse('10'),
            ),
            reviewMessage: '该场景需要手动处理。',
            manualAction: entry.$2,
          ),
        );
        expect(find.byType(CaptureReviewPage), findsOneWidget);
        expect(find.text('该场景需要手动处理。'), findsOneWidget);
        expect(find.text('form:expense'), findsNothing);
        await tester.tap(find.text(entry.$3));
        await tester.pumpAndSettle();
        expect(find.text(entry.$4), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'dismissing the internal image picker returns to the invoking page',
    (tester) async {
      final picker = _CancelledPicker();
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/capture'),
                child: const Text('截图记账入口'),
              ),
            ),
          ),
          GoRoute(
            path: '/capture',
            builder: (context, state) => const CaptureReviewPage(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentScreenshotImagePickerProvider.overrideWithValue(picker),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('截图记账入口'));
      await tester.pumpAndSettle();
      expect(picker.calls, 1);
      expect(find.text('截图记账入口'), findsOneWidget);
      expect(find.byType(CaptureReviewPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _openReview(
  WidgetTester tester,
  CaptureReviewResult result,
) async {
  final router = GoRouter(
    initialLocation: '/capture',
    routes: [
      GoRoute(
        path: '/capture',
        builder: (_, state) => const CaptureReviewPage(shareId: 'image'),
      ),
      GoRoute(
        path: '/',
        builder: (_, state) => const Scaffold(body: Text('交易记录')),
      ),
      GoRoute(
        path: '/account',
        builder: (_, state) => const Scaffold(body: Text('账户')),
      ),
      GoRoute(
        path: '/transaction/new',
        builder: (_, state) => Scaffold(
          body: Text('form:${state.uri.queryParameters['mode'] ?? 'expense'}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        captureReviewViewModelProvider.overrideWith2(
          (sessionKey) => _ReviewModel(result, sessionKey),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _ReviewModel extends CaptureReviewViewModel {
  _ReviewModel(this.result, super.sessionKey);
  final CaptureReviewResult result;
  @override
  Future<UiActionOutcome<CaptureReviewResult>?> recognize(
    String shareId,
  ) async {
    state = CaptureReviewState(review: result);
    return UiActionSuccess(result);
  }
}

class _CancelledPicker implements PaymentScreenshotImagePicker {
  int calls = 0;
  @override
  Future<String?> pickImage() async {
    calls++;
    return null;
  }
}
