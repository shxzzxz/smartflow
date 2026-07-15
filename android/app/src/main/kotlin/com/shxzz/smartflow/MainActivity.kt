package com.shxzz.smartflow

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val updateChannel = "com.shxzz.smartflow/app_update"
    private val updatePreferences by lazy {
        getSharedPreferences("app_update", Context.MODE_PRIVATE)
    }
    private val downloadManager by lazy {
        getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    }

    override fun onResume() {
        super.onResume()
        resumePendingInstallIfAllowed()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getVersionInfo" -> result.success(getVersionInfo())
                    "getSupportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
                    "startApkDownload" -> {
                        val url = call.argument<String>("url")
                        val fileName = call.argument<String>("fileName")
                        if (url.isNullOrBlank() || fileName.isNullOrBlank()) {
                            result.error(
                                "invalidDownload",
                                "APK URL and file name are required.",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        runCatching { startApkDownload(url, fileName) }
                            .onSuccess(result::success)
                            .onFailure {
                                result.error("downloadFailed", it.message, null)
                            }
                    }
                    "getApkDownloadStatus" -> {
                        val downloadId = call.argument<Number>("downloadId")?.toLong()
                        if (downloadId == null) {
                            result.error("invalidDownload", "Download ID is required.", null)
                            return@setMethodCallHandler
                        }
                        result.success(getApkDownloadStatus(downloadId))
                    }
                    "removeApkDownload" -> {
                        val downloadId = call.argument<Number>("downloadId")?.toLong()
                        if (downloadId == null) {
                            result.error("invalidDownload", "Download ID is required.", null)
                            return@setMethodCallHandler
                        }
                        removeApkDownload(downloadId)
                        result.success(null)
                    }
                    "installApk" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath.isNullOrBlank()) {
                            result.error("invalidPath", "APK file path is required.", null)
                            return@setMethodCallHandler
                        }
                        installApk(filePath, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getVersionInfo(): Map<String, Any> {
        val packageInfo =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }

        val buildNumber =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                packageInfo.versionCode.toLong()
            }

        return mapOf(
            "versionName" to (packageInfo.versionName ?: ""),
            "buildNumber" to buildNumber,
        )
    }

    private fun startApkDownload(
        url: String,
        fileName: String,
    ): Long {
        val downloadUri = Uri.parse(url)
        require(downloadUri.scheme == "https" || downloadUri.scheme == "http") {
            "APK URL must use HTTP or HTTPS."
        }

        val safeFileName = File(fileName).name
        require(safeFileName == fileName && safeFileName.endsWith(".apk")) {
            "Invalid APK file name."
        }

        val existingId = updatePreferences.getLong(downloadIdKey, -1L)
        val existingUrl = updatePreferences.getString(downloadUrlKey, null)
        if (existingId >= 0 && existingUrl == url) {
            val existingStatus = getApkDownloadStatus(existingId)["status"]
            if (
                existingStatus == downloadPending ||
                    existingStatus == downloadRunning ||
                    existingStatus == downloadPaused ||
                    existingStatus == downloadSuccessful
            ) {
                return existingId
            }
        }

        clearTrackedDownload(removeManagerEntry = true)

        val baseDirectory =
            requireNotNull(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)) {
                "External downloads directory is unavailable."
            }
        val updateDirectory = File(baseDirectory, "updates").apply { mkdirs() }
        require(updateDirectory.isDirectory) { "Unable to create update directory." }

        val apkFile = File(updateDirectory, safeFileName)
        if (apkFile.exists()) {
            require(apkFile.delete()) { "Unable to replace existing APK." }
        }

        val request =
            DownloadManager.Request(downloadUri)
                .setTitle("SmartFlow 软件更新")
                .setDescription("正在下载安装包")
                .setMimeType(apkMimeType)
                .setNotificationVisibility(
                    DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
                )
                .setAllowedOverMetered(true)
                .setAllowedOverRoaming(false)
                .addRequestHeader("User-Agent", "SmartFlow")
                .setDestinationUri(Uri.fromFile(apkFile))

        val downloadId = downloadManager.enqueue(request)
        updatePreferences
            .edit()
            .putLong(downloadIdKey, downloadId)
            .putString(downloadUrlKey, url)
            .putString(downloadPathKey, apkFile.absolutePath)
            .apply()
        return downloadId
    }

    private fun getApkDownloadStatus(downloadId: Long): Map<String, Any> {
        val query = DownloadManager.Query().setFilterById(downloadId)
        downloadManager.query(query).use { cursor ->
            if (!cursor.moveToFirst()) {
                return mapOf(
                    "status" to downloadFailed,
                    "reason" to "missingDownload",
                    "receivedBytes" to 0L,
                    "totalBytes" to -1L,
                )
            }

            val status =
                when (cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))) {
                    DownloadManager.STATUS_PENDING -> downloadPending
                    DownloadManager.STATUS_RUNNING -> downloadRunning
                    DownloadManager.STATUS_PAUSED -> downloadPaused
                    DownloadManager.STATUS_SUCCESSFUL -> downloadSuccessful
                    else -> downloadFailed
                }
            val reason =
                cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
            val receivedBytes =
                cursor.getLong(
                    cursor.getColumnIndexOrThrow(
                        DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR,
                    ),
                )
            val totalBytes =
                cursor.getLong(
                    cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES),
                )
            val trackedPath =
                if (updatePreferences.getLong(downloadIdKey, -1L) == downloadId) {
                    updatePreferences.getString(downloadPathKey, null)
                } else {
                    null
                }

            if (status == downloadSuccessful) {
                if (trackedPath == null || !File(trackedPath).exists()) {
                    return mapOf(
                        "status" to downloadFailed,
                        "reason" to "downloadedFileMissing",
                        "receivedBytes" to receivedBytes,
                        "totalBytes" to totalBytes,
                    )
                }
            }

            return buildMap {
                put("status", status)
                put("reason", reason)
                put("receivedBytes", receivedBytes)
                put("totalBytes", totalBytes)
                if (trackedPath != null) {
                    put("filePath", trackedPath)
                }
            }
        }
    }

    private fun removeApkDownload(downloadId: Long) {
        if (updatePreferences.getLong(downloadIdKey, -1L) == downloadId) {
            clearTrackedDownload(removeManagerEntry = true)
        } else {
            downloadManager.remove(downloadId)
        }
    }

    private fun clearTrackedDownload(removeManagerEntry: Boolean) {
        val downloadId = updatePreferences.getLong(downloadIdKey, -1L)
        val filePath = updatePreferences.getString(downloadPathKey, null)
        if (removeManagerEntry && downloadId >= 0) {
            downloadManager.remove(downloadId)
        }
        if (filePath != null) {
            File(filePath).delete()
        }
        updatePreferences
            .edit()
            .remove(downloadIdKey)
            .remove(downloadUrlKey)
            .remove(downloadPathKey)
            .apply()
    }

    private fun installApk(filePath: String, result: MethodChannel.Result) {
        val apkFile = File(filePath)
        if (!apkFile.exists()) {
            result.error("fileNotFound", "APK file does not exist.", null)
            return
        }

        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                !packageManager.canRequestPackageInstalls()
        ) {
            val intent =
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            updatePreferences
                .edit()
                .putString(pendingInstallPathKey, apkFile.absolutePath)
                .apply()
            runCatching { startActivity(intent) }
                .onSuccess { result.success(null) }
                .onFailure {
                    updatePreferences.edit().remove(pendingInstallPathKey).apply()
                    result.error("installPermissionFailed", it.message, null)
                }
            return
        }

        runCatching { launchPackageInstaller(apkFile) }
            .onSuccess { result.success(null) }
            .onFailure { result.error("installFailed", it.message, null) }
    }

    private fun resumePendingInstallIfAllowed() {
        val filePath = updatePreferences.getString(pendingInstallPathKey, null) ?: return
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                !packageManager.canRequestPackageInstalls()
        ) {
            return
        }

        val apkFile = File(filePath)
        updatePreferences.edit().remove(pendingInstallPathKey).apply()
        if (!apkFile.exists()) {
            return
        }
        runCatching { launchPackageInstaller(apkFile) }
            .onFailure {
                updatePreferences
                    .edit()
                    .putString(pendingInstallPathKey, apkFile.absolutePath)
                    .apply()
            }
    }

    private fun launchPackageInstaller(apkFile: File) {
        val apkUri =
            FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                apkFile,
            )

        val intent =
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(apkUri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        startActivity(intent)
    }

    companion object {
        private const val apkMimeType = "application/vnd.android.package-archive"
        private const val downloadIdKey = "download_id"
        private const val downloadUrlKey = "download_url"
        private const val downloadPathKey = "download_path"
        private const val pendingInstallPathKey = "pending_install_path"
        private const val downloadPending = "pending"
        private const val downloadRunning = "running"
        private const val downloadPaused = "paused"
        private const val downloadSuccessful = "successful"
        private const val downloadFailed = "failed"
    }
}
