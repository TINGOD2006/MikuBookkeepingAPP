package com.example.countapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
                else -> result.notImplemented()
            }
        }
    }
}