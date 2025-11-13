import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:insign/core/widgets/custom_app_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/home');
        }
        return false;
      },
      child: Scaffold(
        appBar: const CustomAppBar(title: '설정'),
        body: ListView(
          children: [
            _buildSection(
              title: '내 정보',
              children: [
                _buildSettingItem(
                  title: '회원 정보',
                  onTap: () => context.push('/settings/member-info'),
                ),
                _buildSettingItem(
                  title: '알림 설정',
                  onTap: () => context.push('/settings/notifications'),
                ),
              ],
            ),
            _buildSection(
              title: '서비스',
              children: [
                _buildSettingItem(
                  title: '개인정보 처리 방침',
                  onTap: () => context.go('/privacy-policy'),
                ),
                _buildSettingItem(
                  title: '이용약관',
                  onTap: () => context.go('/terms-of-service'),
                ),
              ],
            ),
            _buildSection(
              title: '',
              children: [
                _buildSettingItem(
                  title: '로그아웃',
                  textColor: Colors.red,
                  onTap: () => _showLogoutDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ...children,
        if (title.isNotEmpty)
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.shade200,
          ),
      ],
    );
  }

  Widget _buildSettingItem({
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
    Color? textColor,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: textColor ?? Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing ?? Icon(
        Icons.chevron_right,
        color: Colors.grey.shade400,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      minVerticalPadding: 16,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('로그아웃 기능은 준비 중입니다.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text(
                '로그아웃',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
