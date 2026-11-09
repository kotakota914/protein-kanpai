import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'photo_picker.dart';

/// ブラウザのファイル選択を開き、選んだ写真を FileReader でメモリに読み込む。
///
/// blob: の URL を経由しないので、外部との通信を止めているページでも動く。
Future<Uint8List?> pickPhotoBytes() {
  final completer = Completer<Uint8List?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*';

  void finish(Uint8List? bytes) {
    if (!completer.isCompleted) completer.complete(bytes);
  }

  input.addEventListener(
    'change',
    ((web.Event _) {
      final files = input.files;
      if (files == null || files.length == 0) return finish(null);
      final file = files.item(0)!;
      if (file.size > maxSourceBytes) {
        if (!completer.isCompleted) {
          completer.completeError(PhotoTooLargeException());
        }
        return;
      }
      final reader = web.FileReader();
      reader.addEventListener(
        'load',
        ((web.Event _) {
          final result = reader.result;
          if (result == null) return finish(null);
          finish((result as JSArrayBuffer).toDart.asUint8List());
        }).toJS,
      );
      reader.addEventListener(
        'error',
        ((web.Event _) {
          if (!completer.isCompleted) {
            completer.completeError(StateError('read failed'));
          }
        }).toJS,
      );
      reader.readAsArrayBuffer(file);
    }).toJS,
  );
  // 選ぶのをやめたとき（対応しているブラウザのみ）
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  input.click();
  return completer.future;
}
