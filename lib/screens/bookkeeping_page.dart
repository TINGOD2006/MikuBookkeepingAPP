import 'package:flutter/material.dart';

import '../models/record.dart';
import '../constants/app_colors.dart';
import '../constants/categories.dart'; //
import '../services/storage_service.dart';
import '../widgets/month_picker_dialog.dart'; //

class BookkeepingPage extends StatefulWidget {
  const BookkeepingPage({super.key});

  @override
  State<BookkeepingPage> createState() => BookkeepingPageState();
}

class BookkeepingPageState extends State<BookkeepingPage> {
  List<Record> _allRecords = [];
  List<Record> _filteredRecords = [];
  bool _isLoading = true;
  final StorageService _storage = StorageService();

  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      _allRecords = await _storage.loadRecords();
      _applyFilter();
    } catch (e) {
      debugPrint('載入記錄失敗: $e');
      _allRecords = [];
      _filteredRecords = [];
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

    _filteredRecords = _allRecords.where((record) {
      return record.date.isAfter(
            monthStart.subtract(const Duration(days: 1)),
          ) &&
          record.date.isBefore(monthEnd);
    }).toList();
  }

  Future<void> _selectMonth() async {
    final BuildContext currentContext = context;

    if (!currentContext.mounted) {
      return;
    }

    FocusScope.of(currentContext).unfocus();

    final DateTime? picked = await showDialog<DateTime>(
      context: currentContext,
      builder: (context) => MonthPickerDialog(initialDate: _selectedMonth),
    );

    if (!currentContext.mounted) {
      return;
    }

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
        _applyFilter();
      });
    }
  }

  void refreshRecords() {
    _loadRecords();
  }

  Future<void> _deleteRecord(int index) async {
    final recordToDelete = _filteredRecords[index];
    final allIndex = _allRecords.indexOf(recordToDelete);
    if (allIndex != -1) {
      await _storage.deleteRecord(allIndex);
      _allRecords.removeAt(allIndex);
      _applyFilter();
      if (mounted) {
        setState(() {});
      }
    }
  }

  double get _totalExpense {
    return _filteredRecords
        .where((record) => record.amount < 0)
        .fold(0, (sum, record) => sum + record.amount.abs());
  }

  double get _totalIncome {
    return _filteredRecords
        .where((record) => record.amount > 0)
        .fold(0, (sum, record) => sum + record.amount);
  }

  double get _balance {
    return _totalIncome - _totalExpense;
  }

  Map<String, List<Record>> get _groupedRecords {
    final Map<String, List<Record>> groups = {};
    for (final record in _filteredRecords) {
      final key = record.formattedDate;
      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(record);
    }
    return groups;
  }

  double _getDailyTotal(List<Record> records) {
    return records.fold(0, (sum, record) => sum + record.amount);
  }

  double _getDailyExpense(List<Record> records) {
    return records
        .where((record) => record.amount < 0)
        .fold(0, (sum, record) => sum + record.amount.abs());
  }

  double _getDailyIncome(List<Record> records) {
    return records
        .where((record) => record.amount > 0)
        .fold(0, (sum, record) => sum + record.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        color: AppColor.background,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColor.primary),
              )
            : Column(
                children: [
                  _buildMonthAndSummaryCard(),
                  Expanded(
                    child: _filteredRecords.isEmpty
                        ? _buildEmptyState()
                        : _buildRecordList(),
                  ),
                ],
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Miku 記帳',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('设置功能開發中')));
          },
        ),
      ],
    );
  }

  Widget _buildMonthAndSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColor.primary, AppColor.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColor.primary.withValues(alpha: 0.25),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _selectMonth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_selectedMonth.year.toString()}年',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColor.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${_selectedMonth.month.toString().padLeft(2, '0')}月',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColor.text,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: AppColor.text,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 56,
            color: AppColor.text.withValues(alpha: 0.2),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCompactSummaryItem('支出', _totalExpense),
                  Container(
                    width: 1,
                    height: 24,
                    color: AppColor.text.withValues(alpha: 0.15),
                  ),
                  _buildCompactSummaryItem('收入', _totalIncome),
                  Container(
                    width: 1,
                    height: 24,
                    color: AppColor.text.withValues(alpha: 0.15),
                  ),
                  _buildCompactSummaryItem('結餘', _balance),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSummaryItem(String label, double amount) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColor.text,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          amount.toStringAsFixed(0),
          style: const TextStyle(
            color: AppColor.text,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: AppColor.textSecondary),
          const SizedBox(height: 16),
          Text(
            '${_selectedMonth.year.toString()}年${_selectedMonth.month.toString().padLeft(2, '0')}月 尚無記錄',
            style: const TextStyle(fontSize: 18, color: AppColor.text),
          ),
          const SizedBox(height: 8),
          const Text(
            '點擊 ✚ 按鈕新增記錄',
            style: TextStyle(fontSize: 14, color: AppColor.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordList() {
    final dateKeys = _groupedRecords.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: dateKeys.length,
      itemBuilder: (context, dateIndex) {
        final date = dateKeys[dateIndex];
        final records = _groupedRecords[date]!;
        final dailyExpense = _getDailyExpense(records);
        final dailyIncome = _getDailyIncome(records);
        final dailyTotal = _getDailyTotal(records);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(date, dailyExpense, dailyIncome, dailyTotal),
            ..._buildRecordItems(records),
            if (dateIndex < dateKeys.length - 1) _buildDivider(),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(
    String date,
    double dailyExpense,
    double dailyIncome,
    double dailyTotal,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 13,
                color: AppColor.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                date,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColor.text,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColor.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dailyExpense > 0)
                  Text(
                    '⬇ ${dailyExpense.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (dailyExpense > 0 && dailyIncome > 0)
                  const SizedBox(width: 2),
                if (dailyIncome > 0)
                  Text(
                    '⬆ ${dailyIncome.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (dailyExpense > 0 || dailyIncome > 0) ...[
                  const SizedBox(width: 2),
                  Container(width: 1, height: 10, color: Colors.grey[600]),
                  const SizedBox(width: 2),
                ],
                Text(
                  '淨額 ${dailyTotal.abs().toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: dailyTotal < 0
                        ? Colors.redAccent
                        : Colors.greenAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRecordItems(List<Record> records) {
    return records.asMap().entries.map((entry) {
      final localIndex = entry.key;
      final record = entry.value;

      final uniqueKey =
          '${record.date.millisecondsSinceEpoch}_'
          '${record.category}_'
          '${record.amount}_'
          '${record.note}_'
          '${record.createdAt.millisecondsSinceEpoch}_'
          '$localIndex';

      final globalIndex = _filteredRecords.indexOf(record);

      return Dismissible(
        key: Key('dismissible_$uniqueKey'),
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: AppColor.text),
        ),
        onDismissed: (direction) {
          _deleteRecord(globalIndex);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已刪除記錄'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: _buildRecordItem(record),
      );
    }).toList();
  }

  // ========== ✅ 顯示分類圖標 ==========
  Widget _buildRecordItem(Record record) {
    final isExpense = record.amount < 0;
    final displayAmount = record.amount.abs();

    // ✅ 獲取分類的圖標和顏色
    final categoryInfo = CategoryData.getCategory(record.category);
    final icon = categoryInfo?.icon ?? Icons.category;
    final iconColor = categoryInfo?.color ?? AppColor.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColor.cardBackground,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // ✅ 使用分類圖標
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Icon(icon, size: 20, color: iconColor)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      record.category,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColor.background,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColor.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        isExpense ? '支出' : '收入',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColor.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  record.note,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            isExpense
                ? '-${displayAmount.toStringAsFixed(0)}'
                : displayAmount.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColor.background,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(color: Colors.grey[800], thickness: 0.5),
    );
  }
}
