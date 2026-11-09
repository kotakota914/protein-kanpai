import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'shake_counter.dart';
import 'shake_detector.dart';

/// Web（スマホのブラウザ）用：加速度センサー（devicemotion）を直接使う。
///
/// `sensors_plus` は iPhone の Safari で値が届かない報告があるため、Web では使わない。
class _WebShakeDetector implements ShakeDetector {
  JSFunction? _listener;
  final _counter = ShakeCounter();

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
    _counter.reset();

    void handle(web.DeviceMotionEvent event) {
      final a = event.accelerationIncludingGravity;
      if (a == null) return;
      _counter.add(
        a.x ?? 0,
        a.y ?? 0,
        a.z ?? 0,
        DateTime.now(),
        onShake: onShake,
        onProgress: onProgress,
      );
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
