import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../../../application/intake/recognition/command/port/payment_screenshot_image_picker.dart';
import '../../../application/intake/recognition/command/port/shared_payment_image_source.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/intake/recognition/port/payment_screenshot_ocr.dart';
import '../../../domain/intake/recognition/recognition_error_code.dart';
import '../../../domain/intake/recognition/recognized_payment.dart';

final _logger = Logger('infra.intake.recognition');

class PlatformPaymentScreenshot
    implements
        SharedPaymentImageSource,
        PaymentScreenshotOcr,
        PaymentScreenshotImagePicker {
  PlatformPaymentScreenshot({
    MethodChannel channel = const MethodChannel(
      'com.shxzz.smartflow/capture_intake',
    ),
  }) : _channel = channel {
    if (_supported) _channel.setMethodCallHandler(_handleShare);
  }

  final MethodChannel _channel;
  final _shares = StreamController<SharedPaymentImage>.broadcast();

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Stream<SharedPaymentImage> get shares => _shares.stream;

  @override
  Future<String?> pickImage() async {
    if (!_supported) {
      throw InfrastructureException(RecognitionErrorCode.unsupportedPlatform);
    }
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return null;
      final length = file.lengthSync() ?? await file.length();
      if (length != null && length > 20 * 1024 * 1024) {
        throw InfrastructureException(RecognitionErrorCode.invalidImage);
      }
      final buffer = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (buffer.length + chunk.length > 20 * 1024 * 1024) {
          throw InfrastructureException(RecognitionErrorCode.invalidImage);
        }
        buffer.add(chunk);
      }
      final bytes = buffer.takeBytes();
      if (bytes.isEmpty) {
        throw InfrastructureException(RecognitionErrorCode.invalidImage);
      }
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'prepareImage',
        {'bytes': bytes},
      );
      final id = result?['id'] as String?;
      if (id == null) {
        throw InfrastructureException(RecognitionErrorCode.imageUnavailable);
      }
      return id;
    } on AppException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      throw InfrastructureException(
        RecognitionErrorCode.imagePickFailed,
        cause: _diagnosticCause(error),
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<SharedPaymentImage?> takeInitialShare() async {
    if (!_supported) return null;
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'takeInitialShare',
      );
      return data == null ? null : SharedPaymentImage(id: data['id'] as String);
    } on PlatformException catch (error, stackTrace) {
      throw InfrastructureException(
        RecognitionErrorCode.imageUnavailable,
        cause: _diagnosticCause(error),
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _handleShare(MethodCall call) async {
    if (call.method != 'sharedImage' || _shares.isClosed) return;
    final data = call.arguments as Map;
    _shares.add(SharedPaymentImage(id: data['id'] as String));
  }

  @override
  Future<List<RecognizedTextBlock>> recognize(String shareId) async {
    _logger.info('Screenshot OCR started. imageId=$shareId');
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'recognizeShare',
        {'id': shareId},
      );
      _logger.info(
        () =>
            'Screenshot OCR output: ${_encodeOcrDiagnostic({
              'imageId': shareId,
              'result': result == null ? null : {'blocks': result['blocks'], 'loadTimeMs': result['loadTimeMs'], 'totalTimeMs': result['totalTimeMs']},
            })}',
      );
      final blocks = result?['blocks'] as List<dynamic>? ?? const [];
      return [
        for (final raw in blocks)
          RecognizedTextBlock(
            text: (raw as Map)['text'] as String,
            confidence: (raw['confidence'] as num).toDouble(),
            left: (raw['left'] as num).toDouble(),
            top: (raw['top'] as num).toDouble(),
            right: (raw['right'] as num).toDouble(),
            bottom: (raw['bottom'] as num).toDouble(),
          ),
      ];
    } on PlatformException catch (error, stackTrace) {
      final code = switch (error.code) {
        'capture.invalid_image' => RecognitionErrorCode.invalidImage,
        'capture.image_unavailable' => RecognitionErrorCode.imageUnavailable,
        _ => RecognitionErrorCode.ocrFailed,
      };
      throw InfrastructureException(
        code,
        cause: _diagnosticCause(error),
        stackTrace: stackTrace,
      );
    }
  }

  void dispose() {
    if (_supported) _channel.setMethodCallHandler(null);
    unawaited(_shares.close());
  }
}

String _encodeOcrDiagnostic(Object? value) {
  try {
    return jsonEncode(value);
  } on JsonUnsupportedObjectError {
    // Unexpected native values must not turn diagnostic logging into an OCR failure.
    return value.toString();
  }
}

// Platform messages, details and native stacks may contain image paths or OCR text.
// Keep the stable platform code or exception type alongside the original Dart stack.
Object _diagnosticCause(Exception error) => error is PlatformException
    ? PlatformException(code: error.code)
    : error.runtimeType;
