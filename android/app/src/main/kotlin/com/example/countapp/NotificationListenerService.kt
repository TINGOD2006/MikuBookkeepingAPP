package com.example.countapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.notification.NotificationListenerService as AndroidNotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.HashMap
import org.json.JSONArray
import java.security.MessageDigest

class NotificationListenerService : AndroidNotificationListenerService() {

    companion object {
        private const val TAG = "NotificationListener"
        private const val CHANNEL_ID = "miku_foreground_channel"
        private const val NOTIFICATION_ID = 1001
        private var methodChannel: MethodChannel? = null
        private var serviceInstance: NotificationListenerService? = null

        // ✅ 去重機制（記憶體 + 持久化）
        private const val DEDUPE_WINDOW_MS = 300_000L  // 5 分鐘
        private val recentEventIds = HashMap<String, Long>()
        private val dedupeLock = Any()

        // ============================================================
        // ✅ Dart 端回報的處理結果（見 lib/services/notification_listener.dart）
        //    只有在「確實已記錄」時才會把通知標記為已處理；
        //    其餘狀況一律回退成原生端自行保存，避免通知被無聲丟棄。
        // ============================================================
        private const val STATUS_SAVED = "saved"
        private const val STATUS_DUPLICATE = "duplicate"
        private const val STATUS_DISABLED = "disabled"

        /**
         * Dart 端判定「不是交易通知」（例如廣告推播）時回報。
         *
         * 與 [STATUS_DISABLED] 的差別：這是針對單一通知的內容判斷，
         * 必須標記為已處理避免重複判斷，且**不可**回退成原生端保存，
         * 否則廣告又會被記進明細。
         */
        private const val STATUS_IGNORED = "ignored"

        /** Flutter 端回應逾時（毫秒）：逾時視為未記錄，改由原生端保存 */
        private const val FLUTTER_REPLY_TIMEOUT_MS = 5_000L

        /** 原生端暫存記錄的鍵前綴（實際鍵為 "flutter." + 此前綴 + eventId） */
        private const val NATIVE_RECORD_KEY_PREFIX = "native_record_"

        // ✅ 通知過濾規則已集中到 PaymentTextAnalyzer，與無障礙探針共用同一套規則：
        //      1. 包名必須在白名單內
        //      2. 出現硬廣告字樣 → 直接丟棄
        //      3. 必須命中「已知交易格式」才記錄（不再用寬鬆關鍵字）

        /**
         * 預設支援的支付應用包名（開箱即用）。
         *
         * ⚠️ 與 Dart 端 NotificationListenerService.defaultAllowedPackages
         *    必須保持同步：
         *    lib/services/notification_listener.dart
         */
        val DEFAULT_ALLOWED_PACKAGES = listOf(
            "com.tencent.mm",                // 微信／微信支付
            "com.eg.android.AlipayGphone",   // 支付寶（中國本體）
            "hk.alipay.wallet",              // AlipayHK
            // 支付寶 SDK／安全支付：部分交易只有這個套件會發通知，一併保留
            "com.alipay.android.app",
            "com.macaupass.rechargeEasy",    // MPay / Macau Pass 澳門通
            "com.google.android.apps.wallet",// Google Pay / Google Wallet
            "com.apple.wallet",              // Apple Wallet
            "com.octopus.nfc",               // 八達通
            "hk.com.boc.bocmobilebanking",   // 中銀香港
            "com.icbc.imobile"               // 工銀亞洲
        )

        fun setMethodChannel(channel: MethodChannel?) {
            methodChannel = channel
        }

        fun setForegroundNotification(enabled: Boolean): Boolean {
            val service = serviceInstance ?: return false
            if (enabled) {
                service.createNotificationChannel()
                service.startForegroundNotification()
            } else {
                service.stopForegroundNotification()
            }
            return true
        }

        /** 檢查本 App 是否已獲得「通知使用權限」（Notification Listener Access） */
        fun isNotificationAccessGranted(context: Context): Boolean {
            return try {
                val flat = Settings.Secure.getString(
                    context.contentResolver,
                    "enabled_notification_listeners"
                ) ?: return false
                val component = ComponentName(
                    context,
                    NotificationListenerService::class.java
                ).flattenToString()
                flat.split(":").any { it.equals(component, ignoreCase = true) }
            } catch (e: Exception) {
                Log.e(TAG, "檢查通知使用權限失敗: ${e.message}")
                false
            }
        }
    }

    // ============================================================
    // ✅ 服務生命週期
    // ============================================================

    override fun onListenerConnected() {
        super.onListenerConnected()
        serviceInstance = this
        Log.d(TAG, "✅ 通知監聽服務已連接")

        if (isBackgroundNotificationEnabled()) {
            createNotificationChannel()
            startForegroundNotification()
        }
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "⚠️ 通知監聽服務已斷開")
    }

    override fun onDestroy() {
        stopForegroundNotification()
        serviceInstance = null
        super.onDestroy()
        Log.d(TAG, "🛑 通知監聽服務已銷毀")
    }

    // ============================================================
    // ✅ 前台服務（讓 App 掛在後台 + 顯示在通知欄）
    // ============================================================

    internal fun createNotificationChannel() {
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

    internal fun startForegroundNotification() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("📊 Miku 記帳")
            .setContentText("正在監聽支付通知，自動記錄中...")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)  // ✅ 用戶無法滑掉
            .build()

        startForeground(NOTIFICATION_ID, notification)
        Log.d(TAG, "✅ 前台服務已啟動，顯示在通知欄")
    }

    @Suppress("DEPRECATION")
    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }

    internal fun stopForegroundNotification() {
        stopForegroundCompat()

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID)
        Log.d(TAG, "⏸️ 已移除後台常駐通知")
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
        // ✅ 銀行／支付 App 常把完整內容放在 bigText / subText（尤其 FCM push）
        val bigText = extras.getString(Notification.EXTRA_BIG_TEXT) ?: ""
        val subText = extras.getString(Notification.EXTRA_SUB_TEXT) ?: ""
        val packageName = sbn.packageName

        // 合併所有文字來源，避免漏掉內容
        val fullText = listOf(title, bigText, text, subText)
            .filter { it.isNotBlank() }
            .joinToString(" ")
            .trim()

        Log.d(TAG, "📥 收到通知 pkg=$packageName fullText=$fullText")

        // 判斷是否為支付通知
        if (!isPaymentNotification(fullText, packageName)) {
            return
        }

        // 提取金額
        val amount = PaymentTextAnalyzer.extractAmount(fullText)
        if (amount == null || amount <= 0) {
            Log.d(TAG, "🚫 無法從通知中提取金額: $fullText")
            return
        }

        // 提取商家名稱
        val merchant = extractMerchant(fullText)
        // ✅ 判斷轉帳方向（收入/支出）
        val isIncome = PaymentTextAnalyzer.isIncomeTransfer(fullText)
        // ✅ eventId 加入通知發佈時間：相同金額+相同文字的兩筆轉帳（不同時間）不會再互相誤判為重複
        val eventId = createEventId(packageName, amount, fullText, sbn.postTime)

        // 檢查自動記錄是否啟用
        if (!isAutoRecordEnabled()) {
            Log.d(TAG, "自動記帳已關閉")
            return
        }

        // ✅ 去重檢查必須在「顯示已記錄訊息」之前：
        //    否則重複通知也會跳出「✅ 已記錄」卻沒有任何新記錄。
        if (isAlreadyProcessed(eventId)) {
            Log.d(TAG, "⏭️ 忽略重複支付通知: $eventId")
            return
        }

        Log.d(TAG, "💰 檢測到支付通知: $fullText")
        Log.d(TAG, "  金額: $amount")
        Log.d(TAG, "  商家: $merchant")
        Log.d(TAG, "  方向: ${if (isIncome) "收入" else "支出"}")

        deliverRecord(amount, merchant, fullText, packageName, eventId, isIncome)
    }

    // ============================================================
    // ✅ 記錄交付：Flutter 執行中交給 Dart；否則（或 Dart 處理失敗）由原生端保存
    // ============================================================

    /**
     * 把記錄交給 Dart 端處理，並且**等待 Dart 端回報結果**：
     *
     * - Dart 回報 saved / duplicate → 才算處理完成，標記為已處理。
     * - Dart 回報 disabled（使用者關閉自動記錄）→ 不記錄、不標記。
     * - 其他狀況（Flutter 已結束、逾時、處理失敗、未實作）→ 由原生端直接保存。
     *
     * ⚠️ 舊版只要「送出成功」就標記為已處理，一旦 Flutter 端其實沒寫入
     *    （例如 App 被滑掉、engine 已銷毀但方法通道參照還在），這筆通知就
     *    永久被去重清單封鎖，明細頁再也看不到 → 這正是「有時沒記錄下來」的主因。
     */
    private fun deliverRecord(
        amount: Double,
        merchant: String?,
        text: String,
        packageName: String,
        eventId: String,
        isIncome: Boolean
    ) {
        val channel = methodChannel
        if (channel == null) {
            Log.d(TAG, "Flutter 未執行，改由原生端保存")
            saveRecordNatively(amount, merchant, eventId, isIncome)
            return
        }

        val data = JSONObject().apply {
            put("amount", amount)
            put("merchant", merchant ?: "")
            put("text", text)
            put("packageName", packageName)
            put("timestamp", System.currentTimeMillis())
            put("eventId", eventId)
            put("isIncome", isIncome)
        }

        val mainHandler = Handler(Looper.getMainLooper())
        var settled = false

        val timeoutRunnable = Runnable {
            if (!settled) {
                settled = true
                Log.w(TAG, "⏱️ Flutter 端逾時未回應，改由原生端保存")
                saveRecordNatively(amount, merchant, eventId, isIncome)
            }
        }

        try {
            channel.invokeMethod(
                "onPaymentNotification",
                data.toString(),
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        if (settled) return
                        settled = true
                        mainHandler.removeCallbacks(timeoutRunnable)

                        when (result as? String) {
                            STATUS_SAVED, STATUS_DUPLICATE -> {
                                Log.d(TAG, "📤 Flutter 端已完成記錄: $result")
                                markEventProcessed(eventId)
                                notifyRecordResult(true, merchant, amount)
                            }
                            STATUS_DISABLED -> {
                                Log.d(TAG, "⏸️ Dart 端回報自動記錄已停用，略過此通知")
                            }
                            STATUS_IGNORED -> {
                                // ✅ Dart 判定不是交易通知（廣告/推播）：
                                //    標記為已處理以免重複判斷，且不可回退保存。
                                Log.d(TAG, "📢 Dart 端判定非交易通知，忽略: $eventId")
                                markEventProcessed(eventId)
                            }
                            else -> {
                                Log.w(TAG, "⚠️ Flutter 端未能記錄（結果=$result），改由原生端保存")
                                saveRecordNatively(amount, merchant, eventId, isIncome)
                            }
                        }
                    }

                    override fun error(
                        errorCode: String,
                        errorMessage: String?,
                        errorDetails: Any?
                    ) {
                        if (settled) return
                        settled = true
                        mainHandler.removeCallbacks(timeoutRunnable)
                        Log.e(TAG, "❌ Flutter 端處理失敗: $errorCode $errorMessage")
                        saveRecordNatively(amount, merchant, eventId, isIncome)
                    }

                    override fun notImplemented() {
                        if (settled) return
                        settled = true
                        mainHandler.removeCallbacks(timeoutRunnable)
                        Log.e(TAG, "❌ Flutter 端未實作 onPaymentNotification")
                        saveRecordNatively(amount, merchant, eventId, isIncome)
                    }
                }
            )
            mainHandler.postDelayed(timeoutRunnable, FLUTTER_REPLY_TIMEOUT_MS)
        } catch (e: Exception) {
            if (!settled) {
                settled = true
                mainHandler.removeCallbacks(timeoutRunnable)
                Log.e(TAG, "發送通知到 Flutter 失敗: ${e.message}")
                saveRecordNatively(amount, merchant, eventId, isIncome)
            }
        }
    }

    /** ✅ 只有確實記錄成功／失敗時才更新後台常駐通知，不再提前顯示「已記錄」 */
    private fun notifyRecordResult(success: Boolean, merchant: String?, amount: Double) {
        if (!isBackgroundNotificationEnabled()) return

        val merchantDisplay = merchant?.takeIf { it.isNotBlank() } ?: "未知商家"
        val amountText = formatAmount(amount)
        val message = if (success) {
            "✅ 已記錄: $merchantDisplay - \$$amountText"
        } else {
            "⚠️ 記錄失敗: $merchantDisplay - \$$amountText"
        }

        createNotificationChannel()
        updateForegroundNotification(message)
    }

    private fun formatAmount(amount: Double): String {
        return if (amount == Math.floor(amount) && !amount.isInfinite()) {
            amount.toLong().toString()
        } else {
            String.format(Locale.US, "%.2f", amount)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // 通知被移除時可選處理
    }

    // ============================================================
    // ✅ 支付通知判斷（白名單包名 + 廣告過濾 + 交易格式）
    //    規則本體在 PaymentTextAnalyzer，與無障礙讀屏探針共用
    // ============================================================

    private fun isPaymentNotification(text: String, packageName: String): Boolean {
        if (packageName.isNullOrEmpty() || text.isNullOrEmpty()) {
            return false
        }
        // 永遠排除系統及本 App
        if (packageName == "com.android.systemui" ||
            packageName == "com.android.settings" ||
            packageName == "com.example.countapp") {
            return false
        }

        // 1) 包名必須在白名單內
        val allowedPackages = getAllowedPackages()
        val isPackageAllowed = allowedPackages.any { pkg ->
            packageName.contains(pkg, ignoreCase = true) || pkg.contains(packageName, ignoreCase = true)
        }
        if (!isPackageAllowed) {
            Log.d(TAG, "🚫 包名不在白名單內，忽略通知: $packageName")
            return false
        }

        // 2) 廣告推播：支付 App 的優惠訊息與交易通知共用同一個包名，
        //    因此這裡必須先擋掉，否則廣告會被當成一筆消費記下來。
        if (PaymentTextAnalyzer.isAdvertisement(text)) {
            Log.d(TAG, "📢 判定為廣告推播，忽略通知: $text")
            return false
        }

        // 3) 必須符合已知的交易通知格式（不再用「支付/成功/交易」等寬鬆關鍵字）
        if (!PaymentTextAnalyzer.hasPaymentSignal(text)) {
            Log.d(TAG, "🚫 非交易通知格式，忽略: $text")
            return false
        }

        return true
    }

    private fun getAllowedPackages(): List<String> {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        // ⚠️ 不能讀 "flutter.allowed_package_names"：
        //    shared_preferences 的 StringList 在 Android 上存的是
        //    "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu" + Java 序列化 Base64，
        //    不是 JSON。舊版直接 JSONArray() 一定拋例外 → 靜默退回預設值，
        //    導致使用者自訂的白名單在原生端完全失效。
        //    Dart 端另外寫了一份純 JSON 鏡像，這裡改讀它。
        try {
            val jsonStr = prefs.getString("flutter.allowed_package_names_json", null)
            if (!jsonStr.isNullOrEmpty()) {
                val jsonArr = JSONArray(jsonStr)
                val list = mutableListOf<String>()
                for (i in 0 until jsonArr.length()) {
                    val pkg = jsonArr.optString(i)
                    if (pkg.isNotBlank()) list.add(pkg)
                }
                if (list.isNotEmpty()) return list
            }
        } catch (e: Exception) {
            Log.e(TAG, "讀取白名單失敗: ${e.message}")
        }
        return DEFAULT_ALLOWED_PACKAGES
    }

    // ============================================================
    // ✅ 數據提取
    //
    // 金額／方向／廣告的判斷規則都集中在 PaymentTextAnalyzer，
    // 與無障礙讀屏探針（PaymentAccessibilityService）共用同一套規則。
    // ============================================================

    private fun extractMerchant(text: String): String? {
        // ✅ 依語意優先順序匹配（與 Dart 端一致）：
        // 1. 轉出對象（轉賬給/付款給/向 XXX 轉賬）
        // 2. 轉入來源（收到/來自 XXX 轉賬）
        // 3. 泛用「給 XXX」「由 XXX 轉賬」「- XXX」
        val patterns = listOf(
            Regex("""(?:轉賬|轉帳|转账|转帐|付款|支付|匯款|汇款|畀)\s*給\s*([^\s,，。]+)"""),
            Regex("""向\s*([^\s,，。]+)\s*(?:轉賬|轉帳|转账|转帐|付款|支付|匯款|汇款)"""),
            Regex("""(?:收到|來自|来自)\s*([^\s,，。]+)\s*(?:轉賬|轉帳|转账|转帐|匯款|汇款|的)"""),
            Regex("""給\s*([^\s,，。]+)"""),
            Regex("""由\s*([^\s,，。]+)\s*(?:轉賬|轉帳|轉账|转账|匯款|汇款)"""),
            Regex("""-\s*([^\s,，。]+)""")
        )
        for (pattern in patterns) {
            val match = pattern.find(text)
            if (match != null) {
                val name = match.groupValues[1].trim()
                if (name.isNotEmpty()) return name
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

    private fun isBackgroundNotificationEnabled(): Boolean {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getBoolean("flutter.background_notification_enabled", false)
    }

    // ============================================================
    // ✅ 原生端保存記錄（App 未執行，或 Flutter 端處理失敗時的最後防線）
    // ============================================================

    /**
     * 由原生端把記錄寫進 SharedPreferences，等待 Dart 端下次載入明細時匯入。
     *
     * ✅ 改為「一筆記錄一個鍵」（append-only）：
     *    舊版是「讀出整份 flutter.native_records → 加入新記錄 → 整份覆寫」，
     *    與 Dart 端的匯入（讀取＋刪除該鍵）交叉執行時會互相蓋掉，
     *    造成原生端已保存的記錄無聲消失。單鍵寫入沒有這個競態。
     */
    private fun saveRecordNatively(
        amount: Double,
        merchant: String?,
        eventId: String,
        isIncome: Boolean
    ) {
        val now = Date()
        val isoDate = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).format(now)
        val note = merchant?.takeIf { it.isNotBlank() }
            ?: if (isIncome) "轉賬收入" else "轉賬支出"
        val record = JSONObject().apply {
            put("amount", if (isIncome) amount else -amount)
            put("category", "轉帳")
            put("note", note)
            put("date", isoDate)
            put("createdAt", isoDate)
            put("id", eventId)
        }.toString()

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val key = "flutter.$NATIVE_RECORD_KEY_PREFIX$eventId"

        // ✅ 用 commit()：服務隨時可能被系統回收，必須確定資料已落地；
        //    寫入失敗時不可標記為已處理，否則這筆記錄會永久消失。
        val saved = prefs.edit().putString(key, record).commit()

        if (saved) {
            Log.d(TAG, "✅ 原生端已保存自動記帳: $record")
            markEventProcessed(eventId)
            notifyRecordResult(true, merchant, amount)
        } else {
            Log.e(TAG, "❌ 原生端保存自動記帳失敗，不標記為已處理")
            notifyRecordResult(false, merchant, amount)
        }
    }

    // ============================================================
    // ✅ 去重機制（記憶體 + SharedPreferences 持久化）
    //    注意：只有在「確實儲存成功」後才標記為已處理，
    //    避免儲存失敗時 eventId 被永久封鎖。
    // ============================================================

    /** 只檢查是否已處理過，不寫入任何狀態 */
    private fun isAlreadyProcessed(eventId: String): Boolean {
        val now = System.currentTimeMillis()
        synchronized(dedupeLock) {
            // 1. 清理過期的記憶體記錄
            recentEventIds.entries.removeIf { now - it.value > DEDUPE_WINDOW_MS }

            // 2. 檢查記憶體快取
            val lastSeen = recentEventIds[eventId]
            if (lastSeen != null && now - lastSeen <= DEDUPE_WINDOW_MS) {
                return true
            }

            // 3. 檢查 SharedPreferences（防止 App 重啟後重複處理）
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val processedIds = prefs.getStringSet("processed_notification_ids", mutableSetOf())
                ?: mutableSetOf()
            return processedIds.contains(eventId)
        }
    }

    /** 儲存成功後才呼叫：標記為已處理（記憶體 + SharedPreferences） */
    private fun markEventProcessed(eventId: String) {
        val now = System.currentTimeMillis()
        synchronized(dedupeLock) {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            // ⚠️ getStringSet 回傳的集合可能是不可修改的副本，務必複製成可變集合再操作
            val processedIds = HashSet(
                prefs.getStringSet("processed_notification_ids", mutableSetOf()) ?: mutableSetOf()
            )
            processedIds.add(eventId)
            recentEventIds[eventId] = now
            prefs.edit().putStringSet("processed_notification_ids", processedIds).apply()

            // 限制集合大小（避免無限增長）
            if (processedIds.size > 1000) {
                val toRemove = processedIds.size - 500
                val iterator = processedIds.iterator()
                repeat(toRemove) {
                    if (iterator.hasNext()) {
                        iterator.next()
                        iterator.remove()
                    }
                }
                prefs.edit().putStringSet("processed_notification_ids", processedIds).apply()
            }
            Log.d(TAG, "✅ 已標記通知為已處理: $eventId")
        }
    }

    // ============================================================
    // ✅ 建立事件唯一 ID
    // ============================================================

    private fun createEventId(
        packageName: String,
        amount: Double,
        text: String,
        postTime: Long = System.currentTimeMillis()
    ): String {
        val normalizedText = text.trim().replace(Regex("\\s+"), " ").lowercase(Locale.ROOT)
        // ✅ 加入通知發佈時間：相同金額+相同文字的兩筆轉帳（不同時間）不會再互相誤判為重複
        val source = "$packageName|${"%.2f".format(Locale.US, amount)}|$postTime|$normalizedText"
        val digest = MessageDigest.getInstance("SHA-256").digest(source.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }
}