import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/record.dart';

/// AI 分類服務
///
/// 負責將支付通知文字傳送給 AI API 進行分類，
/// 並在 API 不可用時使用本地規則作為備用方案。
class AIService {
  // ========== 配置 ==========

  /// AI API 端點（替換為你的實際端點）
  static const String apiUrl = 'https://api.ofox.ai/v1/chat/completions';

  /// API 金鑰（替換為你的實際金鑰）
  static const String apiKey =
      'sk-of-xSvSxcglZQrvAGbcrxgoIFEFbGtgOVWWnZXybprFXPcNdqjHXfQsRWDBHzHMkQNT';

  /// 請求超時時間
  static const Duration timeout = Duration(seconds: 5);

  /// 最大重試次數
  static const int maxRetries = 2;

  // ========== 主要方法 ==========

  /// 將支付通知文字傳送給 AI 進行分類
  ///
  /// [notificationText] 通知的完整文字內容
  /// [retries] 當前重試次數（內部使用）
  /// Returns [AIClassificationResult] 分類結果
  /// 回傳 [AIClassificationResult] 分類結果
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

    try {
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              // ✅ 在這裡指定模型
              'model': 'google/gemini-3.5-flash-lite',
              'messages': [
                {
                  'role': 'system',
                  'content': '你是記帳分類助手。請根據用戶輸入的支付通知內容，判斷消費類別。類別只能是以下之一：食物、交通、購物、娛樂、醫療、教育、房租、水電、通訊、保險、稅務、捐款、紅包、其他。請以 JSON 格式回覆，包含 category（類別）、note（簡短備註）、confidence（信心指數0-1）。範例回覆：{"category":"食物","note":"午餐消費","confidence":0.95}',
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
        // OpenAI 格式的回應結構
        final content = data['choices'][0]['message']['content'];
        try {
          final result = jsonDecode(content);
          return AIClassificationResult(
            category: result['category'] as String? ?? '其他',
            note: result['note'] as String? ?? notificationText,
            confidence: (result['confidence'] as num?)?.toDouble() ?? 0.5,
          );
        } catch (e) {
          return localClassify(notificationText);
        }
      } else {
        if (kDebugMode) {
          print('AI API 錯誤: ${response.statusCode} - ${response.body}');
        }
        if (retries < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (retries + 1)));
          return await classifyNotification(
            notificationText,
            retries: retries + 1,
          );
        }
        return localClassify(notificationText);
      }
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        print('AI API 網絡錯誤: $e');
      }
      if (retries < maxRetries) {
        await Future.delayed(Duration(milliseconds: 500 * (retries + 1)));
        return classifyNotification(notificationText, retries: retries + 1);
      }
      return localClassify(notificationText);
    } catch (e) {
      if (kDebugMode) {
        print('AI API 錯誤: $e');
      }
      return localClassify(notificationText);
    }
  }

  // ========== 本地備用分類 ==========

  /// 本地備用分類規則
  ///
  /// 當 AI API 不可用時，使用關鍵字匹配進行分類
  static AIClassificationResult localClassify(String text) {
    final lowerText = text.toLowerCase();

    // 定義關鍵詞映射
    final Map<String, List<String>> keywords = {
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
        '麥當勞',
        '肯德基',
        '星巴克',
        '7-11',
        '全家',
        '便利商店',
        '便當',
        '外賣',
        'delivery',
        'eat',
        'meal',
        'cafe',
        'coffee',
        '壽司',
        '拉麵',
        '火鍋',
        '燒肉',
        '牛排',
        'pizza',
        'burger',
        '麥當勞',
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
    };

    // 匹配關鍵詞
    for (final entry in keywords.entries) {
      for (final keyword in entry.value) {
        if (lowerText.contains(keyword)) {
          return AIClassificationResult(
            category: entry.key,
            note: _cleanText(text),
            confidence: 0.7,
          );
        }
      }
    }

    // 預設分類
    return AIClassificationResult(
      category: '其他',
      note: _cleanText(text),
      confidence: 0.3,
    );
  }

  // ========== 輔助方法 ==========

  /// 清理文字（移除多餘空格和特殊字符）
  static String _cleanText(String text) {
    // 移除多餘空格
    String cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    // 移除特殊字符（保留中文、英文、數字）
    cleaned = cleaned.replaceAll(RegExp(r'[^\u4e00-\u9fa5a-zA-Z0-9\s]'), ' ');
    return cleaned.trim();
  }

  /// 從通知中提取金額
  static double? extractAmount(String text) {
    // 支援多種貨幣格式
    final amountRegex = RegExp(
      r'([\$¥€£]?[\d,]+\.?\d*)\s*(元|HKD|NTD|USD|EUR|CNY|點)?',
      caseSensitive: false,
    );
    final match = amountRegex.firstMatch(text);
    if (match == null) return null;

    final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return null;
    return amount;
  }

  /// 從通知中提取商家名稱
  static String? extractMerchant(String text) {
    // 匹配「於 XXX」或「在 XXX」格式
    final merchantRegex = RegExp(r'於\s*([^\s,，。]+)|在\s*([^\s,，。]+)');
    final match = merchantRegex.firstMatch(text);
    if (match != null) {
      return match.group(1) ?? match.group(2);
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
      note: AIService._cleanText(text),
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
    return AIClassificationResult(
      category: category,
      note: AIService._cleanText(text),
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
