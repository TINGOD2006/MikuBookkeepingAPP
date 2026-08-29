  import 'package:flutter/material.dart';

  void main() {
    runApp(const MyApp());
  }

  class AppColor {
    static const Color primary = Color.fromARGB(255, 0, 122, 244);
    static const Color secondary = Color.fromARGB(255, 5, 169, 239);
    static const Color background = Color.fromARGB(255, 240, 244, 248);
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
            foregroundColor: AppColor.background,
          ),
        ),
        home: const MyHomePage(title: "歡迎使用 Miku 記帳"),
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
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    HomePage(),
    BookkeepingPage(),
    AnalysisPage(),
    ProfilePage(),
  ];

  // 底部导航栏点击事件
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 中间浮动按钮点击事件（已替换）
  void _onFABPressed() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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

              // 标题
              const Text(
                '新增記帳',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColor.primary,
                ),
              ),
              const SizedBox(height: 24),

              // 金额输入框
              const Text(
                '金額',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
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

              // 分类选择
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
                    _buildCategoryChip('🍜 餐飲', true),
                    _buildCategoryChip('🚗 交通', false),
                    _buildCategoryChip('🛒 購物', false),
                    _buildCategoryChip('🏠 居家', false),
                    _buildCategoryChip('💼 工作', false),
                    _buildCategoryChip('🎮 娛樂', false),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 备注输入框
              const Text(
                '備註',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: '請輸入備註（可選）',
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

              // 保存按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ========== 顶部导航栏 ==========
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('设置功能开发中')));
            },
          ),
        ],
      ),
      // ==========主體內容==========
      body: _pages[_selectedIndex],
      
      // ==========中间圓形按钮==========
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 30),
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
      
      // ========== 底部导航栏 ==========
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        color: AppColor.background,
        child: SizedBox(
          height: 60,
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

  // ==========自定义导航项构建方法==========
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

  // ========== 分类标签构建方法（新增） ==========
  Widget _buildCategoryChip(String label, bool isSelected) {
    return Container(
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
    );
  }
}

  // ========== 1. 明細頁面 ==========
  class HomePage extends StatelessWidget {
    const HomePage({super.key});

    @override
    Widget build(BuildContext context) {
      return Container(
        color: AppColor.background,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
          ),
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
        color: AppColor.background,
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
        color: AppColor.background,
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
        color: AppColor.background,
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