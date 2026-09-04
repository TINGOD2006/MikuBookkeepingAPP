import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CategoryItem {
  final String name;
  final IconData icon;
  final Color color;
  final bool isCustom;

  const CategoryItem({
    required this.name,
    required this.icon,
    required this.color,
    this.isCustom = false,
  });

  // ✅ 轉換為 JSON 儲存（儲存 icon 名稱）
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'iconName': _iconToName(icon), // 將 IconData 轉為名稱
      'colorValue': color.toARGB32(),
      'isCustom': isCustom,
    };
  }

  // ✅ 從 JSON 還原（從名稱獲取 IconData）
  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    final iconName = json['iconName'] as String? ?? 'label';
    final icon = _nameToIcon(iconName);
    
    return CategoryItem(
      name: json['name'] as String,
      icon: icon,
      color: Color(json['colorValue'] as int),
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  // ✅ 將 IconData 轉為名稱
  static String _iconToName(IconData icon) {
    // 使用 icon.codePoint 作為識別，但更方便的是用名稱映射
    final iconMap = {
      Icons.label: 'label',
      Icons.star: 'star',
      Icons.favorite: 'favorite',
      Icons.heart_broken: 'heart_broken',
      Icons.emoji_emotions: 'emoji_emotions',
      Icons.emoji_objects: 'emoji_objects',
      Icons.emoji_nature: 'emoji_nature',
      Icons.emoji_food_beverage: 'emoji_food_beverage',
      Icons.emoji_transportation: 'emoji_transportation',
      Icons.emoji_symbols: 'emoji_symbols',
      Icons.emoji_flags: 'emoji_flags',
      Icons.bolt: 'bolt',
      Icons.fireplace: 'fireplace',
      Icons.water_drop: 'water_drop',
      Icons.cloud: 'cloud',
      Icons.wb_sunny: 'wb_sunny',
      Icons.nightlight: 'nightlight',
      Icons.music_note: 'music_note',
      Icons.movie: 'movie',
      Icons.book: 'book',
      Icons.school: 'school',
      Icons.work: 'work',
      Icons.home: 'home',
      Icons.shopping_cart: 'shopping_cart',
      Icons.restaurant: 'restaurant',
      Icons.directions_car: 'directions_car',
      Icons.flight: 'flight',
      Icons.health_and_safety: 'health_and_safety',
      Icons.fitness_center: 'fitness_center',
      Icons.spa: 'spa',
      Icons.pets: 'pets',
      Icons.shopping_bag: 'shopping_bag',
      Icons.phone_android: 'phone_android',
      Icons.checkroom: 'checkroom',
      Icons.car_repair: 'car_repair',
      Icons.local_bar: 'local_bar',
      Icons.smoke_free: 'smoke_free',
      Icons.computer: 'computer',
      Icons.flight_takeoff: 'flight_takeoff',
      Icons.local_hospital: 'local_hospital',
      Icons.build: 'build',
      Icons.chair: 'chair',
      Icons.card_giftcard: 'card_giftcard',
      Icons.volunteer_activism: 'volunteer_activism',
      Icons.confirmation_number: 'confirmation_number',
      Icons.icecream: 'icecream',
      Icons.child_care: 'child_care',
      Icons.agriculture: 'agriculture',
      Icons.payments: 'payments',
      Icons.emoji_events: 'emoji_events',
      Icons.trending_up: 'trending_up',
      Icons.home_work: 'home_work',
      Icons.work_outline: 'work_outline',
      Icons.edit_note: 'edit_note',
      Icons.account_balance: 'account_balance',
      Icons.savings: 'savings',
      Icons.receipt_long: 'receipt_long',
      Icons.assignment: 'assignment',
      Icons.sell: 'sell',
      Icons.more_horiz: 'more_horiz',
    };
    
    return iconMap[icon] ?? 'label';
  }

  // ✅ 從名稱獲取 IconData
  static IconData _nameToIcon(String name) {
    final iconMap = {
      'label': Icons.label,
      'star': Icons.star,
      'favorite': Icons.favorite,
      'heart_broken': Icons.heart_broken,
      'emoji_emotions': Icons.emoji_emotions,
      'emoji_objects': Icons.emoji_objects,
      'emoji_nature': Icons.emoji_nature,
      'emoji_food_beverage': Icons.emoji_food_beverage,
      'emoji_transportation': Icons.emoji_transportation,
      'emoji_symbols': Icons.emoji_symbols,
      'emoji_flags': Icons.emoji_flags,
      'bolt': Icons.bolt,
      'fireplace': Icons.fireplace,
      'water_drop': Icons.water_drop,
      'cloud': Icons.cloud,
      'wb_sunny': Icons.wb_sunny,
      'nightlight': Icons.nightlight,
      'music_note': Icons.music_note,
      'movie': Icons.movie,
      'book': Icons.book,
      'school': Icons.school,
      'work': Icons.work,
      'home': Icons.home,
      'shopping_cart': Icons.shopping_cart,
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'flight': Icons.flight,
      'health_and_safety': Icons.health_and_safety,
      'fitness_center': Icons.fitness_center,
      'spa': Icons.spa,
      'pets': Icons.pets,
      'shopping_bag': Icons.shopping_bag,
      'phone_android': Icons.phone_android,
      'checkroom': Icons.checkroom,
      'car_repair': Icons.car_repair,
      'local_bar': Icons.local_bar,
      'smoke_free': Icons.smoke_free,
      'computer': Icons.computer,
      'flight_takeoff': Icons.flight_takeoff,
      'local_hospital': Icons.local_hospital,
      'build': Icons.build,
      'chair': Icons.chair,
      'card_giftcard': Icons.card_giftcard,
      'volunteer_activism': Icons.volunteer_activism,
      'confirmation_number': Icons.confirmation_number,
      'icecream': Icons.icecream,
      'child_care': Icons.child_care,
      'agriculture': Icons.agriculture,
      'payments': Icons.payments,
      'emoji_events': Icons.emoji_events,
      'trending_up': Icons.trending_up,
      'home_work': Icons.home_work,
      'work_outline': Icons.work_outline,
      'edit_note': Icons.edit_note,
      'account_balance': Icons.account_balance,
      'savings': Icons.savings,
      'receipt_long': Icons.receipt_long,
      'assignment': Icons.assignment,
      'sell': Icons.sell,
      'more_horiz': Icons.more_horiz,
    };
    
    return iconMap[name] ?? Icons.label;
  }

  CategoryItem copyWith({
    String? name,
    IconData? icon,
    Color? color,
    bool? isCustom,
  }) {
    return CategoryItem(
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}

class CategoryData {
  static const String _expenseKey = 'custom_expense_categories';
  static const String _incomeKey = 'custom_income_categories';

  static const List<String> types = ['支出', '收入'];

  // ========== 預設支出分類 ==========
  static const List<CategoryItem> _defaultExpenseCategories = [
    CategoryItem(name: '學費', icon: Icons.school, color: Colors.blue),
    CategoryItem(name: '購物', icon: Icons.shopping_bag, color: Colors.purple),
    CategoryItem(name: '食物', icon: Icons.restaurant, color: Colors.orange),
    CategoryItem(name: '手機', icon: Icons.phone_android, color: Colors.teal),
    CategoryItem(name: '娛樂', icon: Icons.movie, color: Colors.pink),
    CategoryItem(name: '教育', icon: Icons.menu_book, color: Colors.indigo),
    CategoryItem(name: '美容', icon: Icons.spa, color: Colors.pinkAccent),
    CategoryItem(name: '運動', icon: Icons.fitness_center, color: Colors.green),
    CategoryItem(name: '社交', icon: Icons.people, color: Colors.cyan),
    CategoryItem(name: '交通', icon: Icons.directions_car, color: Colors.blueGrey),
    CategoryItem(name: '衣服', icon: Icons.checkroom, color: Colors.deepPurple),
    CategoryItem(name: '汽車', icon: Icons.car_repair, color: Colors.grey),
    CategoryItem(name: '酒', icon: Icons.local_bar, color: Colors.brown),
    CategoryItem(name: '香煙', icon: Icons.smoke_free, color: Colors.grey),
    CategoryItem(name: '電子', icon: Icons.computer, color: Colors.cyan),
    CategoryItem(name: '旅行', icon: Icons.flight_takeoff, color: Colors.lightBlue),
    CategoryItem(name: '醫療', icon: Icons.local_hospital, color: Colors.red),
    CategoryItem(name: '寵物', icon: Icons.pets, color: Colors.amber),
    CategoryItem(name: '维修', icon: Icons.build, color: Colors.brown),
    CategoryItem(name: '住房', icon: Icons.home, color: Colors.orange),
    CategoryItem(name: '居家', icon: Icons.chair, color: Colors.lime),
    CategoryItem(name: '禮金', icon: Icons.card_giftcard, color: Colors.pink),
    CategoryItem(name: '捐款', icon: Icons.volunteer_activism, color: Colors.redAccent),
    CategoryItem(name: '彩票', icon: Icons.confirmation_number, color: Colors.green),
    CategoryItem(name: '零食', icon: Icons.icecream, color: Colors.pink),
    CategoryItem(name: '孩子', icon: Icons.child_care, color: Colors.lightGreen),
    CategoryItem(name: '蔬菜', icon: Icons.agriculture, color: Colors.green),
    CategoryItem(name: '轉帳', icon: Icons.swap_horiz, color: Colors.blue),
  ];

  // ========== 預設收入分類 ==========
  static const List<CategoryItem> _defaultIncomeCategories = [
    CategoryItem(name: '薪水', icon: Icons.payments, color: Colors.green),
    CategoryItem(name: '獎金', icon: Icons.emoji_events, color: Colors.amber),
    CategoryItem(name: '禮金', icon: Icons.card_giftcard, color: Colors.pink),
    CategoryItem(name: '福利', icon: Icons.health_and_safety, color: Colors.teal),
    CategoryItem(name: '投資收益', icon: Icons.trending_up, color: Colors.green),
    CategoryItem(name: '租金收入', icon: Icons.home_work, color: Colors.orange),
    CategoryItem(name: '兼職', icon: Icons.work_outline, color: Colors.blue),
    CategoryItem(name: '稿費', icon: Icons.edit_note, color: Colors.purple),
    CategoryItem(name: '股息', icon: Icons.account_balance, color: Colors.indigo),
    CategoryItem(name: '利息', icon: Icons.savings, color: Colors.cyan),
    CategoryItem(name: '退稅', icon: Icons.receipt_long, color: Colors.lightGreen),
    CategoryItem(name: '保險理賠', icon: Icons.assignment, color: Colors.red),
    CategoryItem(name: '賣出物品', icon: Icons.sell, color: Colors.orange),
    CategoryItem(name: '贈與', icon: Icons.favorite, color: Colors.pink),
    CategoryItem(name: '其他收入', icon: Icons.more_horiz, color: Colors.grey),
  ];

  // ========== 快取 ==========
  static List<CategoryItem>? _cachedExpenseCategories;
  static List<CategoryItem>? _cachedIncomeCategories;

  // ========== 從 SharedPreferences 載入自定義分類 ==========
  static Future<void> _loadCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();

    final expenseJson = prefs.getStringList(_expenseKey);
    if (expenseJson != null && expenseJson.isNotEmpty) {
      try {
        final customExpenses = expenseJson
            .map((json) => CategoryItem.fromJson(jsonDecode(json) as Map<String, dynamic>))
            .toList();
        _cachedExpenseCategories = [
          ..._defaultExpenseCategories,
          ...customExpenses,
        ];
      } catch (e) {
        _cachedExpenseCategories = List.from(_defaultExpenseCategories);
      }
    } else {
      _cachedExpenseCategories = List.from(_defaultExpenseCategories);
    }

    final incomeJson = prefs.getStringList(_incomeKey);
    if (incomeJson != null && incomeJson.isNotEmpty) {
      try {
        final customIncomes = incomeJson
            .map((json) => CategoryItem.fromJson(jsonDecode(json) as Map<String, dynamic>))
            .toList();
        _cachedIncomeCategories = [
          ..._defaultIncomeCategories,
          ...customIncomes,
        ];
      } catch (e) {
        _cachedIncomeCategories = List.from(_defaultIncomeCategories);
      }
    } else {
      _cachedIncomeCategories = List.from(_defaultIncomeCategories);
    }
  }

  // ========== 確保快取已載入 ==========
  static Future<void> _ensureLoaded() async {
    if (_cachedExpenseCategories == null || _cachedIncomeCategories == null) {
      await _loadCustomCategories();
    }
  }

  // ========== 獲取分類 ==========
  static Future<List<CategoryItem>> getExpenseCategoriesAsync() async {
    await _ensureLoaded();
    return List.from(_cachedExpenseCategories!);
  }

  static Future<List<CategoryItem>> getIncomeCategoriesAsync() async {
    await _ensureLoaded();
    return List.from(_cachedIncomeCategories!);
  }

  static List<CategoryItem> getExpenseCategories() {
    if (_cachedExpenseCategories == null) {
      return List.from(_defaultExpenseCategories);
    }
    return List.from(_cachedExpenseCategories!);
  }

  static List<CategoryItem> getIncomeCategories() {
    if (_cachedIncomeCategories == null) {
      return List.from(_defaultIncomeCategories);
    }
    return List.from(_cachedIncomeCategories!);
  }

  static List<CategoryItem> getCategories(String type) {
    if (type == '支出') {
      return getExpenseCategories();
    } else {
      return getIncomeCategories();
    }
  }

  // ========== 初始化 ==========
  static Future<void> init() async {
    await _loadCustomCategories();
  }

  // ========== 新增自定義分類 ==========
  static Future<void> addCustomCategory(String type, String name, {IconData icon = Icons.label, Color color = Colors.grey}) async {
    final prefs = await SharedPreferences.getInstance();
    final newCategory = CategoryItem(
      name: name,
      icon: icon,
      color: color,
      isCustom: true,
    );

    if (type == '支出') {
      _cachedExpenseCategories ??= List.from(_defaultExpenseCategories);
      _cachedExpenseCategories!.add(newCategory);

      final customItems = _cachedExpenseCategories!
          .where((item) => item.isCustom)
          .map((item) => jsonEncode(item.toJson()))
          .toList();
      await prefs.setStringList(_expenseKey, customItems);
    } else {
      _cachedIncomeCategories ??= List.from(_defaultIncomeCategories);
      _cachedIncomeCategories!.add(newCategory);

      final customItems = _cachedIncomeCategories!
          .where((item) => item.isCustom)
          .map((item) => jsonEncode(item.toJson()))
          .toList();
      await prefs.setStringList(_incomeKey, customItems);
    }
  }

  // ========== 刪除自定義分類 ==========
  static Future<bool> deleteCustomCategory(String type, String name) async {
    final prefs = await SharedPreferences.getInstance();

    if (type == '支出') {
      if (_cachedExpenseCategories == null) return false;
      final index = _cachedExpenseCategories!.indexWhere(
        (item) => item.name == name && item.isCustom,
      );
      if (index != -1) {
        _cachedExpenseCategories!.removeAt(index);

        final customItems = _cachedExpenseCategories!
            .where((item) => item.isCustom)
            .map((item) => jsonEncode(item.toJson()))
            .toList();
        await prefs.setStringList(_expenseKey, customItems);
        return true;
      }
    } else {
      if (_cachedIncomeCategories == null) return false;
      final index = _cachedIncomeCategories!.indexWhere(
        (item) => item.name == name && item.isCustom,
      );
      if (index != -1) {
        _cachedIncomeCategories!.removeAt(index);

        final customItems = _cachedIncomeCategories!
            .where((item) => item.isCustom)
            .map((item) => jsonEncode(item.toJson()))
            .toList();
        await prefs.setStringList(_incomeKey, customItems);
        return true;
      }
    }
    return false;
  }

  // ========== 重置為預設分類 ==========
  static Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedExpenseCategories = List.from(_defaultExpenseCategories);
    _cachedIncomeCategories = List.from(_defaultIncomeCategories);
    await prefs.remove(_expenseKey);
    await prefs.remove(_incomeKey);
  }

  // ========== 根據類別名稱獲取圖標和顏色 ==========
  static CategoryItem? getCategory(String name) {
    final allCategories = [
      ...?_cachedExpenseCategories,
      ...?_cachedIncomeCategories,
    ];
    for (final item in allCategories) {
      if (item.name == name) {
        return item;
      }
    }
    return null;
  }
}