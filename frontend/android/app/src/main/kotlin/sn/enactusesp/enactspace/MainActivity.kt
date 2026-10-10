package sn.enactusesp.enactspace

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "sn.enactusesp.enactspace/receipt_share"
    private val chatVoiceChannelName = "sn.enactusesp.enactspace/chat_voice"
    private val voicePermissionRequestCode = 7314
    private var channel: MethodChannel? = null
    private var pendingReceipt: Map<String, Any>? = null
    private var pendingVoicePermissionResult: MethodChannel.Result? = null
    private var voiceRecorder: MediaRecorder? = null
    private var voiceFile: File? = null
    private var voiceStartedAt: Long = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notification = NotificationChannel(
                "enactspace_notifications",
                "Notifications EnactSpace",
                NotificationManager.IMPORTANCE_DEFAULT,
            )
            getSystemService(NotificationManager::class.java).createNotificationChannel(notification)
        }
        receiveShare(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPendingReceipt" -> result.success(pendingReceipt != null)
                "getPendingReceipt" -> {
                    val receipt = pendingReceipt
                    if (receipt == null) {
                        result.success(null)
                    } else {
                        // Consume this exact receipt before OCR so a newer share cannot be erased
                        // when the asynchronous recognition completes.
                        pendingReceipt = null
                        val bytes = receipt["bytes"] as? ByteArray
                        val name = receipt["name"] as? String ?: "recu_partage.jpg"
                        if (bytes == null) {
                            result.success(receipt + ("text" to ""))
                        } else {
                            recognizeText(bytes, name) { text ->
                                result.success(receipt + ("text" to text))
                            }
                        }
                    }
                }
                "recognizeReceipt" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val name = call.argument<String>("name") ?: "recu_importe.jpg"
                    if (bytes == null || bytes.isEmpty()) {
                        result.success("")
                    } else if (bytes.size > 12 * 1024 * 1024) {
                        result.error("receipt_too_large", "Le justificatif dépasse 12 Mo.", null)
                    } else {
                        recognizeText(bytes, name) { text -> result.success(text) }
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            chatVoiceChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVoiceRecording" -> startVoiceRecording(result)
                "stopVoiceRecording" -> stopVoiceRecording(result, send = true)
                "cancelVoiceRecording" -> stopVoiceRecording(result, send = false)
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(newIntent: Intent) {
        super.onNewIntent(newIntent)
        setIntent(newIntent)
        receiveShare(newIntent)
    }

    private fun startVoiceRecording(result: MethodChannel.Result) {
        if (voiceRecorder != null) {
            result.error("voice_busy", "Un enregistrement vocal est déjà en cours.", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingVoicePermissionResult?.error(
                "microphone_permission",
                "Une demande d'accès au microphone est déjà en cours.",
                null,
            )
            pendingVoicePermissionResult = result
            requestPermissions(
                arrayOf(Manifest.permission.RECORD_AUDIO),
                voicePermissionRequestCode,
            )
            return
        }
        beginVoiceRecording(result)
    }

    @Suppress("DEPRECATION")
    private fun beginVoiceRecording(result: MethodChannel.Result) {
        val file = File(cacheDir, "voice_${System.nanoTime()}.m4a")
        val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            MediaRecorder()
        }
        try {
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            recorder.setAudioEncodingBitRate(128000)
            recorder.setAudioSamplingRate(44100)
            recorder.setOutputFile(file.absolutePath)
            recorder.prepare()
            recorder.start()
            voiceRecorder = recorder
            voiceFile = file
            voiceStartedAt = System.currentTimeMillis()
            result.success(true)
        } catch (error: Exception) {
            try {
                recorder.release()
            } catch (_: Exception) {
                // Recorder was not fully initialized.
            }
            file.delete()
            result.error(
                "voice_start_failed",
                error.message ?: "Impossible de démarrer l'enregistrement vocal.",
                null,
            )
        }
    }

    private fun stopVoiceRecording(result: MethodChannel.Result, send: Boolean) {
        val recorder = voiceRecorder
        val file = voiceFile
        if (recorder == null || file == null) {
            result.success(if (send) null else true)
            return
        }

        val durationSeconds = ((System.currentTimeMillis() - voiceStartedAt) / 1000L)
            .coerceAtLeast(1L)
            .coerceAtMost(3600L)
            .toInt()
        var stopFailed = false
        try {
            recorder.stop()
        } catch (_: RuntimeException) {
            stopFailed = true
        } finally {
            try {
                recorder.release()
            } catch (_: Exception) {
                // Best effort cleanup.
            }
            voiceRecorder = null
            voiceFile = null
            voiceStartedAt = 0L
        }

        if (!send) {
            file.delete()
            result.success(true)
            return
        }
        if (stopFailed || !file.exists() || file.length() == 0L) {
            file.delete()
            result.error("voice_empty", "Le vocal est trop court ou vide.", null)
            return
        }

        try {
            val bytes = file.readBytes()
            file.delete()
            result.success(
                mapOf(
                    "bytes" to bytes,
                    "name" to "vocal_enactspace.m4a",
                    "mime_type" to "audio/mp4",
                    "duration_seconds" to durationSeconds,
                ),
            )
        } catch (error: Exception) {
            file.delete()
            result.error(
                "voice_read_failed",
                error.message ?: "Impossible de lire le vocal enregistré.",
                null,
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != voicePermissionRequestCode) return
        val result = pendingVoicePermissionResult ?: return
        pendingVoicePermissionResult = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            beginVoiceRecording(result)
        } else {
            result.error(
                "microphone_permission",
                "Autorise le microphone pour enregistrer un vocal.",
                null,
            )
        }
    }

    override fun onDestroy() {
        val recorder = voiceRecorder
        if (recorder != null) {
            try {
                recorder.stop()
            } catch (_: Exception) {
                // Ignore shutdown errors.
            }
            try {
                recorder.release()
            } catch (_: Exception) {
                // Ignore shutdown errors.
            }
        }
        voiceRecorder = null
        voiceFile?.delete()
        voiceFile = null
        pendingVoicePermissionResult = null
        super.onDestroy()
    }

    private fun recognizeText(bytes: ByteArray, name: String, onDone: (String) -> Unit) {
        val extension = name.substringAfterLast('.', "jpg")
            .lowercase()
            .takeIf { it in setOf("jpg", "jpeg", "png", "webp") }
            ?: "jpg"
        val file = File(cacheDir, "receipt_${System.nanoTime()}.$extension")
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        try {
            file.writeBytes(bytes)
            recognizer.process(InputImage.fromFilePath(this, Uri.fromFile(file)))
                .addOnSuccessListener { recognized ->
                    onDone(recognized.text.take(8000))
                    recognizer.close()
                    file.delete()
                }
                .addOnFailureListener {
                    onDone("")
                    recognizer.close()
                    file.delete()
                }
        } catch (_: Exception) {
            onDone("")
            recognizer.close()
            file.delete()
        }
    }

    private fun receiveShare(shared: Intent?) {
        if (shared?.action != Intent.ACTION_SEND ||
            shared.type?.startsWith("image/") != true
        ) {
            return
        }
        @Suppress("DEPRECATION")
        val uri = shared.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: return
        try {
            // Copy immediately while the temporary URI permission granted by Android is valid.
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return
            if (bytes.isEmpty() || bytes.size > 12 * 1024 * 1024) return
            val extension = when (shared.type) {
                "image/png" -> "png"
                "image/webp" -> "webp"
                else -> "jpg"
            }
            pendingReceipt = mapOf(
                "bytes" to bytes,
                "name" to "recu_partage.$extension",
            )
            channel?.invokeMethod("receiptShared", null)
        } catch (_: Exception) {
            // A revoked or invalid content URI must not interrupt app startup.
        }
    }
}
