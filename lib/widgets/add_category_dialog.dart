import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/categories.dart';

class AddCategoryDialog extends StatefulWidget {
  final String type; // '支出' 或 '收入'

  const AddCategoryDialog({super.key, required this.type});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final TextEditingController _nameController = TextEditingController();
  Color _selectedColor = Colors.grey;
  IconData _selectedIcon = Icons.label;

  // ✅ 預設顏色選項
  final List<Color> _colorOptions = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  // ✅ 預設圖標選項
  final List<IconData> _iconOptions = [
    Icons.label,
    Icons.star,
    Icons.favorite,
    Icons.heart_broken,
    Icons.emoji_emotions,
    Icons.emoji_objects,
    Icons.emoji_nature,
    Icons.emoji_food_beverage,
    Icons.emoji_transportation,
    Icons.emoji_symbols,
    Icons.emoji_flags,
    Icons.bolt,
    Icons.fireplace,
    Icons.water_drop,
    Icons.cloud,
    Icons.wb_sunny,
    Icons.nightlight,
    Icons.music_note,
    Icons.movie,
    Icons.book,
    Icons.school,
    Icons.work,
    Icons.home,
    Icons.shopping_cart,
    Icons.restaurant,
    Icons.directions_car,
    Icons.flight,
    Icons.health_and_safety,
    Icons.fitness_center,
    Icons.spa,
    Icons.pets,
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColor.background,
      title: Text(
        '新增自定義分類 (${widget.type})',
        style: const TextStyle(color: AppColor.text),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 名稱輸入
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppColor.text),
              decoration: InputDecoration(
                hintText: '請輸入分類名稱',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColor.primary),
                ),
                prefixIcon: Icon(_selectedIcon, color: _selectedColor),
              ),
            ),
            const SizedBox(height: 16),
            // 顏色選擇
            const Text(
              '選擇顏色',
              style: TextStyle(color: AppColor.text, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorOptions.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: AppColor.text, width: 2)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // 圖標選擇
            const Text(
              '選擇圖標',
              style: TextStyle(color: AppColor.text, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _iconOptions.map((icon) {
                final isSelected = _selectedIcon == icon;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = icon;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColor.primary : Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: AppColor.text, width: 1)
                          : null,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? AppColor.text : Colors.grey[400],
                      size: 24,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('取消', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            _saveCategory();
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColor.primary),
          child: const Text('新增'),
        ),
      ],
    );
  }

  void _saveCategory() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請輸入分類名稱！'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ 檢查是否已存在同名分類
    final existingCategories = CategoryData.getCategories(widget.type);
    for (final category in existingCategories) {
      if (category.name == name) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('該分類已存在！'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // ✅ 新增分類
    CategoryData.addCustomCategory(
      widget.type,
      name,
      icon: _selectedIcon,
      color: _selectedColor,
    );

    Navigator.pop(context, true); // 返回 true 表示新增成功
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
