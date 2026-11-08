import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_repository.dart';
import '../../data/app_scope.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/shaker.dart';

/// 05 友達：タイムラインとフォロー
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  int _tab = 0; // 0: タイムライン, 1: フォロー

  void _invite() {
    // TODO(backend): 招待リンクを発行して共有する
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('招待リンクはまだ作れません（準備中）')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('友達'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _tab = 1),
            tooltip: '友達を追加',
            color: AppColors.primary,
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _Tabs(
            labels: ['タイムライン', 'フォロー中 ${repo.following.length}'],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 20),
          if (_tab == 0) ..._timeline(repo) else ..._followList(repo),
          const SizedBox(height: 20),
          AppCard(
            borderColor: AppColors.primary,
            color: AppColors.background,
            onTap: _invite,
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '友達を誘う',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'フォローし合うと、同時に振ったとき乾杯になる',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Pill(
                  label: '招待リンクを送る',
                  background: AppColors.primary,
                  foreground: AppColors.onPrimary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _timeline(AppRepository repo) {
    final following = repo.following;
    final now = DateTime.now();
    return [
      const SectionLabel('いま振ってる'),
      const SizedBox(height: 12),
      if (following.isEmpty)
        const Text(
          'まだ誰もフォローしていない。右上から友達を追加しよう。',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        )
      else
        Wrap(
          spacing: 20,
          runSpacing: 12,
          children: [for (final f in following) _FriendNow(friend: f)],
        ),
      const SizedBox(height: 26),
      const SectionLabel('タイムライン'),
      const SizedBox(height: 4),
      for (final item in repo.feed) _FeedRow(item: item, now: now),
    ];
  }

  List<Widget> _followList(AppRepository repo) {
    return [
      for (final f in repo.friends)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              Avatar(initial: f.initial, textColor: Avatar.colorFor(f.name), size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  f.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: 112,
                child: f.following
                    ? OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: () => repo.toggleFollow(f.id),
                        child: const Text('フォロー中'),
                      )
                    : FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: () => repo.toggleFollow(f.id),
                        child: const Text('フォロー'),
                      ),
              ),
            ],
          ),
        ),
    ];
  }
}

/// 下線で選択中を示すタブ
class _Tabs extends StatelessWidget {
  const _Tabs({required this.labels, required this.selected, required this.onChanged});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Semantics(
              selected: i == selected,
              button: true,
              child: InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
                  margin: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == selected ? AppColors.primary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: i == selected ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FriendNow extends StatelessWidget {
  const _FriendNow({required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context) {
    final live = friend.shakingNow;
    return Column(
      children: [
        Avatar(
          initial: friend.initial,
          textColor: Avatar.colorFor(friend.name),
          ringColor: live ? AppColors.cheer : null,
          size: 58,
        ),
        const SizedBox(height: 6),
        Text(friend.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        if (live)
          const Pill(label: '振り中')
        else
          Text(
            friend.shookToday ? '今日は済み' : '今日まだ',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
      ],
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.item, required this.now});

  final FeedItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final Widget mark = switch (item.kind) {
      FeedKind.cheer => const Icon(AppIcons.cheer, color: AppColors.cheer, size: 22),
      FeedKind.shake => const ShakerIcon(size: 22, liquidColor: AppColors.cocoa),
      FeedKind.streak => const Icon(AppIcons.flame, color: AppColors.primary, size: 22),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Avatar(
            initial: item.friendName.substring(0, 1),
            textColor: Avatar.colorFor(item.friendName),
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(
                  relativeTime(item.at, now),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          mark,
        ],
      ),
    );
  }
}
