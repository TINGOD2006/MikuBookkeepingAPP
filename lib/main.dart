import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

// ========== 記帳紀錄類別 ==========
class Record {
  final double amount;
  final String category;
  final String note;
  final DateTime date;

  Record({
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory Record.fromJson(Map<String, dynamic> map) {
    return Record(
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      note: map['note'] as String,
      date: DateTime.parse(map['date'] as String),
    );
  }
}

// ========== 顏色定義 ==========
class AppColor {
  static const Color primary = Color.fromARGB(255, 0, 122, 244);
  static const Color secondary = Color.fromARGB(255, 5, 169, 239);
  static const Color black = Color.fromARGB(255, 0, 0, 0);
  static const Color white = Color.fromARGB(255, 255, 255, 255);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Miku 記帳',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColor.primary),
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColor.primary,
          foregroundColor: AppColor.white,
        ),
      ),
      home: const MyHomePage(title: "Miku 記帳"),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0; // 頁面指針
  static const double _bottomNavBarHeight = 72; // 底部導航欄高度

  // 定義一個全局的 GlobalKey，用於訪問 HomePage 的狀態
  final GlobalKey<HomePageState> _homePageKey = GlobalKey<HomePageState>();

  late List<Widget> _pages;

  // 初始化頁面列表
  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(key: _homePageKey),
      const BookkeepingPage(),
      const AnalysisPage(),
      const ProfilePage(),
    ];
  }

  // 刷新明細頁面
  void _refreshHomePage() {
    _homePageKey.currentState?.refreshRecords();
  }

  // 保存記錄到 SharedPreferences（本地儲存）
  Future<void> _saveRecord(Record record) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? recordsJson = prefs.getStringList('records');
    List<Record> records = [];

    if (recordsJson != null) {
      records = recordsJson
          .map((json) => Record.fromJson(jsonDecode(json) as Map<String, dynamic>))
          .toList();
    }

    records.add(record);
    records.sort((a, b) => b.date.compareTo(a.date));

    final List<String> newRecordsJson = records.map((r) => r.toJsonString()).toList();
    await prefs.setStringList('records', newRecordsJson);
  }

  // 底部導航欄點擊事件
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

// 中間浮動按鈕點擊事件
void _onFABPressed() {
  // 建立控制器
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  String selectedCategory = '餐飲';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 拖拽指示器
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 標題
                const Text(
                  '新增記帳',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColor.primary,
                  ),
                ),
                const SizedBox(height: 24),

                // 金額輸入框
                const Text(
                  '金額',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    hintText: '請輸入金額',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                  autofocus: true,
                ),
                const SizedBox(height: 16),

                // 分類選擇
                const Text(
                  '分類',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildCategoryChip('餐飲', selectedCategory == '餐飲', () {
                        setState(() => selectedCategory = '餐飲');
                      }),
                      _buildCategoryChip('交通', selectedCategory == '交通', () {
                        setState(() => selectedCategory = '交通');
                      }),
                      _buildCategoryChip('購物', selectedCategory == '購物', () {
                        setState(() => selectedCategory = '購物');
                      }),
                      _buildCategoryChip('居家', selectedCategory == '居家', () {
                        setState(() => selectedCategory = '居家');
                      }),
                      _buildCategoryChip('娛樂', selectedCategory == '娛樂', () {
                        setState(() => selectedCategory = '娛樂');
                      }),
                      _buildCategoryChip('教育', selectedCategory == '教育', () {
                        setState(() => selectedCategory = '教育');
                      }),
                      _buildCategoryChip('醫療', selectedCategory == '醫療', () {
                        setState(() => selectedCategory = '醫療');
                      }),
                      _buildCategoryChip('3C', selectedCategory == '3C', () {
                        setState(() => selectedCategory = '3C');
                      }),
                      _buildCategoryChip('禮物', selectedCategory == '禮物', () {
                        setState(() => selectedCategory = '禮物');
                      }),
                      _buildCategoryChip('投資', selectedCategory == '投資', () {
                        setState(() => selectedCategory = '投資');
                      }),
                      _buildCategoryChip('其他', selectedCategory == '其他', () {
                        setState(() => selectedCategory = '其他');
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 備註輸入框
                const Text(
                  '備註',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    hintText: '請輸入備註',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.note_add, color: Colors.grey),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // 保存按鈕
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      // 驗證金額
                      if (amountController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('請輸入金額！'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final amount = double.tryParse(amountController.text) ?? 0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('請輸入有效金額！'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // 建立記錄
                      final record = Record(
                        amount: amount,
                        category: selectedCategory,
                        note: noteController.text.isEmpty ? '無備註' : noteController.text,
                        date: DateTime.now(),
                      );

                      // 儲存記錄
                      await _saveRecord(record);

                      // 刷新明細頁面
                      _refreshHomePage();

                      if (!context.mounted) return;

                      // 關閉底部表單
                      Navigator.pop(context);

                      // 顯示成功訊息
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('記帳成功！🎉'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '保存記帳',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

  // ========== 自定義導航項建構方法 ==========
  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppColor.primary : Colors.grey,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? AppColor.primary : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ========== 分類標籤建構方法（修正） ==========
  Widget _buildCategoryChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColor.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ========== Build 方法 ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
      ),
      body: _pages[_selectedIndex],
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 25),
        child: FloatingActionButton(
          onPressed: _onFABPressed,
          backgroundColor: AppColor.primary,
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: _bottomNavBarHeight,
          color: Colors.black,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, '明細', 0),
              _buildNavItem(Icons.book, '記帳', 1),
              const SizedBox(width: 40),
              _buildNavItem(Icons.analytics, '分析', 2),
              _buildNavItem(Icons.person, '我的', 3),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== 1. 明細頁面（改為 StatefulWidget） ==========
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  List<Record> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  // 載入記錄
  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final List<String>? recordsJson = prefs.getStringList('records');

    if (recordsJson != null) {
      _records = recordsJson
          .map((json) => Record.fromJson(jsonDecode(json) as Map<String, dynamic>))
          .toList();
      _records.sort((a, b) => b.date.compareTo(a.date));
    } else {
      _records = [];
    }

    setState(() => _isLoading = false);
  }

  // 讓外部呼叫的刷新方法
  void refreshRecords() {
    _loadRecords();
  }

  // 刪除記錄
  Future<void> _deleteRecord(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _records.removeAt(index);
    final List<String> newRecordsJson = _records.map((r) => r.toJsonString()).toList();
    await prefs.setStringList('records', newRecordsJson);
    setState(() {});
  }

  // 計算總金額
  double get _totalAmount {
    return _records.fold(0, (sum, record) => sum + record.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColor.black,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 總金額卡片
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    children: [
                      const Text(
                        '總支出',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${_totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '共 ${_records.length} 筆記錄',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // 記錄列表
                Expanded(
                  child: _records.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                '尚無記帳記錄',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '點擊 ✚ 按鈕新增記錄',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _records.length,
                          itemBuilder: (context, index) {
                            final record = _records[index];
                            return Dismissible(
                              key: Key(record.date.toIso8601String() + index.toString()),
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (direction) {
                                _deleteRecord(index);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('已刪除記錄'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
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
                                          record.category.split(' ')[0],
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            record.category,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
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
                                          '\$${record.amount.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColor.primary,
                                          ),
                                        ),
                                        Text(
                                          '${record.date.month}/${record.date.day}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ========== 2. 記帳頁面 ==========
class BookkeepingPage extends StatefulWidget {
  const BookkeepingPage({super.key});

  @override
  State<BookkeepingPage> createState() => _BookkeepingPageState();
}

class _BookkeepingPageState extends State<BookkeepingPage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  void _decrementCounter() {
    setState(() {
      if (_counter > 0) _counter--;
    });
  }

  void _resetCounter() {
    setState(() {
      _counter = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColor.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Miku 记账',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColor.primary,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                '$_counter',
                style: const TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: AppColor.primary,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  heroTag: 'decrement',
                  onPressed: _decrementCounter,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.remove, color: Colors.white),
                ),
                const SizedBox(width: 20),
                FloatingActionButton(
                  heroTag: 'reset',
                  onPressed: _resetCounter,
                  backgroundColor: Colors.grey,
                  child: const Icon(Icons.refresh, color: Colors.white),
                ),
                const SizedBox(width: 20),
                FloatingActionButton(
                  heroTag: 'increment',
                  onPressed: _incrementCounter,
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '你点击了 $_counter 次',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== 3. 分析頁面 ==========
class AnalysisPage extends StatelessWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColor.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 80, color: AppColor.primary),
            SizedBox(height: 16),
            Text(
              '分析頁面',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== 4. 我的頁面 ==========
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColor.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColor.primary,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              '用户名称',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'user@example.com',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}