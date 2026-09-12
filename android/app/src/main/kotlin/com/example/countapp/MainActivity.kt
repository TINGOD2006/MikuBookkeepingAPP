package com.example.countapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.countapp/notification"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        NotificationListenerService.setMethodChannel(methodChannel)

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "onPaymentNotification" -> {
                    result.success(true)
                }
                "setForegroundNotification" -> {
                    val enabled = call.arguments as? Boolean ?: false
                    result.success(
                        NotificationListenerService.setForegroundNotification(enabled)
                    )
                }
                "isNotificationAccessEnabled" -> {
                    result.success(
                        NotificationListenerService.isNotificationAccessGranted(this)
                    )
                }
                "openNotificationAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * ✅ Flutter engine 被銷毀時清空方法通道參照。
     *
     * 通知監聽服務與前台服務會讓行程繼續存活，因此 App 被滑掉後
     * NotificationListenerService.methodChannel 仍會指向已銷毀的 engine，
     * 送出的記錄不但到不了 Dart，還會被誤判為「已處理」而永久消失。
     */
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        NotificationListenerService.setMethodChannel(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}