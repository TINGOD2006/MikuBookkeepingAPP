package com.example.countapp

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject

/**
 * ⚠️ 這是「可行性探針」，不是正式的記帳來源。
 *
 * 目的：確認微信／支付寶等 App 的付款結果畫面，在 Android 無障礙節點樹裡
 * 到底有沒有可讀的文字。
 *
 * 為什麼要先做探針：這類 App 大量使用自繪視圖（Canvas/Skia）與內嵌 WebView，
 * 這些內容在無障礙樹裡往往**完全沒有文字節點**。若真是如此，讀屏這條路線
 * 從根本上就行不通，應該及早放棄，而不是把整套自動記帳邏輯建上去之後才發現。
 *
 * 目前行為：
 *   - 只接收 [PROBE_PACKAGES] 內 App 的視窗事件（見
 *     res/xml/payment_accessibility_service_config.xml 的 android:packageNames）
 *   - 把節點樹的文字 dump 到 logcat（tag: A11yProbe）以及 SharedPreferences，
 *     讓 App 內的「無障礙讀屏探針」頁面可以直接查看
 *   - **不會**建立任何記帳記錄
 *
 * 若探針證實讀得到文字，再把這裡接上與通知相同的記錄流程
 * （PaymentTextAnalyzer 的判定邏輯已經是共用的）。
 */
class PaymentAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "A11yProbe"

        /** 與 Dart 端 shared_preferences 插件共用同一個檔案 */
        private const val PREFS_NAME = "FlutterSharedPreferences"

        /** 鍵名前綴 "flutter." 讓 Dart 端可以直接用 SharedPreferences 讀取 */
        const val KEY_PROBE_LOGS = "flutter.accessibility_probe_logs"

        /** 最多保留幾筆探針結果 */
        private const val MAX_LOGS = 30

        /** 單一節點樹最多走訪幾個節點（避免異常的深樹卡住） */
        private const val MAX_NODES = 1500

        /** 最多往下走幾層 */
        private const val MAX_DEPTH = 40

        /** 單筆記錄保留的文字長度上限 */
        private const val MAX_TEXT_LENGTH = 4000

        /**
         * 只讀這些 App 的畫面。
         *
         * ⚠️ 必須與 res/xml/payment_accessibility_service_config.xml 的
         *    android:packageNames 保持一致；XML 是系統層的硬性過濾，
         *    這裡是第二道確認。
         */
        val PROBE_PACKAGES = listOf(
            "com.tencent.mm",              // 微信
            "com.eg.android.AlipayGphone", // 支付寶（中國）
            "hk.alipay.wallet",            // AlipayHK
            "com.alipay.android.app",      // 支付寶 SDK／安全支付
            "com.macaupass.rechargeEasy",  // MPay 澳門通
        )

        fun isProbeTarget(packageName: String?): Boolean {
            if (packageName.isNullOrEmpty()) return false
            return PROBE_PACKAGES.any { it.equals(packageName, ignoreCase = true) }
        }

        /** 讀取探針結果（JSON 陣列字串） */
        fun readLogs(context: Context): String {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getString(KEY_PROBE_LOGS, "[]") ?: "[]"
        }

        /** 清空探針結果 */
        fun clearLogs(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().remove(KEY_PROBE_LOGS).apply()
        }

        /**
         * 這個無障礙服務目前是否已由使用者在系統設定中啟用。
         *
         * 讀取 Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES，並用
         * ComponentName 逐項比對，避免 "pkg/.Class" 與 "pkg/full.Class"
         * 兩種寫法造成誤判。
         */
        fun isEnabled(context: Context): Boolean {
            return try {
                val flat = Settings.Secure.getString(
                    context.contentResolver,
                    Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
                ) ?: return false

                val target = ComponentName(context, PaymentAccessibilityService::class.java)
                flat.split(":").any { entry ->
                    val parsed = ComponentName.unflattenFromString(entry)
                    parsed != null &&
                        parsed.packageName == target.packageName &&
                        parsed.className == target.className
                }
            } catch (e: Exception) {
                Log.e(TAG, "檢查無障礙服務狀態失敗: ${e.message}")
                false
            }
        }
    }

    /** 節點樹走訪結果 */
    private class NodeDump {
        var nodeCount = 0
        val texts = mutableListOf<String>()
    }

    /** 上一次 dump 的簽章，避免同一個畫面被反覆記錄 */
    private var lastSignature: String? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i(TAG, "✅ 無障礙讀屏探針已連接（只讀取 ${PROBE_PACKAGES.size} 個支付 App）")
    }

    override fun onInterrupt() {
        Log.w(TAG, "⚠️ 無障礙讀屏探針被中斷")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val packageName = event.packageName?.toString() ?: return
        // 不讀自己
        if (packageName == applicationContext.packageName) return
        // 只讀白名單內的支付 App
        if (!isProbeTarget(packageName)) return

        val root = rootInActiveWindow ?: event.source ?: return

        val dump = NodeDump()
        collectTexts(root, dump, 0)

        val joined = dump.texts.distinct().joinToString(" ｜ ")
        val signature = "$packageName|${event.eventType}|$joined"
        if (signature == lastSignature) return // 同一畫面，不重複記錄
        lastSignature = signature

        val entry = buildEntry(event, packageName, dump, joined)
        appendLog(entry)

        Log.i(TAG, "📥 ${entry.optString("verdict")}")
        Log.i(TAG, "   pkg=$packageName nodes=${dump.nodeCount} texts=${dump.texts.size}")
        Log.i(TAG, "   text=$joined")
    }

    // ============================================================
    // ✅ 節點樹走訪
    // ============================================================

    private fun collectTexts(node: AccessibilityNodeInfo?, dump: NodeDump, depth: Int) {
        if (node == null) return
        if (depth > MAX_DEPTH || dump.nodeCount >= MAX_NODES) return

        dump.nodeCount++

        val text = node.text?.toString()?.trim()
        if (!text.isNullOrEmpty()) dump.texts.add(text)

        // contentDescription 也要收：很多自繪元件把文字放在這裡
        val description = node.contentDescription?.toString()?.trim()
        if (!description.isNullOrEmpty() && description != text) {
            dump.texts.add(description)
        }

        for (i in 0 until node.childCount) {
            collectTexts(node.getChild(i), dump, depth + 1)
        }
    }

    // ============================================================
    // ✅ 建立探針結果
    // ============================================================

    private fun buildEntry(
        event: AccessibilityEvent,
        packageName: String,
        dump: NodeDump,
        joined: String
    ): JSONObject {
        val nodeCount = dump.nodeCount
        val textCount = dump.texts.size

        val paymentLike = PaymentTextAnalyzer.isPaymentText(joined)
        val advertisement = PaymentTextAnalyzer.isAdvertisement(joined)
        val amount = PaymentTextAnalyzer.extractAmount(joined)
        val isIncome = PaymentTextAnalyzer.isIncomeTransfer(joined)

        val verdict = when {
            nodeCount == 0 ->
                "⚠️ 完全取不到節點 → 讀不到這個畫面"
            textCount == 0 ->
                "❌ 節點樹沒有任何文字（自繪視圖／WebView）→ 讀屏這條路線不可行"
            advertisement ->
                "📢 讀到 $textCount 段文字，但判定為廣告推播（不會記錄）"
            paymentLike && amount != null ->
                "✅ 讀到 $textCount 段文字，判定可記錄：金額 ${if (isIncome) "+" else "-"}$amount"
            paymentLike ->
                "🟡 讀到 $textCount 段文字，像交易但取不到金額"
            else ->
                "🟡 讀到 $textCount 段文字，但不符合已知交易格式（不會記錄）"
        }

        return JSONObject().apply {
            put("time", System.currentTimeMillis())
            put("package", packageName)
            put("className", event.className?.toString() ?: "")
            put("eventType", eventTypeName(event.eventType))
            put("nodeCount", nodeCount)
            put("textCount", textCount)
            put("paymentLike", paymentLike)
            put("advertisement", advertisement)
            put("amount", amount ?: JSONObject.NULL)
            put("isIncome", isIncome)
            put("verdict", verdict)
            put("text", joined.take(MAX_TEXT_LENGTH))
        }
    }

    private fun eventTypeName(type: Int): String = when (type) {
        AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> "WINDOW_STATE_CHANGED"
        AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> "WINDOW_CONTENT_CHANGED"
        AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> "VIEW_TEXT_CHANGED"
        AccessibilityEvent.TYPE_WINDOWS_CHANGED -> "WINDOWS_CHANGED"
        else -> type.toString()
    }

    /** 追加一筆探針結果，只保留最近 [MAX_LOGS] 筆 */
    private fun appendLog(entry: JSONObject) {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existing = prefs.getString(KEY_PROBE_LOGS, null)
            val array = if (existing.isNullOrEmpty()) JSONArray() else JSONArray(existing)
            array.put(entry)

            val trimmed = JSONArray()
            val start = maxOf(0, array.length() - MAX_LOGS)
            for (i in start until array.length()) {
                trimmed.put(array.get(i))
            }

            prefs.edit().putString(KEY_PROBE_LOGS, trimmed.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "寫入探針結果失敗: ${e.message}")
        }
    }
}
