# PaddleOCR Android SDK

SDK source: [PaddlePaddle/PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR/tree/dab3fe35379033fdcb2d0e9572fac0b36c9a9ebf/deploy/ppocr-android/ppocr-sdk), revision `dab3fe35379033fdcb2d0e9572fac0b36c9a9ebf`.

The Apache-2.0 licensed SDK source is vendored unchanged. Its Gradle configuration uses SmartFlow's Android plugin and Java toolchain, and the official `org.opencv:opencv:4.13.0` Android artifact. The upstream QuickBird OpenCV 4.5.3 artifact failed to load on the x86_64 Android validation device with a missing `__lttf2` symbol. Upstream demo UI and test fixtures are excluded.

The application bundles **PP-OCRv6_tiny** ONNX detection and recognition models with the matching recognition dictionary. OCR runs offline with ONNX Runtime; no model download is required at runtime. One image is recognized at a time and sessions are released after completion. The Android minimum version is API 26.

Model sources:

- [Detection bundle](https://paddle-model-ecology.bj.bcebos.com/paddlex/official_inference_model/paddle3.0.0/PP-OCRv6_tiny_det_onnx_infer.tar)
- [Recognition bundle](https://paddle-model-ecology.bj.bcebos.com/paddlex/official_inference_model/paddle3.0.0/PP-OCRv6_tiny_rec_onnx_infer.tar)

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `models/det/inference.onnx` | 1,780,590 | `193bab7a04fca699a6c82e6abb5b81bdb28177f0abd4062552b04908dafb19f8` |
| `models/rec/inference.onnx` | 4,462,639 | `9ef676d6ed3c88256a2d92c640c44f25b0c40947e111b14b8be8f594091563e6` |
| `models/rec/inference.yml` | 55,571 | `66170210bad538e83fff3c4a3867e547d6bf20b50d64b20347c4b913f3034ea1` |

The two private payment screenshots in ignored `demo/capture/` were checked manually against tiny and small using the same image preprocessing and four CPU threads. Both models produced correct amount, direction, payment time, merchant, and payment method on these samples. Tiny was selected for its smaller weight files and shorter latency. Two samples do not establish general recognition accuracy; Android runtime validation and automated behavior tests are separate checks. Tests use synthetic text and geometry and never load these screenshots.

Validation on the local Windows CPU with ONNX Runtime 1.21.1 (not a phone benchmark): tiny took approximately 0.35–0.45 seconds per screenshot, small 0.92–1.49 seconds. The detection and recognition ONNX weights plus recognition configuration total 6,298,800 bytes for tiny and 31,190,469 bytes for small. These weight sizes exclude the shared inference and OpenCV libraries, which are significant contributors to APK size. Android 15 x86_64 validation confirmed the native SDK's cold-start WeChat share and running-app Alipay share both reach the existing transaction form with the actual amount and payment details.
