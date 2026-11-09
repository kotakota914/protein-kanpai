import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

import 'shake_counter.dart';
import 'shake_detector.dart';

/// iPhone・Android アプリ用：sensors_plus で加速度センサーを使う。
///
/// アプリでは加速度センサーの使用に許可ダイアログは出ない
/// （Info.plist に使う理由 NSMotionUsageDescription は書いてある）。
class _NativeShakeDetector implements ShakeDetector {
  StreamSubscription<AccelerometerEvent>? _sub;
  final _counter = ShakeCounter();

  @override
  bool get isSupported => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  void start(
    void Function() onShake, {
    void Function(double progress)? onProgress,
  }) {
    stop();
    _counter.reset();
    // accelerometerEventStream は重力を含む加速度（m/s²）。Web の値とそろっている
    _sub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
        .listen(
          (e) => _counter.add(
            e.x,
            e.y,
            e.z,
            DateTime.now(),
            onShake: onShake,
            onProgress: onProgress,
          ),
          onError: (_) => stop(),
          cancelOnError: true,
        );
  }

  @override
  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}

ShakeDetector createShakeDetector() => _NativeShakeDetector();
