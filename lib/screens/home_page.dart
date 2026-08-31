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
  List<Record> _records = [];
  bool _isLoading = true;
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      _records = await _storage.loadRecords();
    } catch (e) {
      debugPrint('載入記錄失敗: $e');
      _records = [];
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void refreshRecords() {
    _loadRecords();
  }

  Future<void> _deleteRecord(int index) async {
    await _storage.deleteRecord(index);
    _records.removeAt(index);
    if (mounted) {
      setState(() {});
    }
  }

  double get _totalExpense {
    return _records
        .where((record) => record.amount < 0)
        .fold(0, (sum, record) => sum + record.amount.abs());
  }

  double get _totalIncome {
    return _records
        .where((record) => record.amount > 0)
        .fold(0, (sum, record) => sum + record.amount);
  }

  double get _balance {
    return _totalIncome - _totalExpense;
  }

  double get _todayExpense {
    final today = DateTime.now();
    final todayStr =
        '${today.year}/${today.month.toString().padLeft(2, '0')}/${today.day.toString().padLeft(2, '0')}';
    return _records
        .where((record) => record.formattedDate == todayStr && record.amount < 0)
        .fold(0, (sum, record) => sum + record.amount.abs());
  }

  Map<String, List<Record>> get _groupedRecords {
    final Map<String, List<Record>> groups = {};
    for (final record in _records) {
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
    return Container(
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
                Expanded(
                  child: _records.isEmpty
                      ? _buildEmptyState()
                      : _buildRecordList(),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      margin: const EdgeInsets.all(16),
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          SummaryItem(
            label: '支出',
            amount: _totalExpense,
            color: AppColor.text,
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColor.text.withValues(alpha: 0.2),
          ),
          SummaryItem(
            label: '收入',
            amount: _totalIncome,
            color: AppColor.text,
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColor.text.withValues(alpha: 0.2),
          ),
          SummaryItem(
            label: '結餘',
            amount: _balance,
            color: AppColor.text,
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColor.text.withValues(alpha: 0.2),
          ),
          SummaryItem(
            label: '今日支出',
            amount: _todayExpense,
            color: AppColor.text,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: AppColor.textSecondary),
          SizedBox(height: 16),
          Text(
            '尚無記帳記錄',
            style: TextStyle(
              fontSize: 18,
              color: AppColor.text,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '點擊 ✚ 按鈕新增記錄',
            style: TextStyle(
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
                size: 16,
                color: AppColor.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                date,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColor.text,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColor.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (dailyExpense > 0)
                  Text(
                    '⬇ \$${dailyExpense.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
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
                  const SizedBox(width: 4),
                Text(
                  '淨額 \$${dailyTotal.abs().toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
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

      final globalIndex = _records.indexOf(record);

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
                '\$${displayAmount.toStringAsFixed(0)}',
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