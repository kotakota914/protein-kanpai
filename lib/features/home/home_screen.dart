import 'package:flutter/material.dart';

import '../../app/config.dart';
import '../../app/theme.dart';
import '../../data/app_repository.dart';
import '../../data/app_scope.dart';
import '../../data/growth.dart';
import '../../data/models.dart';
import '../../shake/shake_detector.dart';
import '../../widgets/common.dart';
import '../../widgets/mascot.dart';
import '../../widgets/shaker.dart';
import 'shake_result_sheet.dart';

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
    duration: const Duration(milliseconds: 700),
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
    final ShakeResult result;
    try {
      result = await repo.recordShake();
    } catch (error) {
      // 429（連打）や通信失敗。記録はされていないので、文言を出して振る前に戻す
      if (!mounted) return;
      setState(() => _state = _ShakeState.idle);
      showErrorSnackBar(context, error);
      return;
    }
    if (!mounted) return;
    setState(() => _state = _ShakeState.idle);
    await showShakeResultSheet(
      context,
      result,
      myInitial: repo.userInitial,
      myPhoto: repo.avatar,
      liquidColor: repo.liquidColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final listening = _state == _ShakeState.listening;
    final shaking = repo.shakingFriend;

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日のプロテイン'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Pill(
              label: '${repo.points} pt',
              icon: AppIcons.star,
              background: AppColors.cheerSoft,
              iconColor: AppColors.gold,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _StreakCard(repo: repo),
          const SizedBox(height: 12),
          _CharacterCard(repo: repo),
          const SizedBox(height: 28),
          Center(
            child: _ShakeButton(
              state: _state,
              shookToday: repo.shookToday,
              progress: _progress,
              liquidColor: repo.liquidColor,
              pulse: _pulse,
              onTap: switch (_state) {
                _ShakeState.listening => _cancel,
                _ShakeState.sending => null,
                _ => _start,
              },
            ),
          ),
          const SizedBox(height: 20),
          if (listening || _state == _ShakeState.sending) ...[
            _ShakeProgress(progress: _progress),
            const SizedBox(height: 10),
          ],
          _HintText(state: _state),
          if (shaking != null) ...[
            const SizedBox(height: 20),
            AppCard(
              borderColor: AppColors.cheer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Avatar(
                    initial: shaking.initial,
                    photo: repo.avatarOf(shaking),
                    color: AppColors.primarySoft,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${shaking.name}さんが振っています',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'いま振ると乾杯できるよ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Pill(label: '乾杯OK', icon: AppIcons.cheer),
                ],
              ),
            ),
          ],
          if (AppConfig.devTools) ...[
            const SizedBox(height: 20),
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

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.repo});

  final AppRepository repo;

  @override
  Widget build(BuildContext context) {
    final today = repo.today;
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const IconBadge(icon: AppIcons.flame),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${repo.streak}日連続', style: AppFonts.heading(24)),
                    Text(
                      repo.shookToday ? '今日のスタンプ：ゲット済み' : '今日のスタンプ：まだ',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                _DayDot(
                  label: weekdayLabels[i],
                  day: monday.add(Duration(days: i)),
                  today: today,
                  done: repo.logs.containsKey(monday.add(Duration(days: i))),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// シェイカーくん：振った日数で 5 段階に育つ
class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.repo});

  final AppRepository repo;

  @override
  Widget build(BuildContext context) {
    final stage = repo.stage;
    final next = nextStageAfter(stage);
    final days = repo.totalDays;
    final progress = next == null
        ? 1.0
        : (days - stage.minDays) / (next.minDays - stage.minDays);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 18, 12),
      child: Row(
        children: [
          Mascot(level: stage.level, size: 92, liquidColor: repo.liquidColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'シェイカーくん Lv.${stage.level}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                Text(stage.name, style: AppFonts.heading(22)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: AppColors.line,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  next == null
                      ? '最高段階！ 振った日 $days日'
                      : 'あと ${next.minDays - days}日 振ると「${next.name}」',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.day,
    required this.today,
    required this.done,
  });

  final String label;
  final DateTime day;
  final DateTime today;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final isToday = day == today;
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? AppColors.primary
                : (isToday
                      ? AppColors.surface
                      : AppColors.line.withValues(alpha: 0.6)),
            border: isToday && !done
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
              : null,
        ),
      ],
    );
  }
}

class _ShakeButton extends StatelessWidget {
  const _ShakeButton({
    required this.state,
    required this.shookToday,
    required this.progress,
    required this.liquidColor,
    required this.pulse,
    required this.onTap,
  });

  final _ShakeState state;
  final bool shookToday;

  /// 好きなプロテインの味の色
  final Color liquidColor;

  /// 振った回数の進み具合（0〜1）。シェイカーの中身の混ざり具合に使う
  final double progress;
  final Animation<double> pulse;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final listening = state == _ShakeState.listening;
    final label = switch (state) {
      _ShakeState.listening => 'シェイカーを\n振って！',
      _ShakeState.sending => '記録中…',
      _ => shookToday ? 'もう一回\n振る' : 'タップして\n準備',
    };
    final coreColor = listening ? AppColors.cheer : AppColors.primary;
    final textColor = listening ? AppColors.ink : Colors.white;

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) => Transform.scale(
        scale: listening ? 1 + pulse.value * 0.05 : 1,
        child: child,
      ),
      child: Container(
        width: 280,
        height: 280,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: listening ? AppColors.cheerSoft : AppColors.primarySoft,
        ),
        child: Container(
          width: 252,
          height: 252,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: listening
                ? AppColors.cheer.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
          child: Semantics(
            button: true,
            label: label.replaceAll('\n', ''),
            child: Material(
              color: coreColor,
              shape: const CircleBorder(),
              elevation: 8,
              shadowColor: coreColor.withValues(alpha: 0.6),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox.square(
                  dimension: 224,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ShakerBottle(
                        // 振る前は粉が底にたまり、振るほど混ざってココア色になる
                        mix: switch (state) {
                          _ShakeState.listening ||
                          _ShakeState.sending => progress,
                          _ => shookToday ? 1 : 0,
                        },
                        active: listening,
                        height: 112,
                        liquidColor: liquidColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppFonts.heading(19, color: textColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShakeProgress extends StatelessWidget {
  const _ShakeProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final hits = (progress * ShakeDetector.requiredHits).round();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'シェイク検知中…',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            Text(
              '$hits / ${ShakeDetector.requiredHits}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: AppColors.line,
            color: AppColors.cheer,
          ),
        ),
      ],
    );
  }
}

class _HintText extends StatelessWidget {
  const _HintText({required this.state});

  final _ShakeState state;

  @override
  Widget build(BuildContext context) {
    final text = switch (state) {
      _ShakeState.idle => 'ボタンを押してから、シェイカーを持って振ってね',
      _ShakeState.listening => 'しっかり振ると記録されます（もう一度タップで中止）',
      _ShakeState.sending => '',
      _ShakeState.denied =>
        'センサーの使用が許可されませんでした。\n'
            'iPhone は「設定 > Safari」から許可を確認してください。',
      _ShakeState.unsupported => 'この端末では振る検知が使えません。\nスマホのブラウザで開いてください。',
    };
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
    );
  }
}
