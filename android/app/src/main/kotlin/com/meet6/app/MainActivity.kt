package com.meet6.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val SYSTEM_NOTIFICATION_CHANNEL = "meet6/system_notifications"
        private const val FILE_EXPORT_CHANNEL = "meet6/file_export"
        private const val EXTRA_NOTIFICATION_PAYLOAD = "meet6_notification_payload"
        private const val MESSAGE_CHANNEL = "meet6_messages_v1"
        private const val MESSAGE_CHANNEL_NO_VIBRATION = "meet6_messages_no_vibration_v1"
    }

    private lateinit var systemNotificationChannel: MethodChannel
    private var pendingNotificationTapPayload: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingNotificationTapPayload = intent?.getStringExtra(EXTRA_NOTIFICATION_PAYLOAD)
        createNotificationChannels()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        systemNotificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYSTEM_NOTIFICATION_CHANNEL,
        )
        systemNotificationChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    val args = call.arguments as? Map<*, *>
                    val id = (args?.get("id") as? Number)?.toInt()
                        ?: (System.currentTimeMillis() and 0x7fffffff).toInt()
                    val title = args?.get("title")?.toString()?.trim().orEmpty()
                    val body = args?.get("body")?.toString()?.trim().orEmpty()
                    val payload = args?.get("payload")?.toString().orEmpty()
                    val vibrationEnabled = args?.get("vibrationEnabled") != false
                    showSystemNotification(
                        id = id,
                        title = if (title.isEmpty()) "Meet6" else title,
                        body = body,
                        payload = payload,
                        vibrationEnabled = vibrationEnabled,
                    )
                    result.success(null)
                }

                "consumeInitialTap" -> {
                    val payload = pendingNotificationTapPayload
                        ?: intent?.getStringExtra(EXTRA_NOTIFICATION_PAYLOAD)
                    pendingNotificationTapPayload = null
                    intent?.removeExtra(EXTRA_NOTIFICATION_PAYLOAD)
                    result.success(payload)
                }

                "openSettings" -> {
                    try {
                        val settingsIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            }
                        } else {
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName"),
                            )
                        }
                        startActivity(settingsIntent)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error(
                            "settings_open_failed",
                            error.message ?: "Bildirim ayarları açılamadı.",
                            null,
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FILE_EXPORT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveJson" -> {
                    val args = call.arguments as? Map<*, *>
                    val fileName = args?.get("fileName")?.toString()?.trim().orEmpty()
                    val content = args?.get("content")?.toString().orEmpty()
                    try {
                        val saved = saveJsonExport(
                            if (fileName.isBlank()) "meet6-verilerim.json" else fileName,
                            content,
                        )
                        result.success(saved)
                    } catch (error: Exception) {
                        result.error(
                            "save_failed",
                            error.message ?: "Dosya kaydedilemedi.",
                            null,
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = intent.getStringExtra(EXTRA_NOTIFICATION_PAYLOAD) ?: return
        intent.removeExtra(EXTRA_NOTIFICATION_PAYLOAD)
        if (::systemNotificationChannel.isInitialized) {
            systemNotificationChannel.invokeMethod("notificationTap", payload)
        } else {
            pendingNotificationTapPayload = payload
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val standardChannel = NotificationChannel(
            "meet6_high_v2",
            "Meet6 bildirimleri",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Oda, eşleşme ve hesap bildirimleri"
            enableVibration(true)
            enableLights(true)
            lightColor = Color.rgb(216, 255, 50)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(true)
        }

        val noVibrationChannel = NotificationChannel(
            "meet6_high_no_vibration_v1",
            "Meet6 bildirimleri · titreşimsiz",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Titreşim kapalıyken Meet6 bildirimleri"
            enableVibration(false)
            vibrationPattern = null
            enableLights(true)
            lightColor = Color.rgb(216, 255, 50)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(true)
        }

        val messageChannel = NotificationChannel(
            MESSAGE_CHANNEL,
            "Meet6 mesajları",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Özel sohbet ve oda mesajları"
            enableVibration(true)
            enableLights(true)
            lightColor = Color.rgb(216, 255, 50)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
        }

        val messageNoVibrationChannel = NotificationChannel(
            MESSAGE_CHANNEL_NO_VIBRATION,
            "Meet6 mesajları · titreşimsiz",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Titreşim kapalıyken özel sohbet ve oda mesajları"
            enableVibration(false)
            vibrationPattern = null
            enableLights(true)
            lightColor = Color.rgb(216, 255, 50)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
        }

        manager.createNotificationChannels(
            listOf(
                standardChannel,
                noVibrationChannel,
                messageChannel,
                messageNoVibrationChannel,
            ),
        )
    }

    private fun showSystemNotification(
        id: Int,
        title: String,
        body: String,
        payload: String,
        vibrationEnabled: Boolean,
    ) {
        val channelId = if (vibrationEnabled) MESSAGE_CHANNEL else MESSAGE_CHANNEL_NO_VIBRATION
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_NOTIFICATION_PAYLOAD, payload)
        }
        val pendingIntentFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val contentIntent = PendingIntent.getActivity(this, id, launchIntent, pendingIntentFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            Notification.Builder(this)
                .setPriority(Notification.PRIORITY_HIGH)
                .setDefaults(
                    Notification.DEFAULT_SOUND or
                        if (vibrationEnabled) Notification.DEFAULT_VIBRATE else 0,
                )
        }

        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_meet6)
            .setColor(Color.rgb(216, 255, 50))
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(id, notification)
    }

    private fun saveJsonExport(fileName: String, content: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/json")
                put(
                    MediaStore.Downloads.RELATIVE_PATH,
                    "${Environment.DIRECTORY_DOWNLOADS}/Meet6",
                )
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("İndirme dosyası oluşturulamadı.")
            try {
                resolver.openOutputStream(uri)?.use {
                    it.write(content.toByteArray(Charsets.UTF_8))
                } ?: throw IllegalStateException("Dosya açılamadı.")
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                return "Downloads/Meet6/$fileName"
            } catch (error: Exception) {
                resolver.delete(uri, null, null)
                throw error
            }
        }

        val base = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
        val directory = File(base, "Meet6").apply { mkdirs() }
        val file = File(directory, fileName)
        file.writeText(content, Charsets.UTF_8)
        return file.absolutePath
    }
}
