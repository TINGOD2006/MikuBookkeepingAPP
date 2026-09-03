import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/app_colors.dart';

class PermissionDialog extends StatelessWidget {
  const PermissionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColor.background,
      title: const Text('需要通知權限', style: TextStyle(color: AppColor.text)),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_active, size: 64, color: AppColor.primary),
          SizedBox(height: 16),
          Text(
            '為了實現自動記帳功能，請允許 App 讀取通知權限。\n\n'
            'App 會監聽支付通知並自動分類記錄。',
            style: TextStyle(color: AppColor.text),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () async {
            // ✅ 保存 context 引用
            final BuildContext currentContext = context;

            // 打開系統設定
            await openAppSettings();

            // ✅ 檢查 context 是否仍然有效
            if (currentContext.mounted) {
              Navigator.pop(currentContext);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColor.primary),
          child: const Text('前往設定'),
        ),
      ],
    );
  }
}
