import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/categories.dart';
import '../models/record.dart';
import 'add_category_dialog.dart';

class AddRecordDialog extends StatefulWidget {
  final Function(Record) onSave;

  const AddRecordDialog({super.key, required this.onSave});

  @override
  State<AddRecordDialog> createState() => _AddRecordDialogState();
}

class _AddRecordDialogState extends State<AddRecordDialog> {
  String _amount = '0';
  String _note = '';
  String _selectedType = '支出';
  String _selectedCategory = '';
  bool _showInputArea = false;
  bool _isLoading = false;

  DateTime _selectedDate = DateTime.now();

  static const List<String> _numberKeys = [
    '7', '8', '9',
    '4', '5', '6',
    '1', '2', '3',
    '清空', '0', '⌫',
  ];

  List<CategoryItem> _getCategoriesByType(String type) {
    return CategoryData.getCategories(type);
  }

  List<CategoryItem> get _currentCategories {
    return _getCategoriesByType(_selectedType);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            _dismissKeyboard();
          },
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              _buildHeader(),
              _buildTypeTabs(),
              const SizedBox(height: 8),
              Expanded(child: _buildCategoryGrid()),
              if (_showInputArea) ...[_buildInputArea()],
            ],
          ),
        ),
      ),
    );
  }

  // ========== 選擇日期 ==========
Future<void> _selectDate() async {
  final BuildContext currentContext = context;

  if (!currentContext.mounted) {
    return;
  }

  FocusScope.of(currentContext).unfocus();
  final DateTime now = DateTime.now();
  final DateTime firstDate = DateTime(2020, 1);
  final DateTime lastDate = DateTime(now.year + 10, 12, 31);

  final DateTime? picked = await showDatePicker(
    context: currentContext,
    initialDate: _selectedDate,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: (context, child) {
      return Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColor.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      );
    },
  );

  if (!currentContext.mounted) {
    return;
  }

  if (picked != null) {
    setState(() {
      _selectedDate = picked;
    });
  }
}

  void _dismissKeyboard() {
    if (_showInputArea) {
      FocusScope.of(context).unfocus();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _showInputArea = false;
          });
        }
      });
    }
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const Spacer(),
          const Text(
            '記帳',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColor.text,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 0),
            child: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.close, color: AppColor.text, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: CategoryData.types.map((type) {
            final isSelected = _selectedType == type;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedType = type;
                    _selectedCategory = '';
                    _showInputArea = false;
                    _amount = '0';
                  });
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColor.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? AppColor.text : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final categories = _currentCategories;
    final totalItems = categories.length + 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GridView.builder(
        key: ValueKey('category_grid_${_selectedType}_$_selectedCategory'),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.9,
          crossAxisSpacing: 4,
          mainAxisSpacing: 2,
        ),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          if (index == categories.length) {
            return _buildAddCategoryButton();
          }
          final category = categories[index];
          final isSelected = _selectedCategory == category.name;
          return _buildCategoryItem(category, isSelected);
        },
      ),
    );
  }

  Widget _buildAddCategoryButton() {
    return GestureDetector(
      onTap: () async {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AddCategoryDialog(
            type: _selectedType,
          ),
        );
        if (result == true) {
          setState(() {});
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
              border: Border.all(color: Colors.grey[600]!, width: 2),
            ),
            child: const Icon(
              Icons.add,
              size: 28,
              color: AppColor.text,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '新增',
            style: TextStyle(
              fontSize: 10,
              color: AppColor.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(CategoryItem category, bool isSelected) {
    return GestureDetector(
      key: ValueKey('category_item_${category.name}'),
      onTap: () {
        setState(() {
          _selectedCategory = category.name;
          _showInputArea = true;
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppColor.primary : Colors.grey[800],
              border: isSelected
                  ? Border.all(color: AppColor.primary, width: 2)
                  : null,
            ),
            child: Icon(
              category.icon,
              size: 22,
              color: isSelected ? AppColor.text : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? AppColor.text : Colors.grey[400],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (category.isCustom) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.edit,
                  size: 8,
                  color: isSelected ? AppColor.text : Colors.grey[400],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ========== ✅ 輸入區域（備註 + 日期選擇器在同一行） ==========
  Widget _buildInputArea() {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(_getCategoryIcon(), color: AppColor.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _selectedCategory,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColor.text,
                    ),
                  ),
                ],
              ),
              Text(
                _formatAmount(_amount),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColor.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // ✅ 備註 + 日期選擇器在同一行
          Row(
            children: [
              const Icon(Icons.note_add, color: Colors.grey, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _note = value;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: '備註 (選填)',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 2),
                  ),
                  style: const TextStyle(color: AppColor.text, fontSize: 13),
                ),
              ),
              // ✅ 日期選擇器（在最右邊）
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColor.text,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_selectedDate.month}/${_selectedDate.day}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColor.text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: AppColor.text,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildNumberPad(),
          const SizedBox(height: 4),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        Row(
          children: _numberKeys.sublist(0, 3).map((key) {
            return _buildKeyButton(key);
          }).toList(),
        ),
        const SizedBox(height: 4),
        Row(
          children: _numberKeys.sublist(3, 6).map((key) {
            return _buildKeyButton(key);
          }).toList(),
        ),
        const SizedBox(height: 4),
        Row(
          children: _numberKeys.sublist(6, 9).map((key) {
            return _buildKeyButton(key);
          }).toList(),
        ),
        const SizedBox(height: 4),
        Row(
          children: _numberKeys.sublist(9, 12).map((key) {
            return _buildKeyButton(key);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildKeyButton(String key) {
    bool isSpecial = key == '清空' || key == '⌫';

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: () {
            _onKeyPressed(key);
          },
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: isSpecial ? Colors.grey[700] : Colors.grey[800],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                key,
                style: TextStyle(
                  fontSize: isSpecial ? 12 : 18,
                  fontWeight: FontWeight.w600,
                  color: isSpecial ? Colors.orangeAccent : AppColor.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onKeyPressed(String key) {
    setState(() {
      if (key == '清空') {
        _amount = '0';
      } else if (key == '⌫') {
        if (_amount.length > 1) {
          _amount = _amount.substring(0, _amount.length - 1);
        } else {
          _amount = '0';
        }
      } else {
        if (_amount == '0') {
          _amount = key;
        } else {
          if (_amount.length < 10) {
            _amount += key;
          }
        }
      }
    });
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveRecord,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColor.primary,
          foregroundColor: AppColor.text,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColor.text,
                ),
              )
            : const Text(
                '保存記帳',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  IconData _getCategoryIcon() {
    final category = CategoryData.getCategory(_selectedCategory);
    return category?.icon ?? Icons.category;
  }

  String _formatAmount(String amount) {
    if (amount.isEmpty) return '0';
    final num = int.parse(amount);
    return num.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Future<void> _saveRecord() async {
    final BuildContext currentContext = context;

    if (!currentContext.mounted) {
      return;
    }

    if (_selectedCategory.isEmpty) {
      _showSnackBar(currentContext, '請選擇分類！', Colors.red);
      return;
    }

    final amount = double.tryParse(_amount) ?? 0;
    if (amount <= 0) {
      _showSnackBar(currentContext, '請輸入有效金額！', Colors.red);
      return;
    }

    final finalAmount = _selectedType == '支出' ? -amount : amount;

    final record = Record(
      amount: finalAmount,
      category: _selectedCategory,
      note: _note.isEmpty ? '' : _note,
      date: _selectedDate,
      createdAt: DateTime.now(),
    );

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onSave(record);

      if (!currentContext.mounted) {
        return;
      }

      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
          content: Text('記帳成功 ✅'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));

      if (currentContext.mounted) {
        Navigator.pop(currentContext);
      }
    } catch (e) {
      if (!currentContext.mounted) {
        return;
      }
      _showSnackBar(currentContext, '儲存失敗: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
      ),
    );
  }
}