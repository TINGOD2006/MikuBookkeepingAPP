import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/storage_service.dart';
import '../services/local_notification_service.dart';
import '../services/message_service.dart';
import '../widgets/month_picker_dialog.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final StorageService _storage = StorageService();

  // 當前選中的月份
  DateTime _selectedMonth = DateTime.now();

  // 預算金額
  double? _budgetAmount;

  // 該月總支出
  double _monthlyExpense = 0;

  // 載入狀態
  bool _isLoading = true;

  // 是否正在編輯預算
  bool _isEditing = false;

  // 編輯控制器
  final TextEditingController _budgetController = TextEditingController();

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
      final month = _selectedMonth;
      final budget = await _storage.loadBudget(month.year, month.month);
      final expense = await _storage.getMonthlyExpense(month.year, month.month);

      if (mounted) {
        setState(() {
          _budgetAmount = budget;
          _monthlyExpense = expense;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('載入預算數據失敗: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ========== 切換月份 ==========
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
      });
      _loadData();
    }
  }

  // ========== 儲存預算 ==========
  Future<void> _saveBudget() async {
    final text = _budgetController.text.trim();
    if (text.isEmpty) {
      _showSnackBar('請輸入預算金額', Colors.red);
      return;
    }

    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) {
      _showSnackBar('請輸入有效的預算金額', Colors.red);
      return;
    }

    setState(() {
      _isEditing = false;
      _isLoading = true;
    });

    try {
      await _storage.saveBudget(
        _selectedMonth.year,
        _selectedMonth.month,
        amount,
      );
      _budgetAmount = amount;
      await LocalNotificationService.checkAndShowBudgetAlertForMonth(
        _selectedMonth.year,
        _selectedMonth.month,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('預算已儲存 ✅', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('儲存失敗: $e', Colors.red);
      }
    }
  }

  // ========== 開始編輯預算 ==========
  void _startEditing() {
    _budgetController.text = _budgetAmount?.toStringAsFixed(0) ?? '';
    setState(() {
      _isEditing = true;
    });
  }

  // ========== 取消編輯 ==========
  void _cancelEditing() {
    setState(() {
      _isEditing = false;
    });
    _budgetController.clear();
  }

  // ========== 計算預算使用率 ==========
  double get _usagePercentage {
    if (_budgetAmount == null || _budgetAmount! <= 0) return 0;
    return (_monthlyExpense / _budgetAmount!).clamp(0.0, 1.0);
  }

  double get _remainingBudget {
    if (_budgetAmount == null) return 0;
    return (_budgetAmount! - _monthlyExpense).clamp(
      -double.infinity,
      double.infinity,
    );
  }

  bool get _isOverBudget {
    return _budgetAmount != null && _monthlyExpense > _budgetAmount!;
  }

  bool get _isNearBudget {
    return _budgetAmount != null &&
        _usagePercentage >= 0.8 &&
        _usagePercentage < 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('預算'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Container(
        color: AppColor.background,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColor.primary),
              )
            : SizedBox.expand(
                // ✅ 填滿所有可用空間
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMonthSelector(),
                      const SizedBox(height: 16),
                      _buildBudgetCard(),
                      const SizedBox(height: 16),
                      _buildExpenseCard(),
                      const SizedBox(height: 16),
                      _buildProgressCard(),
                      if (_isOverBudget) ...[
                        const SizedBox(height: 16),
                        _buildOverBudgetWarning(),
                      ],
                      if (_isNearBudget && !_isOverBudget) ...[
                        const SizedBox(height: 16),
                        _buildNearBudgetWarning(),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ========== 月份選擇器 ==========
  Widget _buildMonthSelector() {
    return GestureDetector(
      onTap: _selectMonth,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_month,
                  color: AppColor.text,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  '${_selectedMonth.year}年 ${_selectedMonth.month}月',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColor.text,
                  ),
                ),
              ],
            ),
            const Icon(Icons.arrow_drop_down, color: AppColor.text, size: 24),
          ],
        ),
      ),
    );
  }

  // ========== 預算設定卡片 ==========
  Widget _buildBudgetCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.attach_money, color: AppColor.primary, size: 20),
              SizedBox(width: 8),
              Text(
                '本月預算',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColor.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isEditing) ...[
            // 編輯模式
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _budgetController,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColor.text,
                    ),
                    decoration: InputDecoration(
                      hintText: '輸入預算金額',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 24,
                      ),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    IconButton(
                      onPressed: _saveBudget,
                      icon: const Icon(
                        Icons.check,
                        color: Colors.green,
                        size: 28,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      onPressed: _cancelEditing,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 28,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ] else ...[
            // 顯示模式
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _budgetAmount != null
                      ? '\$${_budgetAmount!.toStringAsFixed(0)}'
                      : '未設定',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _budgetAmount != null
                        ? AppColor.text
                        : Colors.grey[500],
                  ),
                ),
                TextButton.icon(
                  onPressed: _startEditing,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('編輯'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColor.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ========== 支出概覽卡片 ==========
  Widget _buildExpenseCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '已支出',
                  style: TextStyle(fontSize: 14, color: AppColor.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${_monthlyExpense.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 50, color: Colors.grey[700]),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '剩餘',
                  style: TextStyle(fontSize: 14, color: AppColor.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  _budgetAmount != null
                      ? '\$${_remainingBudget.toStringAsFixed(0)}'
                      : '--',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _isOverBudget
                        ? Colors.redAccent
                        : Colors.greenAccent,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 50, color: Colors.grey[700]),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  '使用率',
                  style: TextStyle(fontSize: 14, color: AppColor.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  _budgetAmount != null && _budgetAmount! > 0
                      ? '${(_usagePercentage * 100).toStringAsFixed(0)}%'
                      : '--',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _isOverBudget ? Colors.redAccent : AppColor.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== 預算進度卡片 ==========
  Widget _buildProgressCard() {
    final bool hasBudget = _budgetAmount != null && _budgetAmount! > 0;
    final double progress = hasBudget ? _usagePercentage : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '預算進度',
            style: TextStyle(fontSize: 14, color: AppColor.textSecondary),
          ),
          const SizedBox(height: 8),
          // 進度條
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: hasBudget ? progress.clamp(0.0, 1.0) : 0,
              backgroundColor: Colors.grey[700],
              color: _isOverBudget
                  ? Colors.red
                  : _isNearBudget
                  ? Colors.orange
                  : Colors.green,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasBudget ? '0' : '--',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColor.textSecondary,
                ),
              ),
              Text(
                hasBudget
                    ? '${(_usagePercentage * 100).toStringAsFixed(0)}%'
                    : '尚未設定預算',
                style: TextStyle(
                  fontSize: 12,
                  color: _isOverBudget
                      ? Colors.redAccent
                      : AppColor.textSecondary,
                  fontWeight: _isOverBudget
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              Text(
                hasBudget ? _budgetAmount!.toStringAsFixed(0) : '--',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColor.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========== 超預算警告 ==========
  Widget _buildOverBudgetWarning() {
    final overAmount = _monthlyExpense - _budgetAmount!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠️ 已超過預算！',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                Text(
                  '本月已超出 \$${overAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 14, color: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== 接近預算警告 ==========
  Widget _buildNearBudgetWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠️ 即將超過預算！',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                Text(
                  '已使用 ${(_usagePercentage * 100).toStringAsFixed(0)}% 的預算',
                  style: const TextStyle(fontSize: 14, color: Colors.orange),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== SnackBar ==========
  void _showSnackBar(String message, Color color) {
    MessageService.showSnackBar(message, color: color);
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }
}
