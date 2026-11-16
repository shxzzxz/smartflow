package com.shxzz.smartflow

import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.core.content.IntentCompat
import com.paddle.ocr.EngineConfig
import com.paddle.ocr.PaddleOCR
import com.paddle.ocr.PaddleOCRConfig
import com.paddle.ocr.util.OpenCVUtils
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

/** One image input at a time; shares use URI grants and selected images stay in memory. */
class CaptureIntakeChannel(context: Context, messenger: BinaryMessenger) {
    private val context = context.applicationContext
    private val channel = MethodChannel(messenger, "com.shxzz.smartflow/capture_intake")
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var listening = false
    private var pending: Map<String, String>? = null
    private var imageUri: Uri? = null
    private var imageBytes: ByteArray? = null
    private var imageId: String? = null
    private var recognizing = false

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareImage" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null || bytes.isEmpty() || bytes.size > MAX_IMAGE_BYTES) {
                        result.error("capture.invalid_image", "无法读取所选截图，请重新选择。", null)
                    } else if (recognizing) {
                        result.error("capture.busy", "正在识别截图，请稍候。", null)
                    } else {
                        val id = UUID.randomUUID().toString()
                        imageId = id
                        imageUri = null
                        imageBytes = bytes
                        result.success(mapOf("id" to id))
                    }
                }
                "takeInitialShare" -> {
                    listening = true
                    result.success(pending)
                    pending = null
                }
                "recognizeShare" -> {
                    val id = call.argument<String>("id")
                    val uri = imageUri
                    val selectedBytes = imageBytes
                    if (id == null || id != imageId || (uri == null && selectedBytes == null)) {
                        result.error("capture.image_unavailable", "分享图片已不可用，请重新分享。", null)
                    } else if (recognizing) {
                        result.error("capture.busy", "正在识别截图，请稍候。", null)
                    } else {
                        recognizing = true
                        scope.launch {
                            try {
                                result.success(recognize(uri, selectedBytes))
                            } catch (error: CancellationException) {
                                throw error
                            } catch (error: InvalidSharedImage) {
                                result.error("capture.invalid_image", "无法读取图片，请分享单张清晰的支付截图。", null)
                            } catch (error: Exception) {
                                // OCR exceptions can contain image paths or recognized text.
                                android.util.Log.e(
                                    "SmartFlowCapture",
                                    "OCR failed: ${error.javaClass.simpleName}; cause=${error.cause?.javaClass?.simpleName}",
                                )
                                result.error("capture.ocr_failed", "截图识别失败，请重试或手动记账。", null)
                            } finally {
                                recognizing = false
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun handleIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND || intent.type?.startsWith("image/") != true) return
        val uri = IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
            ?: intent.clipData?.takeIf { it.itemCount == 1 }?.getItemAt(0)?.uri
        val id = UUID.randomUUID().toString()
        imageId = id
        imageBytes = null
        imageUri = uri?.takeIf { it.scheme == "content" }
        val share = mapOf("id" to id)
        if (listening) {
            channel.invokeMethod("sharedImage", share)
        } else {
            pending = share
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        scope.cancel()
        imageUri = null
        imageBytes = null
        pending = null
    }

    private suspend fun recognize(uri: Uri?, selectedBytes: ByteArray?): Map<String, Any> = withContext(Dispatchers.IO) {
        val bytes = selectedBytes ?: try {
            if (uri == null) throw InvalidSharedImage()
            context.contentResolver.openInputStream(uri)?.use { stream ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val count = stream.read(buffer)
                    if (count < 0) break
                    if (output.size() + count > MAX_IMAGE_BYTES) throw InvalidSharedImage()
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            } ?: throw InvalidSharedImage()
        } catch (error: Exception) {
            throw InvalidSharedImage()
        }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0 ||
            bounds.outWidth.toLong() * bounds.outHeight > MAX_IMAGE_PIXELS) {
            throw InvalidSharedImage()
        }
        check(OpenCVUtils.init(context)) { "OCR runtime unavailable" }
        val ocr = PaddleOCR.create(
            context,
            PaddleOCRConfig(detLimitSideLen = 1280, detLimitType = "max", detMaxSideLimit = 1280),
            EngineConfig(numThreads = 4),
        )
        try {
            val run = ocr.recognize(bytes)
            mapOf(
                "blocks" to run.results.map { item ->
                    mapOf(
                        "text" to item.text,
                        "confidence" to item.confidence.toDouble(),
                        "left" to item.box.points.minOf { it.x }.toDouble(),
                        "top" to item.box.points.minOf { it.y }.toDouble(),
                        "right" to item.box.points.maxOf { it.x }.toDouble(),
                        "bottom" to item.box.points.maxOf { it.y }.toDouble(),
                    )
                },
                "loadTimeMs" to run.coldLoadTimeMs,
                "totalTimeMs" to run.totalTimeMs,
            )
        } finally {
            // Release models after recognition instead of retaining idle native memory.
            withContext(kotlinx.coroutines.NonCancellable) { ocr.release() }
        }
    }

    private class InvalidSharedImage : Exception()

    companion object {
        private const val MAX_IMAGE_BYTES = 20 * 1024 * 1024
        private const val MAX_IMAGE_PIXELS = 24_000_000L
    }
}
