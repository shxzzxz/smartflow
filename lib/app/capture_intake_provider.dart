import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/intake/intake_recognition_api.dart';
import '../domain/intake/recognition/service/payment_screenshot_parser.dart';
import '../infrastructure/intake/recognition/ledger_recorded_payment_query.dart';
import '../infrastructure/intake/recognition/platform_payment_screenshot.dart';
import 'provider.dart';
import 'recognition_rules_provider.dart';

final _platformPaymentScreenshotProvider = Provider<PlatformPaymentScreenshot>((
  ref,
) {
  final platform = PlatformPaymentScreenshot();
  ref.onDispose(platform.dispose);
  return platform;
});

final sharedPaymentImageSourceProvider = Provider<SharedPaymentImageSource>((
  ref,
) {
  return ref.watch(_platformPaymentScreenshotProvider);
});

final paymentScreenshotImagePickerProvider =
    Provider<PaymentScreenshotImagePicker>((ref) {
      return ref.watch(_platformPaymentScreenshotProvider);
    });

final paymentDuplicateQueryServiceProvider =
    Provider<PaymentDuplicateQueryService>((ref) {
      return PaymentDuplicateQueryService(
        recordedPayments: LedgerRecordedPaymentQuery(
          transactions: ref.watch(transactionQueryServiceProvider),
        ),
      );
    });

final recognizePaymentScreenshotProvider = Provider<RecognizePaymentScreenshot>(
  (ref) {
    return RecognizePaymentScreenshot(
      ocr: ref.watch(_platformPaymentScreenshotProvider),
      loadRules: ref.watch(recognitionRulesAppServiceProvider).loadCatalog,
      parser: const PaymentScreenshotParser(),
    );
  },
);
