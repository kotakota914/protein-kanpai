# iPhone アプリとして動かす（Xcode）

このアプリは Web 版（提出用）に加えて、iPhone アプリとしても動かせます。実機で「振る検知」やアイコンの写真選びを試したいときに使います。

> 提出・審査に使うのは Web 版（Firebase Hosting）です。iPhone アプリは動作確認用です。

## 必要なもの

- Mac（Apple シリコンでも Intel でも可）
- Xcode（App Store から無料でインストール）
- iPhone と、Mac につなぐケーブル
- Apple ID（無料でOK。有料の開発者登録は不要）

## 1. Mac の準備（最初の 1 回だけ）

1. Flutter を入れる：https://docs.flutter.dev/get-started/install/macos
2. Xcode を一度起動して、追加コンポーネントのインストールを済ませる
3. ターミナルで次を実行する

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

```bash
sudo xcodebuild -runFirstLaunch
```

```bash
flutter doctor
```

`flutter doctor` の「Xcode」の行に ✗ が出たら、表示された指示に従う（CocoaPods が必要と出たら `brew install cocoapods`）。

## 2. コードを取ってくる

```bash
git clone https://github.com/kotakota914/protein-kanpai.git
```

```bash
cd protein-kanpai && flutter pub get
```

## 3. Xcode で署名を設定する（最初の 1 回だけ）

```bash
open ios/Runner.xcworkspace
```

Xcode が開いたら:

1. 左の一覧で一番上の **Runner** を選ぶ → 中央の **TARGETS** で **Runner** を選ぶ
2. 上のタブで **Signing & Capabilities** を開く
3. **Team** で「Add an Account...」→ 自分の Apple ID でログイン → **（あなたの名前）(Personal Team)** を選ぶ
4. **Bundle Identifier** を、ほかの人と重ならない名前に変える
   - 例：`com.t071.proteinApp` → `com.あなたの英字の名前.proteinkanpai`
   - 「Failed to register bundle identifier」と出たら、別の名前にする

## 4. iPhone の準備（最初の 1 回だけ）

1. iPhone をケーブルで Mac につなぎ、iPhone に出る「このコンピュータを信頼しますか？」で **信頼** を押す
2. **デベロッパモードをオンにする**：iPhone の「設定」→「プライバシーとセキュリティ」→ 一番下の「デベロッパモード」→ オン → 再起動
   - 項目が見つからないときは、一度 Xcode から実行（次の手順）すると表示されます

## 5. iPhone で動かす

```bash
flutter devices
```

一覧に自分の iPhone が出たら（名前か ID をコピーする）:

```bash
flutter run --release -d "あなたのiPhoneの名前"
```

- `--release` を付けると動きがなめらかで、ケーブルを抜いてもアプリが使えます
- `--release` を付けずに実行すると、開発用の「（開発用）振ったことにする」ボタンが出ます
- Xcode の上部で iPhone を選んで ▶（Run）を押しても同じです

**初めて起動するとき**、「信頼されていないデベロッパ」と出たら:
iPhone の「設定」→「一般」→「VPN とデバイス管理」→ 自分の Apple ID → **信頼**。

## 6. 試してみる

- **振る検知**：ホームの「タップして準備」を押して、iPhone をシェイカーのように振る。「○ / 8」が進み、8 回で記録されます
  - 判定の強さ・回数は `lib/shake/shake_counter.dart` の `threshold`（強さ）などで調整します。振っても進みにくい／弱く振っても反応する、などの感想を教えてください
- **アイコン**：プロフィールで自分のアイコンを押す →「写真から選ぶ」→ 写真へのアクセスを許可
- `API_BASE_URL` を付けずに動かしたときの**データは仮のもの**です。アプリを終了すると最初の状態に戻ります

## うまくいかないとき

| 表示・症状 | 対処 |
|---|---|
| Signing for "Runner" requires a development team | 手順 3 の Team を選ぶ |
| Failed to register bundle identifier / No profiles were found | 手順 3 の Bundle Identifier を別の名前にする |
| 信頼されていないデベロッパ | 手順 5 の「VPN とデバイス管理」で信頼する |
| `flutter devices` に iPhone が出ない | ケーブルをつなぎ直す、iPhone のロックを解除する、「信頼」を押す、デベロッパモードをオンにする |
| CocoaPods のエラー | `brew install cocoapods` のあと、`cd ios && pod install && cd ..` |
| 7 日たったらアプリが開かなくなった | 無料の Apple ID で入れたアプリは 7 日で期限切れ。手順 5 をもう一度実行する |

## バックエンドにつなぐ（Google ログイン）

何も付けずに動かすと仮のデータで動きます。バックエンドにつなぐには、起動時に API の URL を渡します（iPhone アプリでは `/api` のような相対指定は使えないので、Cloud Run の URL をそのまま書く）:

```bash
flutter run --release -d "あなたのiPhoneの名前" --dart-define=API_BASE_URL=https://<Cloud Run の URL>
```

Google ログインには Firebase の iOS 用の設定が要ります（Firebase プロジェクトができてから。**まだ確認していません**）:

1. Firebase コンソール → プロジェクトの設定 → マイアプリ → **iOS アプリ**を追加（Bundle Identifier は手順 3 で付けたもの）
2. `GoogleService-Info.plist` をダウンロードし、Xcode で `Runner/Runner` の中に入れる（`.gitignore` 済み。リポジトリには入れない）
3. `ios/Runner/Info.plist` の `CFBundleURLTypes` に、plist の `REVERSED_CLIENT_ID` を URL スキームとして追加する（Google のログイン画面からアプリに戻るため）

ログインの実装は `lib/data/auth.dart`（iPhone アプリは `signInWithProvider` で OS のブラウザ画面を開く）。

## しくみ（開発者向け）

| 機能 | Web 版 | iPhone アプリ |
|---|---|---|
| 振る検知 | ブラウザの `devicemotion`（`lib/shake/shake_detector_web.dart`） | `sensors_plus`（`lib/shake/shake_detector_native.dart`） |
| 判定の計算 | 共通：`lib/shake/shake_counter.dart`（テスト：`test/shake_counter_test.dart`） | 同左 |
| 写真選び | ブラウザのファイル選択（`lib/photo/photo_picker_web.dart`） | `image_picker`（`lib/photo/photo_picker_native.dart`） |
| 使う理由の表示 | なし | `ios/Runner/Info.plist`（写真・モーション） |
| Google ログイン | Firebase のポップアップ（`signInWithPopup`） | OS のブラウザ画面（`signInWithProvider`）。`GoogleService-Info.plist` が要る |
