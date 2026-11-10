import 'package:flutter/material.dart';

import '../../app/config.dart';
import '../../app/theme.dart';
import '../../data/app_repository.dart';
import '../../data/app_scope.dart';
import '../../main.dart';
import '../../widgets/common.dart';
import '../../widgets/shaker.dart';

/// 00 ログイン
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _signIn() async {
    await _run(() => AppScope.of(context).signIn());
  }

  /// 開発用：Firebase なしで `dev:<uid>:<名前>` のトークンを使ってログインする。
  /// ローカルのバックエンド（AUTH_MODE=dev）に対して動作を確かめるため
  Future<void> _signInForDevelopment(AppRepository repo) async {
    final input = await showDialog<({String uid, String name})>(
      context: context,
      builder: (context) => const _DevSignInDialog(),
    );
    if (input == null || !mounted) return;
    await _run(
      () => repo.signInForDevelopment(uid: input.uid, name: input.name),
    );
  }

  Future<void> _run(Future<void> Function() signIn) async {
    setState(() => _loading = true);
    try {
      await signIn();
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 220,
                height: 220,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.cheerSoft,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: 156,
                  height: 156,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x59FF7A1A),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const ShakerBottle(mix: 1, height: 108),
                ),
              ),
              const SizedBox(height: 28),
              Text(appTitle, style: AppFonts.heading(32)),
              const SizedBox(height: 12),
              const Text(
                'シェイカーを振ったら、今日の筋トレ完了。\n友達と同時に振って、乾杯しよう。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.7,
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _FeatureChip(
                    leading: ShakerIcon(size: 16, liquidColor: AppColors.cocoa),
                    label: '振ってスタンプ',
                  ),
                  _FeatureChip(
                    leading: Icon(
                      AppIcons.cheer,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: '友達と乾杯',
                  ),
                  _FeatureChip(
                    leading: Icon(
                      AppIcons.flame,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: '毎日つづく',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Google でログイン'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Google アカウントでかんたんに始められます',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (AppConfig.devTools && repo.supportsDevSignIn)
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => _signInForDevelopment(repo),
                  child: const Text(
                    '（開発用）Firebase なしでログイン',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 開発用ログインの入力（uid と名前）。同じ uid なら同じ人として記録が続く
class _DevSignInDialog extends StatefulWidget {
  const _DevSignInDialog();

  @override
  State<_DevSignInDialog> createState() => _DevSignInDialogState();
}

class _DevSignInDialogState extends State<_DevSignInDialog> {
  final _uid = TextEditingController(text: 'u1');
  final _name = TextEditingController(text: 'こうたろう');

  @override
  void dispose() {
    _uid.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('開発用ログイン'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _uid,
            decoration: const InputDecoration(labelText: 'uid（例：u1）'),
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '名前'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('やめる'),
        ),
        FilledButton(
          onPressed: () {
            final uid = _uid.text.trim();
            if (uid.isEmpty) return;
            Navigator.pop(context, (uid: uid, name: _name.text.trim()));
          },
          child: const Text('ログイン'),
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.leading, required this.label});

  final Widget leading;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
