import 'package:flutter/material.dart';
import 'constants/app_colors.dart';
import 'screens/home_page.dart';
import 'screens/bookkeeping_page.dart';
import 'screens/analysis_page.dart';
import 'screens/profile_page.dart';
import 'widgets/nav_item.dart';
import 'widgets/category_chip.dart';
import 'services/storage_service.dart';
import 'models/record.dart';

void main() {
  runApp(const MyApp());
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
  int _selectedIndex = 0;
  static const double _bottomNavBarHeight = 72;
  final GlobalKey<HomePageState> _homePageKey = GlobalKey<HomePageState>();
  late List<Widget> _pages;
  final StorageService _storage = StorageService();

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

  void _refreshHomePage() {
    _homePageKey.currentState?.refreshRecords();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _onFABPressed() {
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
                  const Text(
                    '新增記帳',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColor.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
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
                        CategoryChip(
                          label: '餐飲',
                          isSelected: selectedCategory == '餐飲',
                          onTap: () => setState(() => selectedCategory = '餐飲'),
                        ),
                        CategoryChip(
                          label: '交通',
                          isSelected: selectedCategory == '交通',
                          onTap: () => setState(() => selectedCategory = '交通'),
                        ),
                        CategoryChip(
                          label: '購物',
                          isSelected: selectedCategory == '購物',
                          onTap: () => setState(() => selectedCategory = '購物'),
                        ),
                        CategoryChip(
                          label: '居家',
                          isSelected: selectedCategory == '居家',
                          onTap: () => setState(() => selectedCategory = '居家'),
                        ),
                        CategoryChip(
                          label: '娛樂',
                          isSelected: selectedCategory == '娛樂',
                          onTap: () => setState(() => selectedCategory = '娛樂'),
                        ),
                        CategoryChip(
                          label: '教育',
                          isSelected: selectedCategory == '教育',
                          onTap: () => setState(() => selectedCategory = '教育'),
                        ),
                        CategoryChip(
                          label: '醫療',
                          isSelected: selectedCategory == '醫療',
                          onTap: () => setState(() => selectedCategory = '醫療'),
                        ),
                        CategoryChip(
                          label: '3C',
                          isSelected: selectedCategory == '3C',
                          onTap: () => setState(() => selectedCategory = '3C'),
                        ),
                        CategoryChip(
                          label: '禮物',
                          isSelected: selectedCategory == '禮物',
                          onTap: () => setState(() => selectedCategory = '禮物'),
                        ),
                        CategoryChip(
                          label: '投資',
                          isSelected: selectedCategory == '投資',
                          onTap: () => setState(() => selectedCategory = '投資'),
                        ),
                        CategoryChip(
                          label: '其他',
                          isSelected: selectedCategory == '其他',
                          onTap: () => setState(() => selectedCategory = '其他'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
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

                        final record = Record(
                          amount: amount,
                          category: selectedCategory,
                          note: noteController.text.isEmpty ? '無備註' : noteController.text,
                          date: DateTime.now(),
                        );

                        await _storage.addRecord(record);
                        _refreshHomePage();

                        if (!context.mounted) return;
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('記帳成功'),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('设置功能開發中')),
              );
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 25),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SizedBox(
            width: 56,
            height: 56,
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
              NavItem(
                icon: Icons.home,
                label: '明細',
                isSelected: _selectedIndex == 0,
                onTap: () => _onItemTapped(0),
              ),
              NavItem(
                icon: Icons.book,
                label: '記帳',
                isSelected: _selectedIndex == 1,
                onTap: () => _onItemTapped(1),
              ),
              const SizedBox(width: 40),
              NavItem(
                icon: Icons.analytics,
                label: '分析',
                isSelected: _selectedIndex == 2,
                onTap: () => _onItemTapped(2),
              ),
              NavItem(
                icon: Icons.person,
                label: '我的',
                isSelected: _selectedIndex == 3,
                onTap: () => _onItemTapped(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}