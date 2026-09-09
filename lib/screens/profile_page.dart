import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../services/storage_service.dart';
import '../services/notification_listener.dart';
import '../services/ai_service.dart';
import '../services/message_service.dart';

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
  bool _budgetNotificationEnabled = true;
  String _aiApiUrl = '';
  String _aiApiKey = '';
  String _aiModel = '';

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStatistics();
    _loadAutoRecordSetting();
    _loadAIClassificationSetting(); // ✅ 新增
    _loadBackgroundNotificationSetting();
    _loadBudgetNotificationSetting();
    _loadAISettings();
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

  Future<void> _loadBudgetNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _budgetNotificationEnabled =
            prefs.getBool('budget_notification_enabled') ?? true;
      });
    }
  }

  Future<void> _loadAISettings() async {
    final config = await AIService.loadConfig();
    if (mounted) {
      setState(() {
        _aiApiUrl = config?.apiUrl ?? '';
        _aiApiKey = config?.apiKey ?? '';
        _aiModel = config?.model ?? '';
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

    MessageService.showSnackBar(
      value ? '✅ 自動記錄已開啟' : 'ℹ️ 自動記錄已關閉',
      color: value ? Colors.green : Colors.orange,
      duration: const Duration(seconds: 2),
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

    MessageService.showSnackBar(
      value ? '🤖 AI 分類已啟用' : '📋 已切換為規則表分類（不消耗 AI 額度）',
      color: value ? Colors.green : Colors.orange,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _toggleBackgroundNotification(bool value) async {
    final currentContext = context;
    await NotificationListenerService.setBackgroundNotificationEnabled(value);

    if (!currentContext.mounted) return;
    setState(() => _backgroundNotificationEnabled = value);
    MessageService.showSnackBar(
      value ? '✅ 後台常駐通知已開啟' : 'ℹ️ 後台常駐通知已關閉',
      color: value ? Colors.green : Colors.orange,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _toggleBudgetNotification(bool value) async {
    final BuildContext currentContext = context;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('budget_notification_enabled', value);

    if (!currentContext.mounted) return;

    setState(() {
      _budgetNotificationEnabled = value;
    });

    MessageService.showSnackBar(
      value ? '🔔 預算提醒已開啟' : '🔕 預算提醒已關閉',
      color: value ? Colors.green : Colors.orange,
      duration: const Duration(seconds: 2),
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
        MessageService.showSnackBar(
          '頭像已更新 ✅',
          color: Colors.green,
        );
      }
    } catch (e) {
      if (!currentContext.mounted) return;

      if (currentContext.mounted) {
        MessageService.showSnackBar(
          '更新頭像失敗: $e',
          color: Colors.red,
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
        MessageService.showSnackBar(
          '名稱已更新 ✅',
          color: Colors.green,
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
        MessageService.showSnackBar(
          '郵箱已更新 ✅',
          color: Colors.green,
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

          // ✅ 新增：AI API 設定（用戶自行填入 API、Key、模型）
          _buildSettingsItem(
            icon: Icons.key_outlined,
            label: 'AI API 設定',
            trailing: TextButton(
              onPressed: _showAISettingsDialog,
              child: const Text(
                '設定',
                style: TextStyle(color: AppColor.primary),
              ),
            ),
          ),
          if (_aiApiUrl.isNotEmpty || _aiApiKey.isNotEmpty || _aiModel.isNotEmpty)
            _buildSettingsItem(
              icon: Icons.badge_outlined,
              label: '目前 AI 設定',
              trailing: Text(
                '${_aiModel.isNotEmpty ? _aiModel : '未設定模型'} ・ '
                '${_aiApiKey.isNotEmpty ? 'Key: ${AIConfig(apiUrl: _aiApiUrl, apiKey: _aiApiKey, model: _aiModel).maskedKey}' : '未設定 Key'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColor.textSecondary,
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

          // ✅ 新增：支付通知白名單包名管理
          _buildSettingsItem(
            icon: Icons.security_outlined,
            label: '支付 APP 包名白名單',
            trailing: TextButton(
              onPressed: _showAllowedPackagesDialog,
              child: const Text('管理', style: TextStyle(color: AppColor.primary)),
            ),
          ),

          _buildSettingsItem(
            icon: Icons.notifications_outlined,
            label: '預算提醒',
            trailing: Switch(
              value: _budgetNotificationEnabled,
              onChanged: _toggleBudgetNotification,
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

  // ========== AI 設定對話框 ==========
  Future<void> _showAISettingsDialog() async {
    final config = await AIService.loadConfig();
    final TextEditingController urlController = TextEditingController(
      text: config?.apiUrl ?? '',
    );
    final TextEditingController keyController = TextEditingController(
      text: config?.apiKey ?? '',
    );
    final TextEditingController modelController = TextEditingController(
      text: config?.model ?? '',
    );
    final BuildContext currentContext = context;

    await showDialog(
      context: currentContext,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColor.background,
          title: const Text(
            'AI 設定',
            style: TextStyle(color: AppColor.text, fontSize: 18),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '請填入你自己的 AI API 設定，用於自動記錄時進行 AI 分類。未設定時將使用本地規則分類。',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'API URL',
                    style: TextStyle(color: AppColor.text, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: urlController,
                    style: const TextStyle(color: AppColor.text, fontSize: 13),
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      hintText: '例如 https://api.openai.com/v1/chat/completions',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'API Key',
                    style: TextStyle(color: AppColor.text, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: keyController,
                    style: const TextStyle(color: AppColor.text, fontSize: 13),
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'sk-...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '模型',
                    style: TextStyle(color: AppColor.text, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: modelController,
                    style: const TextStyle(color: AppColor.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '例如 gpt-4o-mini',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColor.primary),
              onPressed: () async {
                final url = urlController.text.trim();
                final key = keyController.text.trim();
                final model = modelController.text.trim();

                if (url.isEmpty || key.isEmpty || model.isEmpty) {
                  if (currentContext.mounted) {
                    MessageService.showSnackBar(
                      '請完整填寫 API URL、Key 與模型名稱',
                      color: Colors.orange,
                    );
                  }
                  return;
                }

                await AIService.saveConfig(
                  apiUrl: url,
                  apiKey: key,
                  model: model,
                );

                if (currentContext.mounted) {
                  setState(() {
                    _aiApiUrl = url;
                    _aiApiKey = key;
                    _aiModel = model;
                  });
                }

                if (context.mounted) Navigator.pop(context);
                if (currentContext.mounted) {
                  MessageService.showSnackBar(
                    '✅ AI 設定已儲存',
                    color: Colors.green,
                  );
                }
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
  }

  // ========== 管理白名單包名對話框 ==========
  Future<void> _showAllowedPackagesDialog() async {
    List<String> packages = await NotificationListenerService.getAllowedPackages();
    final TextEditingController controller = TextEditingController();
    final BuildContext currentContext = context;

    await showDialog(
      context: currentContext,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColor.background,
              title: const Text(
                '支付 APP 包名白名單',
                style: TextStyle(color: AppColor.text, fontSize: 18),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '僅會讀取並記錄以下包名的支付通知（例如 com.macaupass.rechargeEasy），其他軟體通知將直接過濾不作記錄。',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            style: const TextStyle(color: AppColor.text, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: '輸入包名 (例如 com.example.pay)',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColor.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: () {
                            final text = controller.text.trim();
                            if (text.isNotEmpty && !packages.contains(text)) {
                              setStateDialog(() {
                                packages.add(text);
                                controller.clear();
                              });
                            }
                          },
                          child: const Text('新增'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '目前允許的包名:',
                        style: TextStyle(color: AppColor.text, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: packages.length,
                        itemBuilder: (context, index) {
                          final pkg = packages[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              pkg,
                              style: const TextStyle(color: AppColor.text, fontSize: 13),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () {
                                setStateDialog(() {
                                  packages.removeAt(index);
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColor.primary),
                  onPressed: () async {
                    await NotificationListenerService.setAllowedPackages(packages);
                    if (context.mounted) Navigator.pop(context);
                    if (currentContext.mounted) {
                      MessageService.showSnackBar(
                        '✅ 包名白名單已更新',
                        color: Colors.green,
                      );
                    }
                  },
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
