import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'photo_picker.dart';

/// iPhone・Android アプリ用：写真アプリから 1 枚選ぶ（image_picker）。
///
/// 端末側で長い辺 1024px まで縮めてから読み込む。
/// アイコン用にはこのあと shrinkPhoto でさらに 320px に縮める。
Future<Uint8List?> pickPhotoBytes() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 90,
  );
  if (file == null) return null; // 選ぶのをやめた
  if (await file.length() > maxSourceBytes) throw PhotoTooLargeException();
  return file.readAsBytes();
}
