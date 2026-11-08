import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import 'shake_detector.dart';

/// 振ったと判定する強さ（重力 約 9.8 の何倍か）。実機で調整する。
const double _threshold = 25;

/// この時間内に [ShakeDetector.requiredHits] 回強く揺れたら「振った」とする
const Duration _window = Duration(seconds: 2);

/// 1 回判定したあと、次の判定までの待ち時間
const Duration _cooldown = Duration(seconds: 3);

/// 1 回の強い揺れで何度も数えないための間隔
const Duration _hitGap = Duration(milliseconds: 120);

class _WebShakeDetector implements ShakeDetector {
  JSFunction? _listener;

  @override
  bool get isSupported => globalContext.has('DeviceMotionEvent');

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    final dme = globalContext['DeviceMotionEvent'] as JSObject;
    // Android や PC の Chrome には requestPermission がなく、許可は不要
    if (!dme.has('requestPermission')) return true;
    try {
      final result = await dme
          .callMethod<JSPromise<JSString>>('requestPermission'.toJS)
          .toDart;
      return result.toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  @override
  void start(
    void Function() onShake, {
    void Function(double progress)? onProgress,
  }) {
    stop();
    var hits = 0;
    var windowStart = DateTime.now();
    var lastHit = DateTime.fromMillisecondsSinceEpoch(0);
    var lastShake = DateTime.fromMillisecondsSinceEpoch(0);

    void handle(web.DeviceMotionEvent event) {
      final a = event.accelerationIncludingGravity;
      if (a == null) return;
      final x = a.x ?? 0, y = a.y ?? 0, z = a.z ?? 0;
      final g = math.sqrt(x * x + y * y + z * z);
      final now = DateTime.now();

      if (now.difference(lastShake) < _cooldown) return;
      if (now.difference(windowStart) > _window) {
        if (hits > 0) onProgress?.call(0);
        hits = 0;
        windowStart = now;
      }
      if (g > _threshold && now.difference(lastHit) > _hitGap) {
        hits++;
        lastHit = now;
        onProgress?.call(hits / ShakeDetector.requiredHits);
      }
      if (hits >= ShakeDetector.requiredHits) {
        hits = 0;
        lastShake = now;
        onShake();
      }
    }

    _listener = handle.toJS;
    web.window.addEventListener('devicemotion', _listener);
  }

  @override
  void stop() {
    final listener = _listener;
    if (listener != null) {
      web.window.removeEventListener('devicemotion', listener);
      _listener = null;
    }
  }
}

ShakeDetector createShakeDetector() => _WebShakeDetector();
