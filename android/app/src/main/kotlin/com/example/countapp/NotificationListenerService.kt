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

        // ============================================================
        // ✅ 通知過濾規則（與 Dart 端 lib/services/ai_service.dart 保持同步）
        //
        //    問題：支付 App 的行銷推播與真實交易通知來自「同一個包名」，
        //    舊版只要求「白名單包名 + 任一寬鬆關鍵字」，而關鍵字裡包含
        //    單獨的「成功」「交易」「$」以及 App 名稱「MPay」——這些在
        //    廣告文案裡同樣會出現，於是「海鮮自助晚餐 268起」這類廣告
        //    也被當成一筆交易記錄下來。
        //
        //    現在的規則改為三段式，必須「全部通過」才記錄：
        //      1. 包名必須在白名單內
        //      2. 出現硬廣告字樣 → 直接丟棄
        //      3. 必須命中「已知交易格式」才記錄（不再用寬鬆關鍵字）
        // ============================================================

        /**
         * 硬廣告字樣：真實的交易通知（付款/轉賬成功）不會出現這些行銷用語。
         *
         * ⚠️ 只收錄「明確屬於推廣文案」的詞，避免誤殺真實交易。
         *    例如「訂閱」「自助餐」「元」等可能出現在正常消費描述中的詞
         *    刻意不收錄。
         */
        private val AD_MARKERS = listOf(
            "秒殺", "搶購", "限量", "特價", "抵價", "至抵", "震撼價", "優惠價",
            "優惠券", "優惠碼", "限時優惠", "獨家優惠", "會員優惠", "生日優惠",
            "折扣", "半價", "五折", "折上折", "買一送一",
            "抽獎", "中獎", "恭喜", "著數", "快閃", "期間限定", "有獎活動",
            "免費領取", "立即下載", "立即搶", "即刻入", "新品上市",
            "尊享", "專享", "推廣", "廣告", "推薦好友", "邀請碼", "填問卷",
            "積分兌換", "限量發售"
        )

        /**
         * 已知的交易通知格式。必須命中其中一項，才可能是真實交易。
         *
         * 這裡刻意只收錄「交易結果」的固定語句，而不是單獨的「支付」
         * 「交易」「成功」等字，因為那些字在廣告文案中也會出現。
         */
        private val PAYMENT_SIGNAL_PATTERNS = listOf(
            // 支付／交易／轉賬 + 結果：支付成功、交易成功、轉賬成功、付款完成
            Regex(
                """(?:支付|付款|交易|消費|扣款|刷卡|匯款|汇款|轉賬|轉帳|转账|轉出|轉入)\s*(?:成功|完成|已成功|失敗|失败)"""
            ),
            // 結果 + 動作：成功交易、成功轉賬、成功付款
            Regex(
                """成功\s*(?:支付|付款|交易|轉賬|轉帳|转账|消費|扣款|匯款|轉出|轉入)"""
            ),
            // 已支付／已扣款／已轉賬
            Regex(
                """(?:已|經|经)\s*(?:支付|付款|扣款|轉賬|轉帳|转账|匯出|匯入|收款|消費)"""
            ),
            // 轉賬動詞本身（廣告文案不會出現「轉賬／轉帳」）
            Regex("""(?:轉賬|轉帳|转账|轉出|轉入|匯出|匯入|匯款|汇款)"""),
            // 收到款項：收到 XXX 轉賬、入賬 MOP100
            Regex(
                """(?:收到|入賬|入帳).{0,12}(?:轉賬|轉帳|转账|款項|金額|MOP|HK)"""
            ),
            // 支付名詞 + 帶貨幣標記的金額，例如「消費 HK$1,234.50」「交易 MOP50」
            // （銀行／支付 App 的對帳通知常沒有「成功」字樣；
            //   但金額必須帶貨幣代碼或符號，廣告的「268起」這類裸數字不算）
            Regex(
                """(?:消費|交易|付款|支付|扣款|刷卡|轉賬|轉帳|转账|匯款|汇款|金額)\s*[：:]?\s*(?:MOP|HK|RMB|CNY|USD|TWD|NTD|NT|澳門幣|人民幣|港幣|[\$¥€£])\s*\$?\s*\d""",
                RegexOption.IGNORE_CASE
            ),
            // 明確的金額欄位
            Regex("""(?:交易金額|付款金額|消費金額|扣款金額|轉賬金額|金額)\s*[：:]"""),
            // 常見支付 App 的交易描述
            Regex("""(?:你已支付|您已支付|已成功付款|付款給|支付給|轉賬給)"""),
            // 英文
            Regex(
                """(?:payment|transaction|transfer)\s+(?:successful|completed|sent|received|of)""",
                RegexOption.IGNORE_CASE
            ),
            Regex("""you\s+(?:paid|received|sent)""", RegexOption.IGNORE_CASE),
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
        val amount = extractAmount(fullText)
        if (amount == null || amount <= 0) {
            Log.d(TAG, "🚫 無法從通知中提取金額: $fullText")
            return
        }

        // 提取商家名稱
        val merchant = extractMerchant(fullText)
        // ✅ 判斷轉帳方向（收入/支出）
        val isIncome = isIncomeTransfer(fullText)
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
    // ============================================================

    /** 是否為行銷／廣告推播（見 [AD_MARKERS]） */
    private fun isAdvertisement(text: String): Boolean =
        AD_MARKERS.any { text.contains(it, ignoreCase = true) }

    /** 是否符合已知的交易通知格式（見 [PAYMENT_SIGNAL_PATTERNS]） */
    private fun hasPaymentSignal(text: String): Boolean =
        PAYMENT_SIGNAL_PATTERNS.any { it.containsMatchIn(text) }

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
        if (isAdvertisement(text)) {
            Log.d(TAG, "📢 判定為廣告推播，忽略通知: $text")
            return false
        }

        // 3) 必須符合已知的交易通知格式（不再用「支付/成功/交易」等寬鬆關鍵字）
        if (!hasPaymentSignal(text)) {
            Log.d(TAG, "🚫 非交易通知格式，忽略: $text")
            return false
        }

        return true
    }

    private fun getAllowedPackages(): List<String> {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val defaultList = listOf(
            "com.macaupass.rechargeEasy",
            "com.alipay.android.app",
            "com.tencent.mm",
            "com.google.android.apps.wallet",
            "com.apple.wallet",
            "com.octopus.nfc",
            "hk.com.boc.bocmobilebanking",
            "com.icbc.imobile"
        )
        try {
            val jsonStr = prefs.getString("flutter.allowed_package_names", null)
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
        return defaultList
    }

    // ============================================================
    // ✅ 數據提取
    // ============================================================

    private fun extractAmount(text: String): Double? {
        // 1) 貨幣代碼／符號在數字前，例如
        //   「成功轉賬MOP1.00」→ 1.00、「MOP 1.00」「MOP$1.00」
        //   「HK$1,234.5」「澳門幣1.00」「金額：HK$ 12.00」
        val currencyPatterns = listOf(
            Regex(
                """(?:MOP|HK|RMB|CNY|USD|EUR|TWD|NTD|JPY|澳門幣|澳门币|人民幣|人民币|港幣|港币|美元|歐元|欧元|台幣|台币|元)\s*\$?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)""",
                RegexOption.IGNORE_CASE
            ),
            // 2) 貨幣單位在數字後，例如「12.00 元」「1,234.50 澳門幣」
            Regex(
                """(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)\s*(?:元|圓|块|塊|澳門幣|澳门币|人民幣|人民币|港幣|港币|美元|歐元|欧元|台幣|台币)"""
            ),
            // 3) 明確的金額欄位，例如「金額 268」「交易金額：MOP 30」
            Regex(
                """(?:交易金額|付款金額|消費金額|扣款金額|轉賬金額|金額)\s*[：:]?\s*\$?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)"""
            ),
            // 4) 通用貨幣符號
            Regex("""[\$¥€£]\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)"""),
        )
        for (pattern in currencyPatterns) {
            for (match in pattern.findAll(text)) {
                val amountStr = match.groupValues[1].replace(",", "")
                val amount = amountStr.toDoubleOrNull()
                if (amount != null && amount > 0) {
                    return amount
                }
            }
        }

        // 5) 裸數字（含小數），但要排除時間(HH:mm:ss)、日期(2026-09-10)、
        //    訂單號(2026091003453572166504)、電話號碼等。
        val bareNumber = Regex(
            """(?<![\d:./-])(\d{1,3}(?:,\d{3})*\.\d{1,2})(?![\d:./-])"""
        )
        for (match in bareNumber.findAll(text)) {
            val amountStr = match.groupValues[1].replace(",", "")
            val amount = amountStr.toDoubleOrNull()
            if (amount != null && amount > 0) {
                return amount
            }
        }

        // 6) 最後手段：緊跟在交易動詞後的數字（整數也接受），例如「支付 50」
        //
        // ⚠️ 舊版是「支付/成功/MOP 等關鍵字後 40 字內的第一個整數」，
        //    範圍過寬，會把廣告文案裡的價格（例如「海鮮自助晚餐 268起」）
        //    當成交易金額。這裡改成要求數字必須緊接在交易動詞之後，
        //    且動詞清單只保留真正的交易動作。
        val afterVerb = Regex(
            """(?:轉賬|轉帳|转账|轉出|轉入|支付|付款|消費|扣款|匯款|汇款)\s*(?:了|給|至|金額)?\s*(?:MOP|HK\$|RMB|CNY|USD|¥|\$)?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)(?!\d)""",
            RegexOption.IGNORE_CASE
        )
        for (match in afterVerb.findAll(text)) {
            val amountStr = match.groupValues[1].replace(",", "")
            val amount = amountStr.toDoubleOrNull()
            if (amount != null && amount > 0) {
                return amount
            }
        }
        return null
    }

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

    /** 判斷是否為「收入」轉帳（收到錢）；否則視為支出（付錢出去） */
    private fun isIncomeTransfer(text: String): Boolean {
        val incomeKeywords = listOf(
            "收到", "入賬", "入帳", "轉入", "转入", "收款", "來自", "来自",
            "匯入", "汇入", "進賬", "進帳", "收入", "credited", "received", "deposit"
        )
        return incomeKeywords.any { text.contains(it, ignoreCase = true) }
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