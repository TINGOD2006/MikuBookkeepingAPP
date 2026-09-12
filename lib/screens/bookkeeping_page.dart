import 'dart:async';

import 'package:flutter/material.dart';

import '../models/record.dart';
import '../constants/app_colors.dart';
import '../constants/categories.dart';
import '../services/storage_service.dart';
import '../services/message_service.dart';
import '../services/notification_listener.dart';
import '../utils/amount_formatter.dart';
import '../widgets/month_picker_dialog.dart';

class BookkeepingPage extends StatefulWidget {
  const BookkeepingPage({super.key});

  @override
  State<BookkeepingPage> createState() => BookkeepingPageState();
}

class BookkeepingPageState extends State<BookkeepingPage>
    with WidgetsBindingObserver {
  List<Record> _allRecords = [];
  List<Record> _filteredRecords = [];
  bool _isLoading = true;
  final StorageService _storage = StorageService();

  /// ✅ 自動記帳事件訂閱：通知一到就讓明細頁跟著更新
  StreamSubscription<PaymentNotification>? _paymentSubscription;

  DateTime _selectedMonth = DateTime.now();

  // ✅ 搜尋相關
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ✅ 自動記錄完成後立即重新載入，避免「通知說已記錄、明細頁卻看不到」
    _paymentSubscription = NotificationListenerService.paymentStream.listen(
      _onPaymentRecorded,
    );
    _loadRecords();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paymentSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// ✅ App 回到前景時重新載入：App 未執行期間由原生端保存的記錄，
  ///    會在下次載入時匯入明細。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRecords(showLoading: false);
    }
  }

  /// ✅ 自動記錄事件 → 重新載入清單並提示使用者
  void _onPaymentRecorded(PaymentNotification event) {
    if (!mounted) return;
    _loadRecords(showLoading: false);

    final record = event.record;
    final sign = record.amount < 0 ? '-' : '+';
    MessageService.showSnackBar(
      '✅ 已自動記錄：${record.category} $sign${AmountFormatter.format(record.amount.abs())}',
      key: 'auto_record_${record.id}',
      color: Colors.green,
    );
  }

  Future<void> _loadRecords({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() => _isLoading = true);
    }

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

  // ========== 套用月份和搜尋篩選 ==========
  void _applyFilter() {
    // 1. 按月份過濾
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

    List<Record> monthRecords = _allRecords.where((record) {
      return record.date.isAfter(
            monthStart.subtract(const Duration(days: 1)),
          ) &&
          record.date.isBefore(monthEnd);
    }).toList();

    // 2. 如果有搜尋關鍵字，再按搜尋過濾
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      _filteredRecords = monthRecords.where((record) {
        final categoryMatch = record.category.toLowerCase().contains(query);
        final noteMatch = record.note.toLowerCase().contains(query);
        return categoryMatch || noteMatch;
      }).toList();
    } else {
      _filteredRecords = monthRecords;
    }
  }

  // ========== 切換搜尋模式 ==========
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _searchController.clear();
        _applyFilter();
        _searchFocusNode.unfocus();
      } else {
        // 延遲聚焦，讓動畫完成
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      }
    });
  }

  // ========== 清除搜尋 ==========
  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _applyFilter();
      _searchFocusNode.unfocus();
    });
  }

  // ========== 執行搜尋 ==========
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilter();
    });
  }

  Future<void> _selectMonth() async {
    final BuildContext currentContext = context;

    if (!currentContext.mounted) {
      return;
    }

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
                  // ✅ 搜尋結果提示
                  if (_searchQuery.trim().isNotEmpty) _buildSearchResultInfo(),
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

  // ========== 自定義 AppBar（含搜尋功能） ==========
  PreferredSizeWidget _buildAppBar() {
    if (_isSearching) {
      // ✅ 搜尋模式下的 AppBar
      return AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: const TextStyle(color: AppColor.text, fontSize: 16),
          decoration: InputDecoration(
            hintText: '搜尋分類或備註...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, color: AppColor.text),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: AppColor.text,
                      size: 20,
                    ),
                    onPressed: _clearSearch,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  )
                : null,
          ),
          onChanged: _performSearch,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _toggleSearch,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            TextButton(
              onPressed: _clearSearch,
              child: const Text(
                '清除',
                style: TextStyle(color: AppColor.text, fontSize: 14),
              ),
            ),
        ],
        backgroundColor: AppColor.primary,
        foregroundColor: AppColor.text,
      );
    }

    // ✅ 正常模式下的 AppBar
    return AppBar(
      title: const Text(
        'Miku 記帳',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      actions: [
        // ✅ 搜尋按鈕（取代設定）
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _toggleSearch,
          tooltip: '搜尋記錄',
        ),
      ],
    );
  }

  // ========== 搜尋結果資訊 ==========
  Widget _buildSearchResultInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColor.primary.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: AppColor.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '找到 ${_filteredRecords.length} 筆記錄 (關鍵字: "$_searchQuery")',
              style: const TextStyle(fontSize: 13, color: AppColor.text),
            ),
          ),
          GestureDetector(
            onTap: _clearSearch,
            child: const Icon(
              Icons.close,
              size: 16,
              color: AppColor.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ========== 月份選擇器 + 金額卡片 ==========
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
                    '${_selectedMonth.year}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColor.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${_selectedMonth.month}月',
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
          AmountFormatter.format(amount),
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
    String message = '${_selectedMonth.year}年${_selectedMonth.month}月 尚無記錄';
    if (_searchQuery.trim().isNotEmpty) {
      message = '找不到 "$_searchQuery" 相關的記錄';
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.trim().isNotEmpty ? Icons.search_off : Icons.inbox,
            size: 64,
            color: AppColor.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
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
                    '⬇ ${AmountFormatter.format(dailyExpense)}',
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
                    '⬆ ${AmountFormatter.format(dailyIncome)}',
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
                  '淨額 ${AmountFormatter.format(dailyTotal.abs())}',
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
          MessageService.showSnackBar(
            '已刪除記錄',
            key: 'record_deleted',
            color: Colors.grey.shade700,
          );
        },
        child: _buildRecordItem(record),
      );
    }).toList();
  }

  Widget _buildRecordItem(Record record) {
    final isExpense = record.amount < 0;
    final displayAmount = record.amount.abs();

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
                // ✅ 備註（如果有搜尋關鍵字，高亮顯示）
                if (record.note.isNotEmpty) ...[
                  _buildHighlightedText(
                    record.note,
                    _searchQuery.trim(),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    highlightStyle: const TextStyle(
                      fontSize: 11,
                      color: AppColor.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            isExpense
                ? '-${AmountFormatter.format(displayAmount)}'
                : AmountFormatter.format(displayAmount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isExpense ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  // ========== 高亮顯示搜尋關鍵字 ==========
  Widget _buildHighlightedText(
    String text,
    String query, {
    required TextStyle style,
    required TextStyle highlightStyle,
  }) {
    if (query.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final int startIndex = lowerText.indexOf(lowerQuery);

    if (startIndex == -1) {
      return Text(text, style: style);
    }

    final before = text.substring(0, startIndex);
    final highlighted = text.substring(startIndex, startIndex + query.length);
    final after = text.substring(startIndex + query.length);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: before, style: style),
          TextSpan(text: highlighted, style: highlightStyle),
          TextSpan(text: after, style: style),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(color: Colors.grey[800], thickness: 0.5),
    );
  }
}
