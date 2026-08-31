import 'package:flutter/material.dart';

class CategoryItem {
  final String name;
  final IconData icon;
  final Color color;

  const CategoryItem({
    required this.name,
    required this.icon,
    required this.color,
  });
}

class CategoryData {
  // 支出和收入類型
  static const List<String> types = ['支出', '收入'];

  // 預設分類
  static const List<CategoryItem> allCategories = [
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
  ];

  // 根據類別名稱獲取圖標和顏色
  static CategoryItem? getCategory(String name) {
    try {
      return allCategories.firstWhere((item) => item.name == name);
    } catch (e) {
      return null;
    }
  }
}