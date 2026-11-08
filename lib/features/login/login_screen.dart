import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_scope.dart';
import '../../main.dart';
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
    setState(() => _loading = true);
    try {
      await AppScope.of(context).signIn();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appTitle,
                style: AppFonts.heading(16, color: AppColors.primary),
              ),
              const Spacer(),
              const ShakerBottle(mix: 1, height: 150),
              const SizedBox(height: 28),
              Text('振って、\n乾杯。', style: AppFonts.heading(64).copyWith(height: 1.05)),
              const SizedBox(height: 18),
              const Text(
                'シェイカーを振ったら、今日の筋トレは完了。\n友達と同時に振れば乾杯になる。',
                style: TextStyle(fontSize: 15, height: 1.75, color: AppColors.muted),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text('Google でログイン'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
