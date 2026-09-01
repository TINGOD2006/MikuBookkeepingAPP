import 'package:flutter/material.dart';
import '../models/record.dart';
import '../constants/app_colors.dart';
import '../services/storage_service.dart';
import '../widgets/summary_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  List<Record> _allRecords = []; // ✅ 所有記錄（不篩選）
  List<Record> _filteredRecords = []; // ✅ 篩選後的記錄
  bool _isLoading = true;
  final StorageService _storage = StorageService();

  // ✅ 篩選日期（null 表示顯示全部）
  DateTime? _filterDate;

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
      _applyFilter(); // ✅ 套用篩選
    } catch (e) {
      debugPrint('載入記錄失敗: $e');
      _allRecords = [];
      _filteredRecords = [];
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ✅ 套用日期篩選
  void _applyFilter() {
    if (_filterDate == null) {
      _filteredRecords = List.from(_allRecords);
    } else {
      final filterStr = _formatDate(_filterDate!);
      _filteredRecords = _allRecords
          .where((record) => record.formattedDate == filterStr)
          .toList();
    }
  }

  // ✅ 格式化日期為 yyyy/mm/dd
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  // ✅ 顯示日期選擇器
// ========== 顯示日期選擇器 ==========
Future<void> _pickDate() async {
  final BuildContext currentContext = context;
  
  if (!currentContext.mounted) {
    return;
  }

  FocusScope.of(currentContext).unfocus();
  
  await Future.delayed(const Duration(milliseconds: 100));

  if (!currentContext.mounted) {
    return;
  }

  final DateTime? picked = await showDatePicker(
    context: currentContext,
    initialDate: _filterDate ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
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
      if (_filterDate != null && _formatDate(picked) == _formatDate(_filterDate!)) {
        _filterDate = null;
      } else {
        _filterDate = picked;
      }
      _applyFilter();
    });
  }
}

// ========== 清除篩選 ==========
void _clearFilter() {
  if (!mounted) {
    return;
  }
  
  FocusScope.of(context).unfocus();
  
  setState(() {
    _filterDate = null;
    _applyFilter();
  });
}

  void refreshRecords() {
    _loadRecords();
  }

  Future<void> _deleteRecord(int index) async {
    // 從全部記錄中刪除
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

  // ========== 統計數據（基於篩選後的記錄） ==========
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
                child: CircularProgressIndicator(
                  color: AppColor.primary,
                ),
              )
            : Column(
                children: [
                  _buildSummaryCard(),
                  // 顯示當前篩選狀態
                  if (_filterDate != null) _buildFilterChip(),
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

 // ========== 自定義 AppBar（日期按鈕在最左邊 - 簡潔版） ==========
PreferredSizeWidget _buildAppBar() {
  return AppBar(
    leading: IconButton(
      icon: const Icon(Icons.calendar_today, color: AppColor.text),
      onPressed: _pickDate,
      tooltip: _filterDate == null ? '選擇日期' : '篩選: ${_formatDate(_filterDate!)}',
    ),
    title: const Text(
      'Miku 記帳',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    centerTitle: true,
    actions: [
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('设置功能開發中')),
          );
        },
      ),
    ],
  );
}

  // ========== 篩選狀態標籤 ==========
  Widget _buildFilterChip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColor.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.filter_alt,
                  size: 14,
                  color: AppColor.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '篩選: ${_formatDate(_filterDate!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColor.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${_filteredRecords.length} 筆)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColor.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _clearFilter,
            child: const Text(
              '清除篩選',
              style: TextStyle(
                fontSize: 12,
                color: AppColor.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildSummaryCard() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    margin: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColor.primary, AppColor.secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: AppColor.primary.withValues(alpha: 0.3),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: SummaryItem(
            label: '支出',
            amount: _totalExpense,
            color: AppColor.text,
          ),
        ),
        Container(
          width: 1,
          height: 30,
          color: AppColor.text.withValues(alpha: 0.2),
        ),
        Expanded(
          child: SummaryItem(
            label: '收入',
            amount: _totalIncome,
            color: AppColor.text,
          ),
        ),
        Container(
          width: 1,
          height: 30,
          color: AppColor.text.withValues(alpha: 0.2),
        ),
        Expanded(
          child: SummaryItem(
            label: '結餘',
            amount: _balance,
            color: AppColor.text,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildEmptyState() {
    String message = '尚無記帳記錄';
    String subMessage = '點擊 ✚ 按鈕新增記錄';
    if (_filterDate != null) {
      message = '${_formatDate(_filterDate!)} 尚無記錄';
      subMessage = '點擊日期按鈕查看全部';
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _filterDate == null ? Icons.inbox : Icons.calendar_today,
            size: 64,
            color: AppColor.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              color: AppColor.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subMessage,
            style: const TextStyle(
              fontSize: 14,
              color: AppColor.textSecondary,
            ),
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

  Widget _buildDateHeader(String date, double dailyExpense, double dailyIncome, double dailyTotal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 12,
                color: AppColor.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                date,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColor.text,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColor.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                if (dailyExpense > 0)
                  Text(
                    '⬇ \$${dailyExpense.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColor.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (dailyExpense > 0 && dailyIncome > 0)
                  const SizedBox(width: 4),
                if (dailyIncome > 0)
                  Text(
                    '⬆ \$${dailyIncome.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColor.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (dailyExpense > 0 || dailyIncome > 0)
                  const SizedBox(width: 3),
                Text(
                  '淨額 \$${dailyTotal.abs().toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColor.text,
                    fontWeight: FontWeight.w600,
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

      final uniqueKey = '${record.date.millisecondsSinceEpoch}_'
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

  Widget _buildRecordItem(Record record) {
    final isExpense = record.amount < 0;
    final displayAmount = record.amount.abs();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColor.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColor.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                record.category.isNotEmpty ? record.category[0] : '?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColor.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      record.category,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColor.background,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColor.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isExpense ? '支出' : '收入',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColor.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        record.formattedTime,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  record.note,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isExpense
                    ? '-\$${displayAmount.toStringAsFixed(0)}'
                    : '\$${displayAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColor.background,
                ),
              ),
              if (record.createdAt.day != record.date.day)
                Text(
                  '建立: ${record.formattedTime}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[400],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        color: Colors.grey[800],
        thickness: 1,
      ),
    );
  }
}