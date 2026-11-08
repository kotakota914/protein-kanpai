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
      backgroundColor: AppColors.surface,
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
      if (mounted) _toast('読み取れませんでした。もう一度撮ってください');
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
                            border: Border.all(color: AppColors.line, width: 1.5),
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
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('好きなプロテイン', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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
                      child: const ShakerIcon(size: 32, liquidColor: AppColors.cocoa),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fav == null ? 'まだ登録していません' : '${fav.name} ${fav.flavor}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            fav == null
                                ? '袋の写真を撮ると自動で登録できます'
                                : '1食あたり たんぱく質 ${fav.proteinGrams}g',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
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
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    Text('今週のふりかえり', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(repo.weeklySummary, style: const TextStyle(fontSize: 13, height: 1.65)),
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
            child: const Text('ログアウト', style: TextStyle(color: AppColors.muted)),
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
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
