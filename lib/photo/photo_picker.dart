import 'dart:typed_data';
import 'dart:ui' as ui;

import 'photo_picker_stub.dart'
    if (dart.library.js_interop) 'photo_picker_web.dart' as impl;

/// 選べる写真の大きさの上限（縮小する前の元ファイル）
const maxSourceBytes = 15 * 1024 * 1024;

/// 写真を 1 枚選んでもらい、そのままのバイト列を返す。やめたら null。
///
/// タップの処理の中で **await より先に** 呼ぶこと
/// （ブラウザはタップの直後でないとファイル選択を開けない）。
Future<Uint8List?> pickPhotoBytes() => impl.pickPhotoBytes();

/// 写真の長い辺を [maxSide] px に縮め、PNG にして返す。
/// 写真として読めないファイルなら例外を投げる。
Future<Uint8List> shrinkPhoto(Uint8List bytes, {int maxSide = 320}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (width, height) {
      final longest = width > height ? width : height;
      if (longest <= maxSide) return ui.TargetImageSize(width: width, height: height);
      final scale = maxSide / longest;
      return ui.TargetImageSize(
        width: (width * scale).round(),
        height: (height * scale).round(),
      );
    },
  );
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  codec.dispose();
  if (data == null) throw StateError('写真を変換できませんでした');
  return data.buffer.asUint8List();
}

/// 写真が大きすぎるときに投げる
class PhotoTooLargeException implements Exception {}
