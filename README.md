# プロテインで乾杯（フロントエンド）

シェイカーを振ったら、今日の筋トレ完了。友達と同時に振れば乾杯になる、運動習慣を続けるための Web アプリです。
DevFest GDGoC Japan Hackathon 2026 のチーム開発用リポジトリ（Flutter Web）です。

## できること

| 画面 | 内容 |
|---|---|
| ログイン | Google でログイン（いまは仮のログイン） |
| ホーム | 連続日数と今週のスタンプ、シェイカーを振って記録、いま振っている友達の表示 |
| 振った結果 | スタンプ獲得・乾杯の成立・連続日数・ログインボーナス |
| カレンダー | 振った日と乾杯した日のスタンプ、月ごとの集計 |
| 友達 | いま振っている友達、タイムライン、フォロー |
| プロフィール | 写真からアイコンを選ぶ、記録、好きなプロテイン（Gemini で袋の写真から読み取り予定）、今週のふりかえり |

**現在はすべて仮のデータ（モック）で動きます。** ページを読み込み直すと最初の状態に戻ります。

## 動かし方

Flutter（stable）が必要です。

```bash
flutter pub get
```

```bash
flutter run -d chrome --dart-define=DEV_TOOLS=true
```

`DEV_TOOLS=true` を付けると、PC でも確認できるように「（開発用）振ったことにする」ボタンが出ます。**提出・デモ用のビルドには付けないでください。**

テストと静的チェック:

```bash
flutter test
```

```bash
flutter analyze
```

公開用のビルド（日本語フォントとレンダラーを同梱し、外部に通信しない）:

```bash
flutter build web --release --no-web-resources-cdn
```

## 振る検知について

- ブラウザの加速度センサー（`devicemotion`）を直接使っています（`lib/shake/`）。`sensors_plus` は iPhone の Safari で値が届かない報告があるため使っていません。
- iPhone ではボタンを押したときにセンサーの使用許可を求めます。**HTTPS で公開したページでないと動きません**（Firebase Hosting など）。
- 判定の強さと回数は `lib/shake/shake_detector_web.dart` の定数で調整します（実機で要調整）。

## バックエンドとの接続

画面が使うデータは `lib/data/app_repository.dart` にまとめてあります。いまは仮のデータで、バックエンドができたらこのクラスの中身だけを差し替えます。差し替える箇所には `TODO(backend)` と書いてあります。

- ログイン（Firebase Authentication）
- 振った記録・乾杯の判定・ログインボーナス（Cloud Run の API）
- フォロー・招待リンク
- アイコン写真の保存（Cloud Storage）
- プロテインの袋の写真の読み取り・今週のふりかえり（Gemini）

## 使用している素材とライセンス

| 素材 | ライセンス |
|---|---|
| Noto Sans JP（`assets/fonts/NotoSansJP-*.ttf`） | SIL Open Font License 1.1（`assets/fonts/OFL-NotoSansJP.txt`） |
| Zen Maru Gothic（`assets/fonts/ZenMaruGothic-Black.ttf`） | SIL Open Font License 1.1（`assets/fonts/OFL-ZenMaruGothic.txt`） |
| Material Icons（Flutter 同梱） | Apache License 2.0 |
| シェイカーのイラスト（`lib/widgets/shaker.dart`） | チームでコードで描画 |
