package com.example.countapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class NotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "NotificationListener"
        private const val CHANNEL_ID = "miku_foreground_channel"
        private const val NOTIFICATION_ID = 1001
        private var methodChannel: MethodChannel? = null

        fun setMethodChannel(channel: MethodChannel?) {
            methodChannel = channel
        }
    }

    // ============================================================
    // ✅ 服務生命週期
    // ============================================================

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "✅ 通知監聽服務已連接")

        createNotificationChannel()
        startForegroundService()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "⚠️ 通知監聽服務已斷開")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "🛑 通知監聽服務已銷毀")
    }

    // ============================================================
    // ✅ 前台服務（讓 App 掛在後台 + 顯示在通知欄）
    // ============================================================

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Miku 記帳",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "App 正在後台監聽支付通知"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundService() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("📊 Miku 記帳")
            .setContentText("正在監聽支付通知，自動記錄中...")
            .setSmallIcon(android.R.drawable.ic_menu_camera)  // 可換成你的 App 圖標
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)  // ✅ 用戶無法滑掉
            .build()

        startForeground(NOTIFICATION_ID, notification)
        Log.d(TAG, "✅ 前台服務已啟動，顯示在通知欄")
    }

    // ✅ 更新通知欄內容
    private fun updateForegroundNotification(message: String) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("📊 Miku 記帳")
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)
    }

    // ============================================================
    // ✅ 通知處理（核心邏輯）
    // ============================================================

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val notification = sbn.notification
        val extras = notification.extras

        val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
        val text = extras.getString(Notification.EXTRA_TEXT) ?: ""
        val packageName = sbn.packageName

        val fullText = "$title $text"

        // 判斷是否為支付通知
        if (!isPaymentNotification(fullText, packageName)) {
            return
        }

        // 提取金額
        val amount = extractAmount(fullText)
        if (amount == null || amount <= 0) {
            return
        }

        // 提取商家名稱
        val merchant = extractMerchant(fullText)

        Log.d(TAG, "💰 檢測到支付通知: $fullText")
        Log.d(TAG, "  金額: $amount")
        Log.d(TAG, "  商家: $merchant")

        // 檢查自動記錄是否啟用
        if (!isAutoRecordEnabled()) {
            Log.d(TAG, "自動記帳已關閉")
            return
        }

        // ✅ 更新通知欄顯示最新記錄
        val merchantDisplay = merchant ?: "未知商家"
        updateForegroundNotification("✅ 已記錄: $merchantDisplay - \$$amount")

        // ✅ 發送到 Flutter 端處理（AI 分類 + 儲存）
        sendToFlutter(amount, merchant, fullText, packageName)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // 通知被移除時可選處理
    }

    // ============================================================
    // ✅ 支付通知判斷
    // ============================================================

    private fun isPaymentNotification(text: String, packageName: String): Boolean {
        val keywords = listOf(
            "支付", "付款", "轉帳", "交易", "消費", "支出",
            "payment", "transfer", "transaction", "spent",
            "金額", "HK$", "NT$", "¥", "$",
            "支付寶", "微信支付", "Apple Pay", "Google Pay",
            "MPay", "mpay", "Mpay", "澳門通", "Macau Pass"
        )

        val textMatch = keywords.any { text.contains(it, ignoreCase = true) }

        val paymentPackages = listOf(
            "com.alipay.android.app",
            "com.tencent.mm",
            "com.google.android.apps.wallet",
            "com.android.chrome",
            "com.mpay.mobile",
            "com.mpay",
            "mo.mpay.mobile"
        )
        val packageMatch = paymentPackages.any { packageName.contains(it) }

        return textMatch || packageMatch
    }

    // ============================================================
    // ✅ 數據提取
    // ============================================================

    private fun extractAmount(text: String): Double? {
        val patterns = listOf(
            Regex("""[\$¥€£]?(\d{1,3}(?:,\d{3})*\.?\d*)"""),
            Regex("""(\d{1,3}(?:,\d{3})*\.?\d*)\s*(?:元|HKD|NTD|USD|EUR|CNY)"""),
            Regex("""金額[：:]\s*[\$¥€£]?(\d{1,3}(?:,\d{3})*\.?\d*)""")
        )

        for (pattern in patterns) {
            val match = pattern.find(text)
            if (match != null) {
                val amountStr = match.groupValues[1].replace(",", "")
                return amountStr.toDoubleOrNull()
            }
        }
        return null
    }

    private fun extractMerchant(text: String): String? {
        val patterns = listOf(
            Regex("""於\s*([^\s,，。]+)"""),
            Regex("""在\s*([^\s,，。]+)"""),
            Regex("""-\s*([^\s,，。]+)""")
        )
        for (pattern in patterns) {
            val match = pattern.find(text)
            if (match != null) {
                return match.groupValues[1]
            }
        }
        return null
    }

    // ============================================================
    // ✅ SharedPreferences 讀取
    // ============================================================

    private fun isAutoRecordEnabled(): Boolean {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getBoolean("flutter.auto_record_enabled", false)
    }

    // ============================================================
    // ✅ 發送到 Flutter
    // ============================================================

    private fun sendToFlutter(amount: Double, merchant: String?, text: String, packageName: String) {
        try {
            val data = JSONObject().apply {
                put("amount", amount)
                put("merchant", merchant ?: "")
                put("text", text)
                put("packageName", packageName)
                put("timestamp", System.currentTimeMillis())
            }

            methodChannel?.invokeMethod("onPaymentNotification", data.toString())
            Log.d(TAG, "📤 已發送通知到 Flutter: $data")
        } catch (e: Exception) {
            Log.e(TAG, "發送通知到 Flutter 失敗: ${e.message}")
        }
    }
}