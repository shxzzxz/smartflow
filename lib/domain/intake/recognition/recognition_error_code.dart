import '../../../core/error/app_error_code.dart';

enum RecognitionErrorCode implements AppErrorCode {
  unsupportedPlatform('capture.unsupported_platform', '截图记账当前仅支持 Android。'),
  imagePickFailed('capture.image_pick_failed', '无法选择截图，请稍后重试。'),
  unsupportedScreenshot(
    'capture.unsupported_screenshot',
    '请选择或分享单笔交易详情截图。',
  ),
  unpaidTransaction('capture.unpaid_transaction', '截图中的交易未成功支付，请核对后手动记账。'),
  unsupportedTransaction(
    'capture.unsupported_transaction',
    '该截图包含退款、转账或还款，请选择对应场景手动记账。',
  ),
  amountMissing('capture.amount_missing', '未能确定实际支付金额，请使用完整详情截图或手动记账。'),
  imageUnavailable('capture.image_unavailable', '截图已不可用，请重新选择或分享。'),
  invalidImage('capture.invalid_image', '无法读取图片，请使用单张清晰的支付截图。'),
  ocrFailed('capture.ocr_failed', '截图识别失败，请重试或手动记账。');

  const RecognitionErrorCode(this.code, this.defaultMessage);

  @override
  final String code;

  @override
  final String defaultMessage;
}
