import 'shake_detector_native.dart'
    if (dart.library.js_interop) 'shake_detector_web.dart'
    as impl;

/// シェイカーを振ったことを検知する。
///
/// - Web（スマホのブラウザ）：ブラウザの加速度センサー（devicemotion）を直接使う。
///   `sensors_plus` は iPhone の Safari で値が届かない報告があるため使わない。
/// - iPhone・Android アプリ：`sensors_plus` を使う。
/// - 判定の計算はどちらも [ShakeCounter]（shake_counter.dart）。
abstract class ShakeDetector {
  /// 何回強く揺れたら「振った」とするか（進み具合の表示用）
  static const requiredHits = 8;

  /// この端末・ブラウザでセンサーが使えるか
  bool get isSupported;

  /// センサーの使用許可を求める。
  ///
  /// iPhone では、ボタンを押したときの処理の中で **最初に** 呼ぶ必要がある
  /// （手前で await すると「ユーザーの操作」と見なされず、許可が出ない）。
  Future<bool> requestPermission();

  /// 振ったら [onShake] を呼ぶ。揺れを数えるたびに [onProgress]（0〜1）を呼ぶ。
  void start(
    void Function() onShake, {
    void Function(double progress)? onProgress,
  });

  void stop();
}

ShakeDetector createShakeDetector() => impl.createShakeDetector();
