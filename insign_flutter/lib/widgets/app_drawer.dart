import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:insign/features/auth/cubit/auth_cubit.dart';
import 'package:insign/core/constants.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              final user = state.user;
              final displayName = (user?.displayName?.isNotEmpty ?? false)
                  ? user!.displayName!
                  : '사용자';
              final email = user?.email ?? '로그인이 필요합니다';
              final firstLetter = displayName.isNotEmpty ? displayName[0] : 'U';
              
              return UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      softBlue,
                    ],
                  ),
                ),
                accountName: Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                accountEmail: Text(
                  email,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage:
                      user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                  child: user?.avatarUrl == null
                      ? Text(
                          firstLetter,
                          style: const TextStyle(
                            fontSize: 40.0,
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined, color: primaryColor),
            title: const Text(
              '홈',
              style: TextStyle(
                color: black55,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () {
              context.pop();
              context.go('/home');
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined, color: primaryColor),
            title: const Text(
              '계약',
              style: TextStyle(
                color: black55,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () {
              context.pop();
              context.go('/contracts');
            },
          ),
          ListTile(
            leading: const Icon(Icons.layers_outlined, color: primaryColor),
            title: const Text(
              '템플릿',
              style: TextStyle(
                color: black55,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () {
              context.pop();
              context.go('/templates');
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline, color: primaryColor),
            title: const Text(
              '마이',
              style: TextStyle(
                color: black55,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () {
              context.pop();
              context.go('/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline, color: primaryColor),
            title: const Text(
              '고객센터 (챗봇)',
              style: TextStyle(
                color: black55,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () {
              context.pop();
              context.go('/chatbot');
            },
          ),
          ListTile(
            leading: Icon(
              Icons.settings,
              color: primaryColor,
            ),
            title: const Text(
              '설정',
              style: TextStyle(
                color: black55,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () {
              context.pop();
              context.go('/settings');
            },
          ),
          const Divider(
            color: softGrey,
            thickness: 1,
          ),
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              if (state.isLoggedIn) {
                return ListTile(
                  leading: Icon(
                    Icons.logout,
                    color: assentColor,
                  ),
                  title: Text(
                    '로그아웃',
                    style: TextStyle(
                      color: assentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () async {
                    await context.read<AuthCubit>().logout();
                    context.pop();
                    context.go('/splash');
                  },
                );
              } else {
                return ListTile(
                  leading: Icon(
                    Icons.login,
                    color: primaryColor,
                  ),
                  title: const Text(
                    '로그인',
                    style: TextStyle(
                      color: black55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    context.pop();
                    context.go('/auth/login');
                  },
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
