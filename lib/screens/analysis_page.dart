import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/app_colors.dart';
import '../constants/categories.dart';
import '../models/record.dart';
import '../services/storage_service.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final StorageService _storage = StorageService();
  List<Record> _allRecords = [];
  List<Record> _filteredRecords = [];
  bool _isLoading = true;

  // 選中的類型：支出 或 收入
  String _selectedType = '支出';

  // 選中的月份
  DateTime _selectedMonth = DateTime.now();

  // 分類統計數據
  List<CategoryStat> _categoryStats = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ========== 載入數據 ==========
  Future<void> _loadData() async {
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

  // ========== 套用篩選 ==========
  void _applyFilter() {
    // 按月份過濾
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

    _filteredRecords = _allRecords.where((record) {
      return record.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
          record.date.isBefore(monthEnd);
    }).toList();

    // 按類型過濾（支出為負數，收入為正數）
    if (_selectedType == '支出') {
      _filteredRecords = _filteredRecords.where((r) => r.amount < 0).toList();
    } else {
      _filteredRecords = _filteredRecords.where((r) => r.amount > 0).toList();
    }

    // 計算分類統計
    _calculateStats();
  }

  // ========== 計算分類統計 ==========
  void _calculateStats() {
    final Map<String, double> categoryAmounts = {};

    for (final record in _filteredRecords) {
      final amount = record.amount.abs();
      categoryAmounts[record.category] = (categoryAmounts[record.category] ?? 0) + amount;
    }

    final total = categoryAmounts.values.fold(0.0, (sum, value) => sum + value);

    _categoryStats = categoryAmounts.entries.map((entry) {
      final double percentage = total > 0 ? (entry.value / total) * 100.0 : 0.0;
      final category = CategoryData.getCategory(entry.key);
      return CategoryStat(
        name: entry.key,
        amount: entry.value,
        percentage: percentage,
        icon: category?.icon ?? Icons.category,
        color: category?.color ?? Colors.grey,
      );
    }).toList();

    // 按金額降序排列
    _categoryStats.sort((a, b) => b.amount.compareTo(a.amount));
  }

  // ========== 切換月份 ==========
  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
      _applyFilter();
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    if (nextMonth.isBefore(now) || nextMonth.isAtSameMomentAs(DateTime(now.year, now.month, 1))) {
      setState(() {
        _selectedMonth = nextMonth;
        _applyFilter();
      });
    }
  }

  // ========== 切換類型 ==========
  void _switchType(String type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      _applyFilter();
    });
  }

  // ========== 刷新數據 ==========
  void refreshData() {
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分析'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: refreshData,
          ),
        ],
      ),
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
                  // 月份選擇器
                  _buildMonthSelector(),
                  // 類型切換
                  _buildTypeTabs(),
                  // 總金額
                  _buildTotalAmount(),
                  // 圓環圖 + 圖例
                  Expanded(
                    flex: 2,
                    child: _categoryStats.isEmpty
                        ? _buildEmptyState()
                        : _buildChartSection(),
                  ),
                  // 分類列表
                  Expanded(
                    flex: 2,
                    child: _categoryStats.isEmpty
                        ? const SizedBox()
                        : _buildCategoryList(),
                  ),
                ],
              ),
      ),
    );
  }

  // ========== 月份選擇器 ==========
  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousMonth,
            icon: const Icon(Icons.chevron_left, color: AppColor.text, size: 28),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Text(
            '${_selectedMonth.year}年 ${_selectedMonth.month}月',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColor.text,
            ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right, color: AppColor.text, size: 28),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  // ========== 類型切換 ==========
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
          children: ['支出', '收入'].map((type) {
            final isSelected = _selectedType == type;
            return Expanded(
              child: GestureDetector(
                onTap: () => _switchType(type),
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

  // ========== 總金額 ==========
  Widget _buildTotalAmount() {
    final total = _filteredRecords.fold(
      0.0,
      (sum, record) => sum + record.amount.abs(),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$_selectedType 總計：',
            style: const TextStyle(
              fontSize: 14,
              color: AppColor.textSecondary,
            ),
          ),
          Text(
            '\$${total.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColor.text,
            ),
          ),
        ],
      ),
    );
  }

  // ========== 圖表區域 ==========
  Widget _buildChartSection() {
    return Row(
      children: [
        // 圓環圖
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AspectRatio(
              aspectRatio: 1,
              child: _buildDonutChart(),
            ),
          ),
        ),
        // 圖例
        Expanded(
          flex: 2,
          child: _buildLegend(),
        ),
      ],
    );
  }

  // ========== 圓環圖 ==========
  Widget _buildDonutChart() {
    return CustomPaint(
      painter: DonutChartPainter(
        stats: _categoryStats,
        total: _filteredRecords.fold(
          0.0,
          (sum, record) => sum + record.amount.abs(),
        ),
        centerText: '\$${_filteredRecords.fold(0.0, (sum, r) => sum + r.amount.abs()).toStringAsFixed(0)}',
      ),
      size: const Size(double.infinity, double.infinity),
    );
  }

  // ========== 圖例 ==========
  Widget _buildLegend() {
    final topStats = _categoryStats.take(5).toList();
    final remaining = _categoryStats.length - 5;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...topStats.map((stat) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: stat.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stat.name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColor.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${stat.percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColor.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (remaining > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '其他 $remaining 項',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColor.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ========== 空狀態 ==========
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 64,
            color: AppColor.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            '${_selectedMonth.year}年${_selectedMonth.month}月 無$_selectedType記錄',
            style: const TextStyle(
              fontSize: 16,
              color: AppColor.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '切換月份或新增記錄',
            style: const TextStyle(
              fontSize: 14,
              color: AppColor.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ========== 分類列表 ==========
  Widget _buildCategoryList() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        itemCount: _categoryStats.length,
        itemBuilder: (context, index) {
          final stat = _categoryStats[index];
          return _buildCategoryItem(stat, index);
        },
      ),
    );
  }

  Widget _buildCategoryItem(CategoryStat stat, int index) {
    final isEven = index % 2 == 0;
    final barWidth = stat.percentage / 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isEven ? Colors.grey[900] : Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 分類圖標
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: stat.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  stat.icon,
                  size: 18,
                  color: stat.color,
                ),
              ),
              const SizedBox(width: 12),
              // 分類名稱
              Expanded(
                child: Text(
                  stat.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColor.text,
                  ),
                ),
              ),
              // 金額
              Text(
                '\$${stat.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColor.text,
                ),
              ),
              const SizedBox(width: 12),
              // 百分比
              SizedBox(
                width: 50,
                child: Text(
                  '${stat.percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColor.textSecondary,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 進度條
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: barWidth.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[800],
              color: stat.color,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ========== 分類統計數據模型 ==========
class CategoryStat {
  final String name;
  final double amount;
  final double percentage;
  final IconData icon;
  final Color color;

  CategoryStat({
    required this.name,
    required this.amount,
    required this.percentage,
    required this.icon,
    required this.color,
  });
}

// ========== 圓環圖繪製器 ==========
class DonutChartPainter extends CustomPainter {
  final List<CategoryStat> stats;
  final double total;
  final String centerText;

  DonutChartPainter({
    required this.stats,
    required this.total,
    required this.centerText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.85;
    final innerRadius = radius * 0.6;

    double startAngle = -math.pi / 2;

    // 繪製扇形
    for (final stat in stats) {
      final sweepAngle = (stat.percentage / 100) * 2 * math.pi;

      final paint = Paint()
        ..color = stat.color
        ..style = PaintingStyle.fill
        ..strokeWidth = 0;

      // 繪製扇形路徑
      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
      );
      path.close();
      canvas.drawPath(path, paint);

      startAngle += sweepAngle;
    }

    // 繪製內圓（形成圓環效果）
    final innerPaint = Paint()
      ..color = AppColor.background
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, innerRadius, innerPaint);

    // 繪製中間文字
    final textSpan = TextSpan(
      text: centerText,
      style: const TextStyle(
        color: AppColor.text,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}