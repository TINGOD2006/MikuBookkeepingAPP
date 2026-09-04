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
                "openNotificationAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}