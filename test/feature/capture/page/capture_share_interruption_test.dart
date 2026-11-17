import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/capture_intake_navigation.dart';
import 'package:smartflow/app/capture_intake_provider.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/intake/intake_recognition_api.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule_catalog.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/capture/page/capture_review_page.dart';

import '../../../helper/test_app_database.dart';

void main() {
  for (final lateSelection in <String?>[null, 'old-selected-image']) {
    for (final afterFrame in [false, true]) {
      testWidgets(
        'shared image survives picker result $lateSelection afterFrame=$afterFrame',
        (tester) async {
          final picker = _PendingPicker();
          final recognizer = _RecordingRecognizer();
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
                builder: (_, _) => const CaptureReviewPage(),
              ),
              GoRoute(
                path: '/capture/:id',
                builder: (_, state) =>
                    CaptureReviewPage(shareId: state.pathParameters['id']!),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                testAppDatabaseOverride(),
                builtinRecognitionRuleCatalogProvider.overrideWithValue(
                  RecognitionRuleCatalog(rules: const []),
                ),
                paymentScreenshotImagePickerProvider.overrideWithValue(picker),
                recognizePaymentScreenshotProvider.overrideWithValue(
                  recognizer,
                ),
              ],
              child: MaterialApp.router(
                theme: AppTheme.light(),
                routerConfig: router,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('截图记账入口'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(picker.calls, 1);
          openSharedPaymentImage(
            router,
            const SharedPaymentImage(id: 'shared-image'),
          );
          if (afterFrame) await tester.pump();
          picker.result.complete(lateSelection);
          await tester.pumpAndSettle();
          expect(recognizer.ids, ['shared-image']);
          expect(find.text('交易未成功，无法记账。'), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(router.canPop(), isTrue);
          router.pop();
          await tester.pumpAndSettle();
          expect(find.text('截图记账入口'), findsOneWidget);
        },
      );
    }
  }
}

class _PendingPicker implements PaymentScreenshotImagePicker {
  final result = Completer<String?>();
  int calls = 0;

  @override
  Future<String?> pickImage() {
    calls++;
    return result.future;
  }
}

class _RecordingRecognizer implements RecognizePaymentScreenshot {
  final ids = <String>[];

  @override
  Future<RecognizedPayment> call(String shareId) async {
    ids.add(shareId);
    return RecognizedPayment(scene: PaymentScreenshotScene.unpaid);
  }
}
