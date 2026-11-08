import 'dart:typed_data';

/// Web 以外（テスト実行時など）では写真を選べない
Future<Uint8List?> pickPhotoBytes() async => null;
