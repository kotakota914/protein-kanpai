import 'shake_detector.dart';

/// Web 以外（テスト実行時など）で使う空の実装。
class _StubShakeDetector implements ShakeDetector {
  @override
  bool get isSupported => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  void start(
    void Function() onShake, {
    void Function(double progress)? onProgress,
  }) {}

  @override
  void stop() {}
}

ShakeDetector createShakeDetector() => _StubShakeDetector();
