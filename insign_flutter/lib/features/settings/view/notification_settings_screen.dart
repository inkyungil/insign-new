import 'package:flutter/material.dart';
import 'package:insign/core/widgets/custom_app_bar.dart';
import 'package:insign/data/services/notification_preferences_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _loading = true;
  bool _appNotifications = true;
  bool _contractUpdates = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await NotificationPreferencesService.loadPreferences();
    if (!mounted) {
      return;
    }
    setState(() {
      _appNotifications = preferences.appNotifications;
      _contractUpdates = preferences.contractUpdates;
      _loading = false;
    });
  }

  Future<void> _updateAppNotifications(bool value) async {
    setState(() {
      _appNotifications = value;
      if (!value) {
        _contractUpdates = false;
      }
      _saving = true;
    });
    await NotificationPreferencesService.setAppNotifications(value);
    if (!value) {
      await NotificationPreferencesService.setContractUpdates(false);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
    });
    _showSnackBar(value ? '앱 알림을 켰어요.' : '앱 알림을 껐어요.');
  }

  Future<void> _updateContractUpdates(bool value) async {
    if (!_appNotifications && value) {
      setState(() {
        _appNotifications = true;
      });
      await NotificationPreferencesService.setAppNotifications(true);
      _showSnackBar('앱 알림을 함께 켰어요.');
    }
    setState(() {
      _contractUpdates = value;
      _saving = true;
    });
    await NotificationPreferencesService.setContractUpdates(value);
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
    });
    _showSnackBar(value ? '계약 진행 알림을 켰어요.' : '계약 진행 알림을 껐어요.');
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _loading || _saving;

    return Scaffold(
      appBar: const CustomAppBar(title: '알림 설정'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildSection(
                  title: '알림 기본 설정',
                  subtitle: '앱 내 알림 수신 여부를 관리합니다.',
                  children: [
                    _buildSwitchTile(
                      title: '앱 알림 수신',
                      subtitle: '푸시와 인앱 알림을 모두 포함합니다.',
                      value: _appNotifications,
                      onChanged: isBusy ? null : (value) => _updateAppNotifications(value),
                    ),
                  ],
                ),
                _buildSection(
                  title: '계약 & 투자',
                  subtitle: '핵심 작업과 상태 변경을 알려드려요.',
                  children: [
                    _buildSwitchTile(
                      title: '계약 진행 알림',
                      subtitle: '계약 생성, 서명 요청, 상태 변경 시 안내합니다.',
                      value: _contractUpdates,
                      onChanged: isBusy ? null : (value) => _updateContractUpdates(value),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool)? onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged == null ? null : (selected) => onChanged(selected),
      ),
    );
  }
}
