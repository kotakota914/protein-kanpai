import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/app_repository.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/friends/friends_screen.dart';
import '../features/home/home_screen.dart';
import '../features/invite/invite_screen.dart';
import '../features/login/login_screen.dart';
import '../features/profile/profile_screen.dart';
import '../widgets/shaker.dart';
import 'theme.dart';

/// 画面の行き先の一覧。
///
/// ログインしていなければ /login へ、ログイン済みなら下のタブ 4 つで移動する。
/// 招待リンク `/invite/<code>` を開いた人は、ログインしてから同じリンクへ戻す。
GoRouter buildRouter(AppRepository repository) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: repository,
    redirect: (context, state) {
      final atLogin = state.matchedLocation == '/login';
      if (!repository.signedIn) {
        if (atLogin) return null;
        final location = state.uri.toString();
        return isInvitePath(location)
            ? Uri(
                path: '/login',
                queryParameters: {'next': location},
              ).toString()
            : '/login';
      }
      if (atLogin) {
        final next = state.uri.queryParameters['next'];
        // 戻る先は招待リンクだけに限る（外から来た値をそのまま行き先にしない）
        return next != null && isInvitePath(next) ? next : '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/invite/:code',
        builder: (_, state) =>
            InviteScreen(code: state.pathParameters['code']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _TabScaffold(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (_, _) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/friends',
                builder: (_, _) => const FriendsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// `/invite/<code>` の形か（クエリ付きも可）
bool isInvitePath(String location) =>
    RegExp(r'^/invite/[^/?#]+(\?.*)?$').hasMatch(location);

class _TabScaffold extends StatelessWidget {
  const _TabScaffold({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: ShakerIcon(color: AppColors.muted, fill: 0),
            selectedIcon: ShakerIcon(liquidColor: AppColors.cocoa),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'カレンダー',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: '友達',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'プロフィール',
          ),
        ],
      ),
    );
  }
}
