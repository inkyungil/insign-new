// lib/app.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:insign/core/constants.dart';

class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({required this.child, super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}


class _AppShellState extends State<AppShell> {
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/contracts')) return 1;
    if (location.startsWith('/templates')) return 2;
    if (location.startsWith('/events')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/contracts');
        break;
      case 2:
        context.go('/templates');
        break;
      case 3:
        context.go('/events');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
            currentIndex: _calculateSelectedIndex(context),
            onTap: (idx) => _onItemTapped(idx, context),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
              BottomNavigationBarItem(icon: Icon(Icons.description_outlined), label: '계약'),
              BottomNavigationBarItem(icon: Icon(Icons.layers_outlined), label: '템플릿'),
              BottomNavigationBarItem(icon: Icon(Icons.celebration_outlined), label: '이벤트'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이'),
            ],
            type: BottomNavigationBarType.fixed,
            selectedItemColor: primaryColor,
            unselectedItemColor: Colors.grey,
            backgroundColor: Colors.white,
          ),
    );
  }
}
