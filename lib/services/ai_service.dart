import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/record.dart';

/// AI 分類服務
class AIService {
  // ========== 配置 ==========

  /// 請求超時時間
  static const Duration timeout = Duration(seconds: 5);

  /// 最大重試次數
  static const int maxRetries = 2;

  /// AI 設定（由用戶自行設定）
  static const String prefApiUrl = 'ai_api_url';
  static const String prefApiKey = 'ai_api_key';
  static const String prefModel = 'ai_model';

  /// 儲存用戶自訂的 AI 設定
  static Future<void> saveConfig({
    required String apiUrl,
    required String apiKey,
    required String model,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefApiUrl, apiUrl.trim());
    await prefs.setString(prefApiKey, apiKey.trim());
    await prefs.setString(prefModel, model.trim());
  }

  /// 讀取用戶自訂的 AI 設定；未完整設定時回傳 null
  static Future<AIConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final apiUrl = prefs.getString(prefApiUrl)?.trim() ?? '';
    final apiKey = prefs.getString(prefApiKey)?.trim() ?? '';
    final model = prefs.getString(prefModel)?.trim() ?? '';
    if (apiUrl.isEmpty || apiKey.isEmpty || model.isEmpty) {
      return null;
    }
    return AIConfig(apiUrl: apiUrl, apiKey: apiKey, model: model);
  }

  /// 是否已設定完整的 AI API
  static Future<bool> hasValidConfig() async {
    return await loadConfig() != null;
  }

  // ========== 主要方法 ==========

  /// 將支付通知文字傳送給 AI 進行分類
  static Future<AIClassificationResult> classifyNotification(
    String notificationText, {
    int retries = 0,
  }) async {
    if (notificationText.trim().isEmpty) {
      return AIClassificationResult(
        category: '其他',
        note: '空通知',
        confidence: 0.0,
      );
    }

    final config = await loadConfig();
    if (config == null) {
      debugPrint('⚠️ 尚未設定 AI API，改用本地分類');
      // ✅ 使用含「用戶自訂規則」的規則表，而不是只有內建規則
      return localClassifyAsync(notificationText);
    }

    try {
      final response = await http
          .post(
            Uri.parse(config.apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${config.apiKey}',
            },
            body: jsonEncode({
              'model': config.model,
              'messages': [
                {
                  'role': 'system',
                  'content': '你是記帳分類助手。請根據用戶輸入的支付通知內容，判斷消費類別。類別只能是以下之一：食物、交通、購物、娛樂、醫療、教育、房租、水電、通訊、保險、稅務、捐款、紅包、轉帳、其他。請以 JSON 格式回覆，包含 category（類別）、note（簡短備註）、confidence（信心指數0-1）。範例回覆：{"category":"食物","note":"午餐消費","confidence":0.95}',
                },
                {'role': 'user', 'content': notificationText},
              ],
              'temperature': 0.3,
              'max_tokens': 100,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        try {
          final result = jsonDecode(content);
          return AIClassificationResult(
            category: result['category'] as String? ?? '其他',
            note: result['note'] as String? ?? notificationText,
            confidence: (result['confidence'] as num?)?.toDouble() ?? 0.5,
          );
        } catch (e) {
          debugPrint('AI 回應 JSON 解析失敗: $e');
          return await localClassifyAsync(notificationText);
        }
      } else {
        debugPrint('AI API 錯誤: ${response.statusCode} - ${response.body}');
        if (retries < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (retries + 1)));
          return await classifyNotification(
            notificationText,
            retries: retries + 1,
          );
        }
        return await localClassifyAsync(notificationText);
      }
    } on http.ClientException catch (e) {
      debugPrint('AI API 網絡錯誤: $e');
      if (retries < maxRetries) {
        await Future.delayed(Duration(milliseconds: 500 * (retries + 1)));
        return await classifyNotification(notificationText, retries: retries + 1);
      }
      return localClassifyAsync(notificationText);
    } catch (e) {
      debugPrint('AI API 錯誤: $e');
      return localClassifyAsync(notificationText);
    }
  }

  // ========== 本地備用分類 ==========

  /// SharedPreferences 鍵：用戶自訂規則表（每個分類的詞條）
  static const String prefCustomRules = 'custom_classify_rules';

  /// 預設分類規則（內建，可被用戶自訂規則覆蓋/擴充）
  static Map<String, List<String>> get defaultRules => {
        '食物': [
          'food',
          '餐',
          '吃',
          'restaurant',
          '午餐',
          '晚餐',
          '早餐',
          '下午茶',
          '餐廳',
          '便當',
          '外賣',
          'delivery',
          'eat',
          'meal',
          'cafe',
          'coffee',
          '麥當勞',
          '肯德基',
          '星巴克',
          '摩斯',
          '漢堡王',
          'subway',
          '路易莎',
          'cama',
        ],
        '交通': [
          'transport',
          '交通',
          '車',
          'taxi',
          'bus',
          'mtr',
          '地鐵',
          '火車',
          'uber',
          'grab',
          '高鐵',
          '台鐵',
          '捷運',
          '公車',
          '客運',
          '渡輪',
          '加油',
          '停車',
          '停車費',
          '過路費',
          'etag',
          '車票',
          '機票',
        ],
        '購物': [
          'shop',
          '購物',
          'store',
          '超市',
          '網購',
          '電商',
          'pchome',
          'momo',
          '蝦皮',
          'shopee',
          '淘寶',
          '京東',
          '天貓',
          'costco',
          '家樂福',
          '全聯',
          '美廉社',
          '屈臣氏',
          '康是美',
          '寶雅',
          'uniqlo',
          'zara',
          'h&m',
          'nike',
          'adidas',
          'apple',
          '小米',
          '3c',
          '家電',
        ],
        '娛樂': [
          'entertain',
          '娛樂',
          'movie',
          '電影',
          'game',
          '遊戲',
          '演唱會',
          '票',
          'netflix',
          'spotify',
          'youtube',
          'premium',
          '迪士尼',
          '環球',
          '遊樂園',
          'ktv',
          '唱歌',
          '酒吧',
          '夜店',
          'party',
        ],
        '醫療': [
          'medical',
          '醫療',
          'doctor',
          '醫生',
          '醫院',
          '診所',
          '藥局',
          '看病',
          '掛號',
          '健保',
          '牙醫',
          '眼科',
          '皮膚科',
          '復健',
          '藥費',
          '檢查',
          '體檢',
          '疫苗',
          '口罩',
        ],
        '教育': [
          'education',
          '教育',
          '學校',
          '課程',
          '補習',
          '學費',
          '書',
          '教材',
          '文具',
          '才藝',
          '語言',
          '英文',
          '日文',
          '家教',
          '大學',
          '研究所',
          '考試',
          '證照',
          '培訓',
        ],
        '房租': ['rent', '房租', '租金', '租屋', '套房', '公寓', '押金', '管理費'],
        '水電': [
          '水費',
          '電費',
          '煤氣',
          '瓦斯',
          'utilities',
          '水電',
          '天然氣',
          '帳單',
          '繳費',
          '台電',
          '自來水',
        ],
        '通訊': [
          'phone',
          '手機',
          '網路',
          '寬頻',
          '電信',
          '話費',
          '月租',
          '中華電信',
          '台灣大哥大',
          '遠傳',
          '亞太',
          '台灣之星',
        ],
        '保險': [
          '保險',
          'insurance',
          '保費',
          '壽險',
          '醫療險',
          '意外險',
          '車險',
          '產險',
          '儲蓄險',
          '投資型',
        ],
        '稅務': ['稅', 'tax', '所得稅', '營業稅', '房屋稅', '地價稅', '牌照稅'],
        '捐款': ['捐款', '捐贈', '慈善', '公益', 'fund', 'donate', '紅十字會'],
        '紅包': ['紅包', '禮金', '包紅', '結婚', '喜宴', '生日禮物'],
        '轉帳': ['轉賬', '轉帳', 'transfer', '轉帳成功', '轉賬成功', '轉帳給', '轉賬給'],
      };

  /// 讀取「有效規則表」＝內建規則 + 用戶自訂規則（自訂可新增分類，也可覆蓋內建分類詞條）
  static Future<Map<String, List<String>>> loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, List<String>> rules = {};
    // 用戶自訂規則優先（排前面，先匹配）
    final customJson = prefs.getString(prefCustomRules);
    if (customJson != null && customJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(customJson) as Map<String, dynamic>;
        decoded.forEach((cat, value) {
          final words = (value as List<dynamic>)
              .whereType<String>()
              .map((w) => w.trim())
              .where((w) => w.isNotEmpty)
              .toList();
          if (words.isNotEmpty) {
            rules[cat] = words; // 完全覆蓋該分類詞條（用戶編輯的就是整個清單）
          }
        });
      } catch (e) {
        debugPrint('⚠️ 讀取自訂規則表失敗: $e');
      }
    }
    // 內建規則（若該分類未被自訂覆蓋）
    defaultRules.forEach((cat, words) {
      rules.putIfAbsent(cat, () => List.from(words));
    });
    return rules;
  }

  /// 儲存用戶自訂規則表（只存用戶有編輯過的分類）
  static Future<void> saveCustomRules(Map<String, List<String>> customRules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefCustomRules,
      jsonEncode(customRules),
    );
  }

  /// 移除用戶自訂規則（恢復內建預設）
  static Future<void> resetRules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefCustomRules);
  }

  /// 本地備用分類規則
  static Future<AIClassificationResult> localClassifyAsync(String text) async {
    final rules = await loadRules();
    return _classifyWithRules(text, rules);
  }

  /// 本地備用分類規則（同步版：使用內建規則，供測試/緊急使用）
  static AIClassificationResult localClassify(String text) {
    return _classifyWithRules(text, defaultRules);
  }

  static AIClassificationResult _classifyWithRules(
    String text,
    Map<String, List<String>> keywords,
  ) {
    final lowerText = text.toLowerCase();

    // 匹配關鍵詞
    for (final entry in keywords.entries) {
      for (final keyword in entry.value) {
        if (lowerText.contains(keyword)) {
          final cleanedText = _cleanText(text);
          return AIClassificationResult(
            category: entry.key,
            // ✅ 安全截取，使用 cleanedText 的長度
            note: cleanedText.isNotEmpty
                ? cleanedText.substring(0, cleanedText.length.clamp(0, 80))
                : '無備註',
            confidence: 0.7,
          );
        }
      }
    }

    // 預設分類
    final cleanedText = _cleanText(text);
    return AIClassificationResult(
      category: '其他',
      note: cleanedText.isNotEmpty
          ? cleanedText.substring(0, cleanedText.length.clamp(0, 80))
          : '無備註',
      confidence: 0.3,
    );
  }

  // ========== 輔助方法 ==========

  /// 清理文字（移除多餘空格和特殊字符）
  static String _cleanText(String text) {
    if (text.isEmpty) return '無備註';
    // 移除多餘空格
    String cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    // 移除特殊字符（保留中文、英文、數字）
    cleaned = cleaned.replaceAll(RegExp(r'[^\u4e00-\u9fa5a-zA-Z0-9\s]'), ' ');
    cleaned = cleaned.trim();
    return cleaned.isEmpty ? '無備註' : cleaned;
  }

  // ========== 通知過濾規則 ==========
  //
  // ⚠️ 這裡的規則與 Android 原生端
  //    android/app/src/main/kotlin/com/example/countapp/NotificationListenerService.kt
  //    的 AD_MARKERS / PAYMENT_SIGNAL_PATTERNS 必須保持一致。
  //
  // 問題：支付 App 的行銷推播與真實交易通知來自同一個包名，舊版只要求
  // 「白名單包名 + 任一寬鬆關鍵字」，而關鍵字包含單獨的「成功」「交易」
  // 以及 App 名稱「MPay」——廣告文案同樣含有這些字，於是
  // 「海鮮自助晚餐 268起」這類廣告也被記成一筆消費。

  /// 硬廣告字樣：真實交易通知不會出現這些行銷用語。
  ///
  /// 只收錄「明確屬於推廣文案」的詞，避免誤殺真實交易
  /// （例如「訂閱」「自助餐」等可能出現在正常消費描述的詞刻意不收錄）。
  static const List<String> adMarkers = [
    '秒殺', '搶購', '限量', '特價', '抵價', '至抵', '震撼價', '優惠價',
    '優惠券', '優惠碼', '限時優惠', '獨家優惠', '會員優惠', '生日優惠',
    '折扣', '半價', '五折', '折上折', '買一送一',
    '抽獎', '中獎', '恭喜', '著數', '快閃', '期間限定', '有獎活動',
    '免費領取', '立即下載', '立即搶', '即刻入', '新品上市',
    '尊享', '專享', '推廣', '廣告', '推薦好友', '邀請碼', '填問卷',
    '積分兌換', '限量發售',
  ];

  /// 已知的交易通知格式。必須命中其中一項，才可能是真實交易。
  ///
  /// 刻意只收錄「交易結果」的固定語句，而不是單獨的「支付」「交易」
  /// 「成功」等字，因為那些字在廣告文案中也會出現。
  static final List<RegExp> _paymentSignalPatterns = [
    // 支付／交易／轉賬 + 結果：支付成功、交易成功、轉賬成功、付款完成
    RegExp(
      r'(?:支付|付款|交易|消費|扣款|刷卡|匯款|汇款|轉賬|轉帳|转账|轉出|轉入)\s*(?:成功|完成|已成功|失敗|失败)',
    ),
    // 結果 + 動作：成功交易、成功轉賬、成功付款
    RegExp(r'成功\s*(?:支付|付款|交易|轉賬|轉帳|转账|消費|扣款|匯款|轉出|轉入)'),
    // 已支付／已扣款／已轉賬
    RegExp(r'(?:已|經|经)\s*(?:支付|付款|扣款|轉賬|轉帳|转账|匯出|匯入|收款|消費)'),
    // 轉賬動詞本身（廣告文案不會出現「轉賬／轉帳」）
    RegExp(r'(?:轉賬|轉帳|转账|轉出|轉入|匯出|匯入|匯款|汇款)'),
    // 收到款項：收到 XXX 轉賬、入賬 MOP100
    RegExp(r'(?:收到|入賬|入帳).{0,12}(?:轉賬|轉帳|转账|款項|金額|MOP|HK)'),
    // 支付名詞 + 帶貨幣標記的金額，例如「消費 HK$1,234.50」「交易 MOP50」
    // （銀行／支付 App 的對帳通知常沒有「成功」字樣；
    //   但金額必須帶貨幣代碼或符號，廣告的「268起」這類裸數字不算）
    RegExp(
      r'(?:消費|交易|付款|支付|扣款|刷卡|轉賬|轉帳|转账|匯款|汇款|金額)\s*[：:]?\s*(?:MOP|HK|RMB|CNY|USD|TWD|NTD|NT|澳門幣|人民幣|港幣|[\$¥€£])\s*\$?\s*\d',
      caseSensitive: false,
    ),
    // 明確的金額欄位
    RegExp(r'(?:交易金額|付款金額|消費金額|扣款金額|轉賬金額|金額)\s*[：:]'),
    // 常見支付 App 的交易描述
    RegExp(r'(?:你已支付|您已支付|已成功付款|付款給|支付給|轉賬給)'),
    // 英文
    RegExp(
      r'(?:payment|transaction|transfer)\s+(?:successful|completed|sent|received|of)',
      caseSensitive: false,
    ),
    RegExp(r'you\s+(?:paid|received|sent)', caseSensitive: false),
  ];

  /// 是否為行銷／廣告推播
  static bool isAdvertisement(String text) {
    final lower = text.toLowerCase();
    return adMarkers.any((marker) => lower.contains(marker.toLowerCase()));
  }

  /// 文字是否符合已知的交易通知格式
  static bool hasPaymentSignal(String text) {
    return _paymentSignalPatterns.any((pattern) => pattern.hasMatch(text));
  }

  /// 這則通知的文字是否「像一筆交易」。
  ///
  /// 與原生端 `isPaymentNotification()` 一致：只判斷廣告與交易格式，
  /// 金額是否存在由呼叫端另外確認（因為「符合交易格式但取不到金額」
  /// 要回報 failed，讓原生端知道這筆通知沒被記錄）。
  static bool isPaymentNotificationText(String text) {
    if (text.trim().isEmpty) return false;
    if (isAdvertisement(text)) return false;
    return hasPaymentSignal(text);
  }

  /// 從通知中提取金額（支援 MOP1.00 / MOP$1.00 / HK$1,234.5 / 澳門幣1.00 等格式，
  /// 並排除時間、日期、訂單號等干擾數字）
  static double? extractAmount(String text) {
    final currencyPatterns = [
      // 1) 貨幣代碼／符號在數字前
      RegExp(
        r'(?:MOP|HK|RMB|CNY|USD|EUR|TWD|NTD|JPY|澳門幣|澳门币|人民幣|人民币|港幣|港币|美元|歐元|欧元|台幣|台币|元)\s*\$?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
      // 2) 貨幣單位在數字後，例如「12.00 元」
      RegExp(
        r'(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)\s*(?:元|圓|块|塊|澳門幣|澳门币|人民幣|人民币|港幣|港币|美元|歐元|欧元|台幣|台币)',
      ),
      // 3) 明確的金額欄位，例如「金額 268」「交易金額：MOP 30」
      RegExp(
        r'(?:交易金額|付款金額|消費金額|扣款金額|轉賬金額|金額)\s*[：:]?\s*\$?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)',
      ),
      // 4) 通用貨幣符號
      RegExp(r'[\$¥€£]\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)'),
    ];
    for (final pattern in currencyPatterns) {
      for (final match in pattern.allMatches(text)) {
        final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) return amount;
      }
    }

    // 5) 備選：裸數字（含小數），排除時間/日期/訂單號
    final bareNumber = RegExp(
      r'(?<![\d:./-])(\d{1,3}(?:,\d{3})*\.\d{1,2})(?![\d:./-])',
    );
    for (final match in bareNumber.allMatches(text)) {
      final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
      final amount = double.tryParse(amountStr);
      if (amount != null && amount > 0) return amount;
    }

    // 6) 最後手段：緊跟在交易動詞後的數字（整數也接受），例如「支付 50」
    //
    // ⚠️ 舊版是「支付/成功/MOP 等關鍵字後 40 字內的第一個整數」，範圍過寬，
    //    會把廣告文案裡的價格（例如「海鮮自助晚餐 268起」）當成交易金額。
    final afterVerb = RegExp(
      r'(?:轉賬|轉帳|转账|轉出|轉入|支付|付款|消費|扣款|匯款|汇款)\s*(?:了|給|至|金額)?\s*(?:MOP|HK\$|RMB|CNY|USD|¥|\$)?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)(?!\d)',
      caseSensitive: false,
    );
    for (final match in afterVerb.allMatches(text)) {
      final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
      final amount = double.tryParse(amountStr);
      if (amount != null && amount > 0) return amount;
    }
    return null;
  }

  /// 從通知中提取商家名稱/轉帳對象（支援 給/向/轉給/收到/來自/由 格式）
  static String? extractMerchant(String text) {
    // ✅ 依語意優先順序匹配：
    // 1. 轉出對象（轉賬給/付款給/向 XXX 轉賬）
    // 2. 轉入來源（收到/來自 XXX）
    // 3. 泛用「給 XXX」與「- XXX」
    final patterns = [
      // 轉賬給 XXX / 付款給 XXX / 支付給 XXX
      RegExp(
        r'(?:轉賬|轉帳|转账|转帐|付款|支付|匯款|汇款|畀)\s*給\s*([^\s,，。]+)',
      ),
      // 向 XXX 轉賬 / 向 XXX 付款
      RegExp(
        r'向\s*([^\s,，。]+)\s*(?:轉賬|轉帳|转账|转帐|付款|支付|匯款|汇款)',
      ),
      // 收到 XXX 轉賬 / 來自 XXX 轉賬
      RegExp(
        r'(?:收到|來自|来自)\s*([^\s,，。]+)\s*(?:轉賬|轉帳|转账|转帐|匯款|汇款|的)',
      ),
      // 泛用：給 XXX / 由 XXX 轉賬
      RegExp(r'給\s*([^\s,，。]+)'),
      RegExp(r'由\s*([^\s,，。]+)\s*(?:轉賬|轉帳|轉账|转账|匯款|汇款)'),
      // 最後手段：- XXX
      RegExp(r'-\s*([^\s,，。]+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final name = match.group(1)?.trim();
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return null;
  }

  /// 從通知中提取支付方式
  static String? extractPaymentMethod(String text) {
    final methods = ['支付寶', '微信支付', 'Apple Pay', 'Google Pay', '信用卡', '現金'];
    for (final method in methods) {
      if (text.contains(method)) {
        return method;
      }
    }
    return null;
  }
}

/// AI 分類結果
class AIClassificationResult {
  /// 分類名稱（如：食物、交通、購物等）
  final String category;

  /// 備註內容
  final String note;

  /// 信心指數（0.0 - 1.0）
  final double confidence;

  /// 從通知中提取的金額（可選）
  final double? amount;

  /// 從通知中提取的商家名稱（可選）
  final String? merchant;

  /// 從通知中提取的支付方式（可選）
  final String? paymentMethod;

  AIClassificationResult({
    required this.category,
    required this.note,
    required this.confidence,
    this.amount,
    this.merchant,
    this.paymentMethod,
  });

  /// 從 JSON 建立實例
  factory AIClassificationResult.fromJson(Map<String, dynamic> json) {
    final text = json['text'] as String? ?? json['note'] as String? ?? '';

    return AIClassificationResult(
      category: json['category'] as String? ?? '其他',
      note: text.isNotEmpty
          ? text.substring(0, text.length.clamp(0, 80))
          : '無備註',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      amount: (json['amount'] as num?)?.toDouble(),
      merchant: json['merchant'] as String?,
      paymentMethod: json['payment_method'] as String?,
    );
  }

  /// 從本地分類建立實例
  factory AIClassificationResult.fromLocal({
    required String category,
    required String text,
    double confidence = 0.7,
  }) {
    final cleanedText = text.isNotEmpty
        ? text.substring(0, text.length.clamp(0, 80))
        : '無備註';
    return AIClassificationResult(
      category: category,
      note: cleanedText,
      confidence: confidence,
      amount: AIService.extractAmount(text),
      merchant: AIService.extractMerchant(text),
      paymentMethod: AIService.extractPaymentMethod(text),
    );
  }

  /// 建立備用分類結果
  factory AIClassificationResult.fallback(String text) {
    final result = AIService.localClassify(text);
    return AIClassificationResult(
      category: result.category,
      note: result.note,
      confidence: result.confidence,
      amount: AIService.extractAmount(text),
      merchant: AIService.extractMerchant(text),
      paymentMethod: AIService.extractPaymentMethod(text),
    );
  }

  /// 轉換為 Record 模型
  Record toRecord({double? amountOverride}) {
    final finalAmount = amountOverride ?? amount ?? 0;
    return Record(
      amount: -finalAmount, // 支出為負數
      category: category,
      note: merchant != null ? '$merchant - $note' : note,
      date: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  /// 是否可信（信心指數 >= 0.6）
  bool get isConfident => confidence >= 0.6;

  /// 是否需要用戶確認（信心指數在 0.4 - 0.6 之間）
  bool get needsConfirmation => confidence >= 0.4 && confidence < 0.6;

  /// 是否低可信度（信心指數 < 0.4）
  bool get isLowConfidence => confidence < 0.4;

  @override
  String toString() {
    return 'AIClassificationResult(category: $category, confidence: $confidence, amount: $amount, merchant: $merchant)';
  }
}

/// AI API 設定（由用戶自行填寫）
class AIConfig {
  final String apiUrl;
  final String apiKey;
  final String model;

  const AIConfig({
    required this.apiUrl,
    required this.apiKey,
    required this.model,
  });

  /// 將 API Key 遮蔽顯示（只顯示前 4 碼與後 4 碼）
  String get maskedKey {
    if (apiKey.length <= 8) return '****';
    return '${apiKey.substring(0, 4)}****${apiKey.substring(apiKey.length - 4)}';
  }
}
