package com.seaky.smplayer_flutter

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

// SharedPreferences caches are process-local. The host configuration is instead
// an atomic encrypted file; the active sharing host is its only writer.
object MusicSharingConfiguration {
    private const val KEY = "smplayer_background_sharing_configuration"

    private fun configuration(context: Context) =
        AtomicFile(File(context.noBackupFilesDir, "music-sharing-host.enc"))

    private fun startup(context: Context) =
        AtomicFile(File(context.noBackupFilesDir, "music-sharing-startup"))

    fun startupEnabled(context: Context): Boolean = withLock(context, "startup") {
        val file = startup(context)
        file.baseFile.exists() && file.openRead().use { it.read() == 1 }
    }

    fun setStartupEnabled(context: Context, enabled: Boolean) = withLock(context, "startup") {
        write(startup(context), byteArrayOf(if (enabled) 1 else 0))
    }

    @Synchronized
    private fun <T> withLock(context: Context, name: String, action: () -> T): T {
        // AtomicFile supplies crash-safe replacement, not reader/writer exclusion.
        // Serialize native callbacks here and coordinate the two OS processes.
        RandomAccessFile(File(context.noBackupFilesDir, "music-sharing-$name.lock"), "rw").use { file ->
            file.channel.use { channel ->
                channel.lock().use { return action() }
            }
        }
    }

    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "smplayer_flutter/sharing_configuration")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "read" -> withLock(context, "configuration") {
                            val file = configuration(context)
                            if (!file.baseFile.exists()) result.success(null)
                            else {
                                val bytes = file.openRead().use { it.readBytes() }
                                val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                                val key = (store.getEntry(KEY, null) as KeyStore.SecretKeyEntry).secretKey
                                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                                cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
                                result.success(String(cipher.doFinal(bytes, 12, bytes.size - 12), Charsets.UTF_8))
                            }
                        }
                        "write" -> withLock(context, "configuration") {
                            val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                            val key: SecretKey = if (store.containsAlias(KEY)) {
                                (store.getEntry(KEY, null) as KeyStore.SecretKeyEntry).secretKey
                            } else {
                                KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
                                    init(KeyGenParameterSpec.Builder(KEY,
                                        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                                        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                                        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
                                }.generateKey()
                            }
                            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                            cipher.init(Cipher.ENCRYPT_MODE, key)
                            write(configuration(context), cipher.iv + cipher.doFinal((call.arguments as String).toByteArray(Charsets.UTF_8)))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("sharing_configuration_failed", error.localizedMessage, null)
                }
            }
    }

    private fun write(file: AtomicFile, bytes: ByteArray) {
        val stream = file.startWrite()
        try {
            stream.write(bytes)
            file.finishWrite(stream)
        } catch (error: Exception) {
            file.failWrite(stream)
            throw error
        }
    }
}
