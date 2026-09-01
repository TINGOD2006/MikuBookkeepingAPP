import 'package:flutter/material.dart';

class CategoryItem {
  final String name;
  final IconData icon;
  final Color color;
  final bool isCustom; // ✅ 標記是否為自定義分類

  const CategoryItem({
    required this.name,
    required this.icon,
    required this.color,
    this.isCustom = false, // 預設為非自定義
  });

  // ✅ 複製方法（用於修改）
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
  // 類型標籤
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
    CategoryItem(
      name: '交通',
      icon: Icons.directions_car,
      color: Colors.blueGrey,
    ),
    CategoryItem(name: '衣服', icon: Icons.checkroom, color: Colors.deepPurple),
    CategoryItem(name: '汽車', icon: Icons.car_repair, color: Colors.grey),
    CategoryItem(name: '酒', icon: Icons.local_bar, color: Colors.brown),
    CategoryItem(name: '香煙', icon: Icons.smoke_free, color: Colors.grey),
    CategoryItem(name: '電子', icon: Icons.computer, color: Colors.cyan),
    CategoryItem(
      name: '旅行',
      icon: Icons.flight_takeoff,
      color: Colors.lightBlue,
    ),
    CategoryItem(name: '醫療', icon: Icons.local_hospital, color: Colors.red),
    CategoryItem(name: '寵物', icon: Icons.pets, color: Colors.amber),
    CategoryItem(name: '维修', icon: Icons.build, color: Colors.brown),
    CategoryItem(name: '住房', icon: Icons.home, color: Colors.orange),
    CategoryItem(name: '居家', icon: Icons.chair, color: Colors.lime),
    CategoryItem(name: '禮金', icon: Icons.card_giftcard, color: Colors.pink),
    CategoryItem(
      name: '捐款',
      icon: Icons.volunteer_activism,
      color: Colors.redAccent,
    ),
    CategoryItem(
      name: '彩票',
      icon: Icons.confirmation_number,
      color: Colors.green,
    ),
    CategoryItem(name: '零食', icon: Icons.icecream, color: Colors.pink),
    CategoryItem(name: '孩子', icon: Icons.child_care, color: Colors.lightGreen),
    CategoryItem(name: '蔬菜', icon: Icons.agriculture, color: Colors.green),
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
    CategoryItem(
      name: '退稅',
      icon: Icons.receipt_long,
      color: Colors.lightGreen,
    ),
    CategoryItem(name: '保險理賠', icon: Icons.assignment, color: Colors.red),
    CategoryItem(name: '賣出物品', icon: Icons.sell, color: Colors.orange),
    CategoryItem(name: '贈與', icon: Icons.favorite, color: Colors.pink),
    CategoryItem(name: '其他收入', icon: Icons.more_horiz, color: Colors.grey),
  ];

  // ✅ 可變分類列表（支援自定義）
  static List<CategoryItem> _expenseCategories = List.from(
    _defaultExpenseCategories,
  );
  static List<CategoryItem> _incomeCategories = List.from(
    _defaultIncomeCategories,
  );

  // ✅ 獲取分類（返回副本，避免外部修改）
  static List<CategoryItem> getExpenseCategories() {
    return List.from(_expenseCategories);
  }

  static List<CategoryItem> getIncomeCategories() {
    return List.from(_incomeCategories);
  }

  static List<CategoryItem> getCategories(String type) {
    if (type == '支出') {
      return getExpenseCategories();
    } else {
      return getIncomeCategories();
    }
  }

  // ✅ 新增自定義分類
  static void addCustomCategory(
    String type,
    String name, {
    IconData icon = Icons.label,
    Color color = Colors.grey,
  }) {
    final newCategory = CategoryItem(
      name: name,
      icon: icon,
      color: color,
      isCustom: true,
    );

    if (type == '支出') {
      _expenseCategories.add(newCategory);
    } else {
      _incomeCategories.add(newCategory);
    }
  }

  // ✅ 刪除自定義分類（只能刪除自定義的）
  static bool deleteCustomCategory(String type, String name) {
    if (type == '支出') {
      final index = _expenseCategories.indexWhere(
        (item) => item.name == name && item.isCustom,
      );
      if (index != -1) {
        _expenseCategories.removeAt(index);
        return true;
      }
    } else {
      final index = _incomeCategories.indexWhere(
        (item) => item.name == name && item.isCustom,
      );
      if (index != -1) {
        _incomeCategories.removeAt(index);
        return true;
      }
    }
    return false;
  }

  // ✅ 重置為預設分類（刪除所有自定義）
  static void resetToDefault() {
    _expenseCategories = List.from(_defaultExpenseCategories);
    _incomeCategories = List.from(_defaultIncomeCategories);
  }

  // ✅ 根據類別名稱獲取圖標和顏色
  static CategoryItem? getCategory(String name) {
    for (final item in _expenseCategories) {
      if (item.name == name) {
        return item;
      }
    }
    for (final item in _incomeCategories) {
      if (item.name == name) {
        return item;
      }
    }
    return null;
  }
}
