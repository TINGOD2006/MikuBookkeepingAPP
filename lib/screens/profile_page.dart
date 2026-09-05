import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../services/storage_service.dart';
import '../services/notification_listener.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final StorageService _storage = StorageService();

  String _userName = '用戶名稱';
  String _userEmail = 'user@example.com';
  String? _avatarPath;

  int _totalRecords = 0;
  double _totalExpense = 0;
  double _totalIncome = 0;

  bool _isLoading = true;
  bool _autoRecordEnabled = false; // ✅ 是否記錄
  bool _aiClassificationEnabled = true; // ✅ 是否使用 AI（預設開啟）
  bool _backgroundNotificationEnabled = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStatistics();
    _loadAutoRecordSetting();
    _loadAIClassificationSetting(); // ✅ 新增
    _loadBackgroundNotificationSetting();
  }

  // ========== 載入用戶資料 ==========
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('user_name') ?? '用戶名稱';
        _userEmail = prefs.getString('user_email') ?? 'user@example.com';
        _avatarPath = prefs.getString('avatar_path');
      });
    }
  }

  // ========== 載入統計數據 ==========
  Future<void> _loadStatistics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final records = await _storage.loadRecords();

      double expense = 0;
      double income = 0;

      for (final record in records) {
        if (record.amount < 0) {
          expense += record.amount.abs();
        } else {
          income += record.amount;
        }
      }

      if (mounted) {
        setState(() {
          _totalRecords = records.length;
          _totalExpense = expense;
          _totalIncome = income;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ========== 載入自動記錄設定 ==========
  Future<void> _loadAutoRecordSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoRecordEnabled = prefs.getBool('auto_record_enabled') ?? false;
      });
    }
  }

  // ✅ 新增：載入 AI 分類設定
  Future<void> _loadAIClassificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _aiClassificationEnabled =
            prefs.getBool('use_ai_classification') ?? true;
      });
    }
  }

  Future<void> _loadBackgroundNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _backgroundNotificationEnabled =
            prefs.getBool('background_notification_enabled') ?? false;
      });
    }
  }

  // ========== ✅ 切換自動記錄（只控制是否記錄） ==========
  Future<void> _toggleAutoRecord(bool value) async {
    final BuildContext currentContext = context;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_record_enabled', value);
    await NotificationListenerService.setAutoRecordEnabled(value);

    if (!currentContext.mounted) return;

    setState(() {
      _autoRecordEnabled = value;
    });

    ScaffoldMessenger.of(currentContext).showSnackBar(
      SnackBar(
        content: Text(value ? '✅ 自動記錄已開啟' : 'ℹ️ 自動記錄已關閉'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: value ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ========== ✅ 切換 AI 分類（只控制分類方式） ==========
  Future<void> _toggleAIClassification(bool value) async {
    final BuildContext currentContext = context;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_ai_classification', value);

    if (!currentContext.mounted) return;

    setState(() {
      _aiClassificationEnabled = value;
    });

    ScaffoldMessenger.of(currentContext).showSnackBar(
      SnackBar(
        content: Text(value ? '🤖 AI 分類已啟用' : '📋 已切換為規則表分類（不消耗 AI 額度）'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: value ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleBackgroundNotification(bool value) async {
    final currentContext = context;
    await NotificationListenerService.setBackgroundNotificationEnabled(value);

    if (!currentContext.mounted) return;
    setState(() => _backgroundNotificationEnabled = value);
    ScaffoldMessenger.of(currentContext).showSnackBar(
      SnackBar(
        content: Text(value ? '✅ 後台常駐通知已開啟' : 'ℹ️ 後台常駐通知已關閉'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: value ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ========== 更換頭像 ==========
  Future<void> _changeAvatar(ImageSource source) async {
    final BuildContext currentContext = context;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 80,
      );

      if (image == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatar_path', image.path);

      if (!currentContext.mounted) return;

      setState(() {
        _avatarPath = image.path;
      });

      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(
            content: Text('頭像已更新 ✅'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!currentContext.mounted) return;

      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text('更新頭像失敗: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ========== 顯示頭像選擇對話框 ==========
  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '選擇頭像',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColor.text,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPickerOption(
                      icon: Icons.photo_library,
                      label: '從相簿選擇',
                      onTap: () {
                        Navigator.pop(context);
                        _changeAvatar(ImageSource.gallery);
                      },
                    ),
                    _buildPickerOption(
                      icon: Icons.camera_alt,
                      label: '拍照',
                      onTap: () {
                        Navigator.pop(context);
                        _changeAvatar(ImageSource.camera);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColor.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColor.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColor.text),
          ),
        ],
      ),
    );
  }

  // ========== 編輯用戶名稱 ==========
  Future<void> _editName() async {
    final TextEditingController controller = TextEditingController(
      text: _userName,
    );
    final BuildContext currentContext = context;

    final result = await showDialog<bool>(
      context: currentContext,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColor.background,
          title: const Text('編輯名稱', style: TextStyle(color: AppColor.text)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: AppColor.text),
            decoration: InputDecoration(
              hintText: '請輸入名稱',
              hintStyle: TextStyle(color: Colors.grey[400]),
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
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor.primary,
              ),
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );

    if (!currentContext.mounted) return;

    if (result == true && controller.text.trim().isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', controller.text.trim());

      setState(() {
        _userName = controller.text.trim();
      });

      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(
            content: Text('名稱已更新 ✅'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    controller.dispose();
  }

  // ========== 編輯用戶郵箱 ==========
  Future<void> _editEmail() async {
    final TextEditingController controller = TextEditingController(
      text: _userEmail,
    );
    final BuildContext currentContext = context;

    final result = await showDialog<bool>(
      context: currentContext,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColor.background,
          title: const Text('編輯郵箱', style: TextStyle(color: AppColor.text)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: AppColor.text),
            decoration: InputDecoration(
              hintText: '請輸入郵箱',
              hintStyle: TextStyle(color: Colors.grey[400]),
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
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor.primary,
              ),
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );

    if (!currentContext.mounted) return;

    if (result == true && controller.text.trim().isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', controller.text.trim());

      setState(() {
        _userEmail = controller.text.trim();
      });

      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(
            content: Text('郵箱已更新 ✅'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
        ],
      ),
      body: Container(
        color: AppColor.background,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColor.primary),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildAvatarSection(),
                    const SizedBox(height: 24),
                    _buildProfileCard(),
                    const SizedBox(height: 16),
                    _buildStatisticsCard(),
                    const SizedBox(height: 16),
                    _buildSettingsCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  // ========== 頭像區域 ==========
  Widget _buildAvatarSection() {
    return GestureDetector(
      onTap: _showAvatarPicker,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[800],
                  border: Border.all(color: AppColor.primary, width: 3),
                ),
                child: ClipOval(
                  child: _avatarPath != null && File(_avatarPath!).existsSync()
                      ? Image.file(
                          File(_avatarPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar();
                          },
                        )
                      : _buildDefaultAvatar(),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColor.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: AppColor.text,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '點擊更換頭像',
            style: TextStyle(fontSize: 12, color: AppColor.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(Icons.person, size: 50, color: AppColor.textSecondary),
    );
  }

  // ========== 個人資料卡片 ==========
  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildProfileItem(
            icon: Icons.person_outline,
            label: '名稱',
            value: _userName,
            onTap: _editName,
          ),
          const Divider(color: Colors.grey, height: 1),
          _buildProfileItem(
            icon: Icons.email_outlined,
            label: '郵箱',
            value: _userEmail,
            onTap: _editEmail,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: AppColor.primary, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColor.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 14, color: AppColor.text),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              color: AppColor.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ========== 統計卡片 ==========
  Widget _buildStatisticsCard() {
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
            '統計概覽',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColor.text,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem(
                label: '總支出',
                value: '\$${_totalExpense.toStringAsFixed(0)}',
                color: Colors.redAccent,
              ),
              _buildStatItem(
                label: '總收入',
                value: '\$${_totalIncome.toStringAsFixed(0)}',
                color: Colors.greenAccent,
              ),
              _buildStatItem(
                label: '記錄筆數',
                value: '$_totalRecords',
                color: AppColor.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColor.textSecondary),
          ),
        ],
      ),
    );
  }

  // ========== 設定選項 ==========
  Widget _buildSettingsCard() {
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
            '設定',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColor.text,
            ),
          ),
          const SizedBox(height: 8),

          // ✅ 獨立開關 1：自動記錄（控制是否記錄）
          _buildSettingsItem(
            icon: Icons.play_circle_outline,
            label: '自動記錄',
            trailing: Switch(
              value: _autoRecordEnabled,
              onChanged: _toggleAutoRecord,
              activeThumbColor: AppColor.primary,
            ),
          ),

          // ✅ 獨立開關 2：AI 分類（控制分類方式，僅當自動記錄開啟時可操作）
          _buildSettingsItem(
            icon: Icons.psychology_outlined,
            label: 'AI 分類',
            trailing: Switch(
              value: _aiClassificationEnabled,
              onChanged: _autoRecordEnabled ? _toggleAIClassification : null,
              activeThumbColor: AppColor.primary,
            ),
          ),

          // ✅ 顯示當前分類方式（狀態顯示）
          _buildSettingsItem(
            icon: Icons.info_outline,
            label: '分類方式',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: !_autoRecordEnabled
                    ? Colors.grey.withValues(alpha: 0.2)
                    : _aiClassificationEnabled
                    ? AppColor.primary.withValues(alpha: 0.2)
                    : Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                !_autoRecordEnabled
                    ? '⏸️ 已停用'
                    : _aiClassificationEnabled
                    ? '🤖 AI 分類'
                    : '📋 規則表分類',
                style: TextStyle(
                  fontSize: 12,
                  color: !_autoRecordEnabled
                      ? Colors.grey
                      : _aiClassificationEnabled
                      ? AppColor.primary
                      : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          _buildSettingsItem(
            icon: Icons.notifications_active_outlined,
            label: '後台常駐通知',
            trailing: Switch(
              value: _backgroundNotificationEnabled,
              onChanged: _toggleBackgroundNotification,
              activeThumbColor: AppColor.primary,
            ),
          ),

          _buildSettingsItem(
            icon: Icons.notifications_outlined,
            label: '預算提醒',
            trailing: Switch(
              value: true,
              onChanged: (value) {},
              activeThumbColor: AppColor.primary,
            ),
          ),
          _buildSettingsItem(
            icon: Icons.lock_outline,
            label: '隱私設定',
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColor.textSecondary,
            ),
          ),
          _buildSettingsItem(
            icon: Icons.info_outline,
            label: '關於',
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColor.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String label,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColor.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppColor.text),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
