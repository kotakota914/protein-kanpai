import 'package:flutter_test/flutter_test.dart';
import 'package:protein_app/shake/shake_counter.dart';

void main() {
  final t0 = DateTime(2026, 11, 9, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  /// [times] の時刻（ミリ秒）に強さ [g] の揺れを送り、振った回数と最後の進み具合を返す
  (int shakes, double progress) feed(
    ShakeCounter c,
    List<int> times, {
    double g = 30,
  }) {
    var shakes = 0;
    var progress = 0.0;
    for (final ms in times) {
      c.add(
        g,
        0,
        0,
        at(ms),
        onShake: () => shakes++,
        onProgress: (p) => progress = p,
      );
    }
    return (shakes, progress);
  }

  List<int> every(int start, int count, int gap) => [
    for (var i = 0; i < count; i++) start + i * gap,
  ];

  test('2秒以内に8回強く揺れると「振った」になる', () {
    final (shakes, progress) = feed(ShakeCounter(), every(0, 8, 200));
    expect(shakes, 1);
    expect(progress, 1.0);
  });

  test('7回では「振った」にならず、進み具合は 7/8', () {
    final (shakes, progress) = feed(ShakeCounter(), every(0, 7, 200));
    expect(shakes, 0);
    expect(progress, closeTo(7 / 8, 1e-9));
  });

  test('弱い揺れ（重力くらい）は数えない', () {
    final (shakes, progress) = feed(ShakeCounter(), every(0, 20, 200), g: 9.8);
    expect(shakes, 0);
    expect(progress, 0);
  });

  test('2秒を過ぎると数え直す', () {
    // 4 回揺れて 3 秒あける → 数え直しになり、そのあと 4 回では足りない
    final c = ShakeCounter();
    final (first, _) = feed(c, every(0, 4, 200));
    final (second, _) = feed(c, every(3600, 4, 200));
    expect(first + second, 0);
  });

  test('1回の強い揺れを何度も数えない（120ミリ秒以内は1回）', () {
    final (shakes, progress) = feed(ShakeCounter(), every(0, 8, 50));
    expect(shakes, 0);
    expect(progress, closeTo(3 / 8, 1e-9)); // 0, 150, 300 ミリ秒の 3 回だけ
  });

  test('判定したあと3秒間は数えない', () {
    final c = ShakeCounter();
    final (first, _) = feed(c, every(0, 8, 200));
    final (during, _) = feed(c, every(1600, 8, 200)); // 判定直後〜3 秒以内
    final (after, _) = feed(c, every(5000, 8, 200)); // 3 秒後
    expect(first, 1);
    expect(during, 0);
    expect(after, 1);
  });

  test('振る前に弱い値がずっと届いていても、振り始めてから2秒以内なら判定できる', () {
    // センサーは振っていない間も値を送ってくる（60回/秒）。1.5 秒構えてから振り始める
    final c = ShakeCounter();
    final (idle, _) = feed(c, every(0, 90, 16), g: 9.8);
    final (shakes, progress) = feed(c, every(1500, 8, 200));
    expect(idle, 0);
    expect(shakes, 1);
    expect(progress, 1.0);
  });
}
