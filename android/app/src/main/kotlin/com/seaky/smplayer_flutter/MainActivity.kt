package com.seaky.smplayer_flutter

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var desktopFeatureChannel: MethodChannel? = null
    private val pendingInitialExternalArguments = mutableListOf<String>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        desktopFeatureChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "smplayer_flutter/desktop_features",
        )
        desktopFeatureChannel?.setMethodCallHandler { call, result ->
            if (call.method == "takeInitialExternalArguments") {
                result.success(pendingInitialExternalArguments.toList())
                pendingInitialExternalArguments.clear()
                return@setMethodCallHandler
            }
            result.notImplemented()
        }
        pendingInitialExternalArguments.addAll(externalArgumentsFromIntent(intent))
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        dispatchExternalIntent(intent)
    }

    private fun dispatchExternalIntent(intent: Intent?) {
        val arguments = externalArgumentsFromIntent(intent)
        if (arguments.isEmpty()) {
            return
        }
        desktopFeatureChannel?.invokeMethod("openExternalArguments", arguments)
    }

    private fun externalArgumentsFromIntent(intent: Intent?): List<String> {
        val sourceIntent = intent ?: return emptyList()
        return when (sourceIntent.action) {
            Intent.ACTION_VIEW -> {
                sourceIntent.data?.let(::argumentFromUri)?.let(::listOf) ?: emptyList()
            }

            Intent.ACTION_SEND -> {
                sourceIntent.parcelableUriExtra(Intent.EXTRA_STREAM)
                    ?.let(::argumentFromUri)
                    ?.let(::listOf) ?: emptyList()
            }

            Intent.ACTION_SEND_MULTIPLE -> {
                sourceIntent.parcelableUriArrayListExtra(Intent.EXTRA_STREAM)
                    .map(::argumentFromUri)
            }

            else -> emptyList()
        }
    }

    private fun argumentFromUri(uri: Uri): String {
        if (uri.scheme == "smplayer") {
            return uri.toString()
        }
        if (uri.scheme == "file") {
            return uri.path.orEmpty()
        }
        return copyContentUriToCache(uri).path
    }

    private fun copyContentUriToCache(uri: Uri): File {
        val name = audioFileName(uri)
        val target = File(cacheDir, "external-open/$name")
        target.parentFile?.mkdirs()
        contentResolver.openInputStream(uri).use { input ->
            target.outputStream().use { output ->
                requireNotNull(input).copyTo(output)
            }
        }
        return target
    }

    private fun audioFileName(uri: Uri): String {
        val displayName = contentDisplayName(uri)
        if (displayName != null && audioExtension(displayName).isNotEmpty()) {
            return displayName
        }
        val extension = audioExtension(uri.lastPathSegment.orEmpty()).ifEmpty { ".mp3" }
        return "external-${System.currentTimeMillis()}$extension"
    }

    private fun contentDisplayName(uri: Uri): String? {
        val cursor: Cursor? = contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )
        cursor.use {
            if (it != null && it.moveToFirst()) {
                return it.getString(0)
            }
        }
        return null
    }

    private fun audioExtension(value: String): String {
        val extension = value.substringAfterLast('.', missingDelimiterValue = "")
            .lowercase()
        return when (extension) {
            "aac", "aiff", "alac", "ape", "flac", "m4a", "mp3", "ogg", "opus",
            "wav", "wma" -> ".$extension"
            else -> ""
        }
    }

    private fun Intent.parcelableUriExtra(name: String): Uri? {
        return getParcelableExtra(name)
    }

    private fun Intent.parcelableUriArrayListExtra(name: String): List<Uri> {
        return getParcelableArrayListExtra<Uri>(name)?.toList() ?: emptyList()
    }
}
