package com.meet6.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val standardChannel = NotificationChannel(
                "meet6_high_v2",
                "Meet6 bildirimleri",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Oda, eşleşme, mesaj ve hesap bildirimleri"
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

            manager.createNotificationChannel(standardChannel)
            manager.createNotificationChannel(noVibrationChannel)
        }
    }
}
