import 'package:flutter/material.dart';

import 'constants/app_colors.dart';
import 'constants/categories.dart';
import 'screens/bookkeeping_page.dart';
import 'screens/budget_page.dart';
import 'screens/analysis_page.dart';
import 'screens/profile_page.dart';
import 'widgets/nav_item.dart';
import 'widgets/add_record_dialog.dart';
import 'services/storage_service.dart';
import 'services/notification_listener.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CategoryData.init();
  await NotificationListenerService.initialize();
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
          foregroundColor: AppColor.text,
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  static const double _bottomNavBarHeight = 72;
  final GlobalKey<BookkeepingPageState> _bookkeepingPageKey =
      GlobalKey<BookkeepingPageState>();
  late List<Widget> _pages;
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _pages = [
      BookkeepingPage(key: _bookkeepingPageKey),
      const BudgetPage(),
      const AnalysisPage(),
      const ProfilePage(),
    ];
  }

  void _refreshBookkeepingPage() {
    final state = _bookkeepingPageKey.currentState;
    if (state != null) {
      state.refreshRecords();
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _onFABPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: AppColor.background,
          body: AddRecordDialog(
            onSave: (record) async {
              await _storage.addRecord(record);
              _refreshBookkeepingPage();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              child: const Icon(Icons.add, color: AppColor.text, size: 30),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: _bottomNavBarHeight,
          color: AppColor.background,
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
                label: '預算',
                isSelected: _selectedIndex == 1,
                onTap: () => _onItemTapped(1),
              ),
              const SizedBox(width: 90),
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
