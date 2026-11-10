import 'dart:typed_data';
import 'dart:ui' as ui;

import 'photo_picker_native.dart'
    if (dart.library.js_interop) 'photo_picker_web.dart'
    as impl;

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
      if (longest <= maxSide) {
        return ui.TargetImageSize(width: width, height: height);
      }
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

/// 先頭のバイト列で JPEG / PNG を見分ける（`image/jpeg` か `image/png`。それ以外は null）。
///
/// サーバーも同じ方法で確認する（backend/app/services/images.py）。
/// ファイル名や Content-Type は信用しない。
String? detectImageType(Uint8List bytes) {
  const pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  const jpegSignature = [0xFF, 0xD8, 0xFF];
  bool startsWith(List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith(pngSignature)) return 'image/png';
  if (startsWith(jpegSignature)) return 'image/jpeg';
  return null;
}
