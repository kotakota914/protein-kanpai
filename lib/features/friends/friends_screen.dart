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
      const SnackBar(content: Text('招待リンクの共有は準備中です')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('友達'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              onPressed: () => setState(() => _tab = 1),
              tooltip: '友達を追加',
              icon: const Icon(Icons.person_add_alt_1_outlined),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primarySoft,
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        children: [
          _Segmented(
            labels: ['タイムライン', 'フォロー中 ${repo.following.length}'],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 16),
          if (_tab == 0) ..._timeline(repo) else ..._followList(repo),
          const SizedBox(height: 16),
          AppCard(
            color: AppColors.primarySoft,
            shadow: false,
            onTap: _invite,
            child: const Row(
              children: [
                Icon(Icons.link_rounded, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '友達を招待しよう',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '招待リンクを送ると、乾杯できるようになります',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Pill(
                  label: 'リンクを送る',
                  background: AppColors.primary,
                  foreground: Colors.white,
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
      const SectionLabel('いま振っている友達'),
      const SizedBox(height: 10),
      if (following.isEmpty)
        const Text(
          'まだ誰もフォローしていません',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        )
      else
        Wrap(
          spacing: 18,
          runSpacing: 12,
          children: [for (final f in following) _ShakingFriend(friend: f)],
        ),
      const SizedBox(height: 20),
      const SectionLabel('タイムライン'),
      const SizedBox(height: 10),
      for (final item in repo.feed) ...[
        _FeedTile(item: item, now: now),
        const SizedBox(height: 10),
      ],
    ];
  }

  List<Widget> _followList(AppRepository repo) {
    return [
      for (final f in repo.friends) ...[
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Avatar(initial: f.initial, color: Avatar.colorFor(f.name), size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  f.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              f.following
                  ? OutlinedButton(
                      onPressed: () => repo.toggleFollow(f.id),
                      child: const Text('フォロー中'),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
                      onPressed: () => repo.toggleFollow(f.id),
                      child: const Text('フォロー'),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.line.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
                        color: i == selected ? AppColors.ink : AppColors.muted,
                      ),
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

class _ShakingFriend extends StatelessWidget {
  const _ShakingFriend({required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context) {
    final live = friend.shakingNow;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: live ? AppColors.cheer : AppColors.line,
              width: live ? 3 : 2,
            ),
          ),
          child: Avatar(
            initial: friend.initial,
            color: Avatar.colorFor(friend.name),
            size: 54,
          ),
        ),
        const SizedBox(height: 6),
        Text(friend.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        if (live)
          const Pill(
            label: '振り中',
            leading: ShakerIcon(size: 14, color: AppColors.ink, liquidColor: AppColors.cocoa),
          )
        else
          Text(
            friend.shookToday ? '今日済み' : '今日まだ',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
      ],
    );
  }
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({required this.item, required this.now});

  final FeedItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final badge = switch (item.kind) {
      FeedKind.cheer => const IconBadge(
          icon: AppIcons.cheer,
          size: 32,
          background: AppColors.cheerSoft,
          foreground: AppColors.ink,
        ),
      FeedKind.shake => const IconBadge(
          size: 32,
          background: AppColors.primarySoft,
          child: ShakerIcon(size: 18, liquidColor: AppColors.cocoa),
        ),
      FeedKind.streak => const IconBadge(icon: AppIcons.flame, size: 32),
    };
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Avatar(
            initial: item.friendName.substring(0, 1),
            color: Avatar.colorFor(item.friendName),
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Text(
                  relativeTime(item.at, now),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          badge,
        ],
      ),
    );
  }
}
