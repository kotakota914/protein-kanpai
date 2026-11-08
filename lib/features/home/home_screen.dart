import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_repository.dart';
import '../../data/app_scope.dart';
import '../../shake/shake_detector.dart';
import '../../widgets/common.dart';
import '../../widgets/gym.dart';
import '../../widgets/shaker.dart';
import 'shake_result_sheet.dart';

/// 開発用ボタンを出すか。
///
/// 開発中（debug）か、プレビュー用に `--dart-define=DEV_TOOLS=true` を付けて
/// ビルドしたときだけ出す。提出・デモ用のビルドには付けない。
const showDevTools = kDebugMode || bool.fromEnvironment('DEV_TOOLS');

/// 01 / 02 ホーム：シェイカーを振る画面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.detectorFactory = createShakeDetector});

  /// テストで差し替えられるようにしている
  final ShakeDetector Function() detectorFactory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _ShakeState { idle, listening, sending, denied, unsupported }

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final ShakeDetector _detector = widget.detectorFactory();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  _ShakeState _state = _ShakeState.idle;
  double _progress = 0;

  @override
  void dispose() {
    _detector.stop();
    _pulse.dispose();
    super.dispose();
  }

  /// ボタンを押したとき。iPhone の許可を取るため、最初に requestPermission を呼ぶ。
  Future<void> _start() async {
    final permission = _detector.requestPermission();
    if (!_detector.isSupported) {
      setState(() => _state = _ShakeState.unsupported);
      return;
    }
    final granted = await permission;
    if (!mounted) return;
    if (!granted) {
      setState(() => _state = _ShakeState.denied);
      return;
    }
    _detector.start(
      _onShake,
      onProgress: (p) => setState(() => _progress = p.clamp(0, 1)),
    );
    _pulse.repeat(reverse: true);
    setState(() {
      _state = _ShakeState.listening;
      _progress = 0;
    });
  }

  void _cancel() {
    _detector.stop();
    _pulse.stop();
    setState(() => _state = _ShakeState.idle);
  }

  Future<void> _onShake() async {
    if (_state == _ShakeState.sending) return;
    final repo = AppScope.of(context);
    _detector.stop();
    _pulse.stop();
    setState(() {
      _state = _ShakeState.sending;
      _progress = 1;
    });
    final result = await repo.recordShake();
    if (!mounted) return;
    setState(() => _state = _ShakeState.idle);
    await showShakeResultSheet(
      context,
      result,
      myInitial: repo.userInitial,
      myPhoto: repo.avatar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final shaking = repo.shakingFriend;
    final counting =
        _state == _ShakeState.listening || _state == _ShakeState.sending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日のプロテイン'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                const Icon(AppIcons.star, size: 18, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('${repo.points}', style: AppFonts.heading(18)),
                const SizedBox(width: 3),
                const Text('pt', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          _Streak(repo: repo),
          const SizedBox(height: 26),
          Center(
            child: _PlateButton(
              state: _state,
              shookToday: repo.shookToday,
              progress: _progress,
              pulse: _pulse,
              onTap: switch (_state) {
                _ShakeState.listening => _cancel,
                _ShakeState.sending => null,
                _ => _start,
              },
            ),
          ),
          const SizedBox(height: 16),
          _StatusLine(state: _state, hits: (_progress * ShakeDetector.requiredHits).round(), counting: counting),
          if (shaking != null) ...[
            const SizedBox(height: 22),
            AppCard(
              borderColor: AppColors.cheer,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Avatar(
                    initial: shaking.initial,
                    textColor: Avatar.colorFor(shaking.name),
                    ringColor: AppColors.cheer,
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${shaking.name}が振ってる',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const Text(
                          'いま振れば乾杯になる',
                          style: TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const Pill(label: '乾杯OK', icon: AppIcons.cheer),
                ],
              ),
            ),
          ],
          if (showDevTools) ...[
            const SizedBox(height: 18),
            // 開発用：PC では振れないので、振ったことにして画面を確認する。
            // 提出・デモ用のビルドには表示されない（デモ動画には使わない）。
            OutlinedButton(
              onPressed: _state == _ShakeState.sending ? null : _onShake,
              child: const Text('（開発用）振ったことにする'),
            ),
          ],
        ],
      ),
    );
  }
}

/// 大きな連続日数と、今週の「正」の字
class _Streak extends StatelessWidget {
  const _Streak({required this.repo});

  final AppRepository repo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${repo.streak}',
              style: AppFonts.heading(108, color: AppColors.primary)
                  .copyWith(height: 0.95),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('日連続', style: AppFonts.heading(26)),
                  Text(
                    repo.shookToday ? '今日の分は記録済み' : '今日はまだ',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text(
              '今週',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted),
            ),
            const SizedBox(width: 12),
            TallyMarks(count: repo.daysThisWeek),
            const Spacer(),
            Text('${repo.daysThisWeek}', style: AppFonts.heading(20)),
            const Text(' / 7日', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ),
      ],
    );
  }
}

/// バーベルのプレートの形をした振るボタン。外側の輪が振った回数だけ光る。
class _PlateButton extends StatelessWidget {
  const _PlateButton({
    required this.state,
    required this.shookToday,
    required this.progress,
    required this.pulse,
    required this.onTap,
  });

  final _ShakeState state;
  final bool shookToday;

  /// 振った回数の進み具合（0〜1）
  final double progress;
  final Animation<double> pulse;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final listening = state == _ShakeState.listening;
    final counting = listening || state == _ShakeState.sending;
    final label = switch (state) {
      _ShakeState.listening => '振れ！',
      _ShakeState.sending => '記録中',
      _ => shookToday ? 'もう一回' : '押して、振れ',
    };

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) => Transform.scale(
        scale: listening ? 1 + pulse.value * 0.03 : 1,
        child: child,
      ),
      child: PlateRing(
        segments: ShakeDetector.requiredHits,
        lit: counting
            ? progress * ShakeDetector.requiredHits
            : (shookToday ? ShakeDetector.requiredHits.toDouble() : 0),
        size: 292,
        thickness: 18,
        child: Semantics(
          button: true,
          label: label,
          child: Material(
            color: listening ? AppColors.primarySoft : AppColors.surface,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox.square(
                dimension: 232,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShakerBottle(
                      // 振る前は粉が底にたまり、振るほど混ざってココア色になる
                      mix: counting ? progress : (shookToday ? 1 : 0),
                      active: listening,
                      height: 116,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      style: AppFonts.heading(
                        listening ? 30 : 22,
                        color: listening ? AppColors.primary : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state, required this.hits, required this.counting});

  final _ShakeState state;
  final int hits;
  final bool counting;

  @override
  Widget build(BuildContext context) {
    final text = switch (state) {
      _ShakeState.idle => '押してから、シェイカーを ${ShakeDetector.requiredHits}回 しっかり振る',
      _ShakeState.listening => '$hits / ${ShakeDetector.requiredHits} 回（もう一度押すと中止）',
      _ShakeState.sending => '',
      _ShakeState.denied => 'センサーの使用が許可されていません。\n'
          'iPhone は「設定 > Safari」で許可してから、もう一度押してください。',
      _ShakeState.unsupported => 'この端末では振っても検知できません。\nスマホのブラウザで開いてください。',
    };
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        height: 1.5,
        color: counting ? AppColors.ink : AppColors.muted,
        fontWeight: counting ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}
