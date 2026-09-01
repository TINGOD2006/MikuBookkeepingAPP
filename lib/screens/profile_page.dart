import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ 加入 ProfilePage 專屬的 AppBar
      appBar: AppBar(
        title: const Text('我的'),
        centerTitle: true,
      ),
      body: Container(
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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColor.text,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'user@example.com',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColor.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}