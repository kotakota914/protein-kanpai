import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_repository.dart';
import '../../data/app_scope.dart';
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
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('写真から選ぶ', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                _pickAvatar(repo);
                Navigator.pop(sheetContext);
              },
            ),
            if (repo.avatar != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.muted),
                title: const Text('写真を外す'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  repo.clearAvatar();
                  _toast('アイコンの写真を外しました');
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
    } catch (_) {
      if (mounted) _toast('この写真は読み込めません。JPEG か PNG の写真を選んでください');
    }
  }

  /// TODO(frontend): 袋の写真を撮り、バックエンド（Gemini）へ送る
  Future<void> _scan(AppRepository repo) async {
    setState(() => _scanning = true);
    try {
      await repo.scanProtein();
    } catch (_) {
      if (mounted) _toast('読み取れませんでした。袋の文字が写るように撮り直してください');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final fav = repo.favoriteProtein;

    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
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
                        textColor: AppColors.onPrimary,
                        size: 80,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.background, width: 3),
                          ),
                          child: const Icon(
                            Icons.photo_camera,
                            size: 14,
                            color: AppColors.background,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(repo.userName, style: AppFonts.heading(28)),
                    const Text(
                      'アイコンを押すと写真を変えられる',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Stat(value: '${repo.streak}', label: '日連続'),
              _Stat(value: '${repo.totalDays}', label: '日 合計'),
              _Stat(value: '${repo.totalCheers}', label: '回 乾杯'),
              _Stat(value: '${repo.points}', label: 'pt'),
            ],
          ),
          const SizedBox(height: 22),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        '好きなプロテイン',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Pill(
                      label: 'Gemini で読み取り',
                      icon: AppIcons.gemini,
                      background: AppColors.primarySoft,
                      foreground: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const IconBadge(
                      size: 52,
                      background: AppColors.background,
                      child: ShakerIcon(size: 30, liquidColor: AppColors.cocoa),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fav == null ? 'まだ登録していない' : '${fav.name} ${fav.flavor}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            fav == null
                                ? '袋の写真を撮ると、商品名・味・たんぱく質量が入る'
                                : '1食あたり たんぱく質 ${fav.proteinGrams}g',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _scanning ? null : () => _scan(repo),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  icon: _scanning
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.camera),
                  label: Text(_scanning ? 'Gemini が読み取り中' : '袋の写真から登録'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(AppIcons.gemini, size: 18, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text('今週のふりかえり', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(repo.weeklySummary, style: const TextStyle(fontSize: 14, height: 1.7)),
                const SizedBox(height: 6),
                const Text(
                  'Gemini が記録をもとに作成',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: repo.signOut,
              child: const Text('ログアウト', style: TextStyle(color: AppColors.muted)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppFonts.heading(30, color: AppColors.primary)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}
