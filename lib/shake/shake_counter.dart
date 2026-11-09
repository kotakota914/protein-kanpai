import 'dart:math' as math;

import 'shake_detector.dart';

/// 加速度の値から「振った」を判定する計算。Web と iPhone アプリで共通。
///
/// 重力の約 2.5 倍を超える揺れを、最初の揺れから [window] 以内に
/// [ShakeDetector.requiredHits] 回数えたら「振った」とする。
class ShakeCounter {
  ShakeCounter({
    this.threshold = 25,
    this.window = const Duration(seconds: 2),
    this.cooldown = const Duration(seconds: 3),
    this.hitGap = const Duration(milliseconds: 120),
  });

  /// 振ったと判定する強さ（m/s²。重力は約 9.8）。実機で調整する
  final double threshold;

  /// この時間内に必要な回数だけ揺れたら「振った」
  final Duration window;

  /// 1 回判定したあと、次の判定までの待ち時間
  final Duration cooldown;

  /// 1 回の強い揺れで何度も数えないための間隔
  final Duration hitGap;

  int _hits = 0;
  DateTime? _windowStart;
  DateTime? _lastHit;
  DateTime? _lastShake;

  /// 加速度（重力を含む、m/s²）を 1 回分渡す。
  ///
  /// 数えた回数が変わったら [onProgress]（0〜1）を、
  /// 「振った」と判定したら [onShake] を呼ぶ。
  void add(
    double x,
    double y,
    double z,
    DateTime now, {
    required void Function() onShake,
    void Function(double progress)? onProgress,
  }) {
    if (_lastShake != null && now.difference(_lastShake!) < cooldown) return;
    // 数え時間は「最初の強い揺れ」から始める。センサーは振っていない間も値を送ってくるので、
    // 値が届いた時から計ると、構えている間に時間切れになってしまう
    final start = _windowStart;
    if (start != null && now.difference(start) > window) {
      if (_hits > 0) onProgress?.call(0);
      _hits = 0;
      _windowStart = null;
    }
    final g = math.sqrt(x * x + y * y + z * z);
    final last = _lastHit;
    if (g > threshold && (last == null || now.difference(last) > hitGap)) {
      _windowStart ??= now;
      _hits++;
      _lastHit = now;
      onProgress?.call(_hits / ShakeDetector.requiredHits);
    }
    if (_hits >= ShakeDetector.requiredHits) {
      _hits = 0;
      _windowStart = null;
      _lastShake = now;
      onShake();
    }
  }

  void reset() {
    _hits = 0;
    _windowStart = null;
    _lastHit = null;
    _lastShake = null;
  }
}
