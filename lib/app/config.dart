import 'package:flutter/foundation.dart';

/// ビルド時に `--dart-define=名前=値` で渡す設定。
///
/// 何も渡さなければ、バックエンド無し（仮データ）で動く。
class AppConfig {
  /// API の土台 URL。例：`http://localhost:8000`。
  /// Firebase Hosting の rewrite（`/api/**` → Cloud Run）を使うなら `/api`。
  /// 空なら仮データ（モック）で動く。
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static bool get usesApi => apiBaseUrl.isNotEmpty;

  /// 開発用の道具（「振ったことにする」ボタン、Firebase なしのログイン）を出すか。
  ///
  /// 開発中（debug）か、`DEV_TOOLS=true` を付けてビルドしたときだけ出す。
  /// 提出・デモ用のビルドには付けない。
  static const devTools = kDebugMode || bool.fromEnvironment('DEV_TOOLS');

  // Firebase の Web 用の設定値。
  // Firebase コンソール → プロジェクトの設定 → マイアプリ（Web アプリ）に表示される。
  // 「API キー」という名前だが秘密ではなく、公開ページに埋め込む前提の識別子
  // （https://firebase.google.com/docs/projects/api-keys ）。
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );

  static bool get hasFirebaseConfig =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;
}
