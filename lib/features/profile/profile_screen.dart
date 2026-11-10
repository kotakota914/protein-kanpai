import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/achievements.dart';
import '../../data/api_client.dart';
import '../../data/app_repository.dart';
import '../../data/app_scope.dart';
import '../../data/models.dart';
import '../../photo/photo_picker.dart';
import '../../widgets/common.dart';
import '../../widgets/shaker.dart';

/// 06 プロフィール：アイコン・記録・好きなプロテイン・Gemini のふりかえり
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _scanning = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// アイコンを押したとき：写真を選ぶ／外す
  ///
  /// ブラウザはタップの直後でないとファイル選択を開けないため、
  /// メニューの項目を押した処理の中で、そのまま写真選択を開く。
  Future<void> _editAvatar(AppRepository repo) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
              ),
              title: const Text(
                '写真から選ぶ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () {
                _pickAvatar(repo);
                Navigator.pop(sheetContext);
              },
            ),
            if (repo.hasAvatar)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.muted,
                ),
                title: const Text('写真を外す'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _clearAvatar(repo);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _clearAvatar(AppRepository repo) async {
    try {
      await repo.clearAvatar();
      if (mounted) _toast('アイコンの写真を外しました');
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    }
  }

  Future<void> _pickAvatar(AppRepository repo) async {
    final Uint8List? source;
    try {
      source = await pickPhotoBytes(); // await より先にファイル選択を開く
    } on PhotoTooLargeException {
      _toast('写真が大きすぎます（15MB まで）。別の写真を選んでください');
      return;
    } catch (_) {
      _toast('写真を開けませんでした。別の写真を選んでください');
      return;
    }
    if (source == null || !mounted) return; // 選ぶのをやめた
    try {
      // アイコンは小さく表示するだけなので、長い辺 320px に縮めて保存する
      final small = await shrinkPhoto(source);
      await repo.setAvatar(small);
      if (mounted) _toast('アイコンを変更しました');
    } on ArgumentError {
      if (mounted) _toast('写真が大きすぎます。別の写真を選んでください');
    } on ApiException catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } catch (_) {
      if (mounted) _toast('この写真は読み込めません。JPEG か PNG の写真を選んでください');
    }
  }

  /// 袋の写真を選び、Gemini に読み取ってもらい、確認してから保存する。
  ///
  /// 読み取った結果はサーバーに保存されないので（契約の POST /protein/scan）、
  /// 中身を見せて「登録する」と言われてから PUT /me/favorite-protein で保存する。
  Future<void> _scan(AppRepository repo) async {
    final Uint8List? photo;
    try {
      photo = await pickPhotoBytes(); // await より先にファイル選択を開く
    } on PhotoTooLargeException {
      _toast('写真が大きすぎます（15MB まで）。別の写真を選んでください');
      return;
    } catch (_) {
      _toast('写真を開けませんでした。別の写真を選んでください');
      return;
    }
    if (photo == null || !mounted) return; // 選ぶのをやめた

    setState(() => _scanning = true);
    final Protein protein;
    try {
      protein = await repo.scanProtein(photo);
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
      return;
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ScanResultDialog(protein: protein),
    );
    if (confirmed != true || !mounted) return;
    try {
      await repo.saveFavoriteProtein(protein);
      if (mounted) _toast('好きなプロテインを登録しました');
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final fav = repo.favoriteProtein;

    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'アイコンを変更',
                child: GestureDetector(
                  onTap: () => _editAvatar(repo),
                  child: Stack(
                    children: [
                      Avatar(
                        initial: repo.userInitial,
                        photo: repo.avatar,
                        color: AppColors.primary,
                        size: 68,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.line,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.photo_camera,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(repo.userName, style: AppFonts.heading(22)),
                    const Text(
                      'アイコンを押すと写真を変えられます',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(label: '連続', value: '${repo.streak}日'),
              const SizedBox(width: 8),
              _Stat(label: '合計', value: '${repo.totalDays}日'),
              const SizedBox(width: 8),
              _Stat(label: '乾杯', value: '${repo.totalCheers}回'),
              const SizedBox(width: 8),
              _Stat(label: 'ポイント', value: '${repo.points}'),
            ],
          ),
          const SizedBox(height: 12),
          _AchievementBoard(earned: repo.earnedAchievementIds),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '好きなプロテイン',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Pill(
                      label: 'Gemini で読み取り',
                      icon: AppIcons.gemini,
                      background: AppColors.cheerSoft,
                      iconColor: AppColors.gold,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: ShakerIcon(
                        size: 32,
                        liquidColor: repo.liquidColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fav == null
                                ? 'まだ登録していません'
                                : '${fav.name} ${fav.flavor}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            fav == null
                                ? '袋の写真を撮ると自動で登録できます'
                                : '1食あたり たんぱく質 ${fav.proteinGrams}g',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _scanning ? null : () => _scan(repo),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: _scanning
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.camera),
                  label: Text(_scanning ? 'Gemini が読み取り中…' : '袋の写真から登録する'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'プロテインの袋を撮ると、Gemini が商品名・味・たんぱく質量を読み取ります',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.cheerSoft,
            shadow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(AppIcons.gemini, size: 18, color: AppColors.gold),
                    SizedBox(width: 6),
                    Text(
                      '今週のふりかえり',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  repo.weeklySummary,
                  style: const TextStyle(fontSize: 13, height: 1.65),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Gemini が記録をもとに作成',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: repo.signOut,
            child: const Text(
              'ログアウト',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(
          children: [
            FittedBox(child: Text(value, style: AppFonts.heading(18))),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// バッジの一覧。取ったものは色付き、まだのものは灰色で取り方を出す
class _AchievementBoard extends StatelessWidget {
  const _AchievementBoard({required this.earned});

  final Set<String> earned;

  @override
  Widget build(BuildContext context) {
    final count = achievements.where((a) => earned.contains(a.id)).length;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'バッジ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$count / ${achievements.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const columns = 3;
              const gap = 8.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: 12,
                children: [
                  for (final a in achievements)
                    SizedBox(
                      width: width,
                      child: _AchievementTile(
                        achievement: a,
                        earned: earned.contains(a.id),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.earned});

  final Achievement achievement;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: earned
          ? 'バッジ ${achievement.name} 獲得済み'
          : 'バッジ ${achievement.name} 未獲得。${achievement.howTo}',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconBadge(
                  icon: achievement.icon,
                  size: 52,
                  background: earned ? AppColors.cheer : AppColors.line,
                  foreground: earned ? AppColors.ink : AppColors.muted,
                ),
                if (!earned)
                  const Positioned(
                    right: -2,
                    bottom: -2,
                    child: Icon(
                      Icons.lock_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              achievement.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: earned ? AppColors.ink : AppColors.muted,
              ),
            ),
            if (!earned)
              Text(
                achievement.howTo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.muted,
                  height: 1.3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Gemini が読み取った内容を見せて、登録するかを聞く
class _ScanResultDialog extends StatelessWidget {
  const _ScanResultDialog({required this.protein});

  final Protein protein;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('この内容で登録しますか？'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${protein.name} ${protein.flavor}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '1食あたり たんぱく質 ${protein.proteinGrams}g',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          const Text(
            'Gemini が袋の写真から読み取りました。違っていたら撮り直してください。',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('撮り直す'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('登録する'),
        ),
      ],
    );
  }
}
