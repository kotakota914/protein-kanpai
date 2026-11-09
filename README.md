# プロテインで乾杯 🥤

[![Test and deploy](https://github.com/kotakota914/protein-kanpai/actions/workflows/deploy.yml/badge.svg)](https://github.com/kotakota914/protein-kanpai/actions/workflows/deploy.yml)

**シェイカーを振ったら、今日の筋トレ完了。友達と同時に振れば「乾杯」になる。**

運動を一人で続けられない人のための、スマホのブラウザで使える Web アプリです。
DevFest GDGoC Japan Hackathon 2026 に向けて、Flutter Web で開発しています。

### 紹介動画（約 2 分・音声あり）

[![紹介動画：使い方・工夫した点・機能（クリックで再生）](docs/images/video-thumb.png)](docs/video/intro.mp4)

使い方・機能・工夫した点を約 2 分で紹介しています（画像をクリックすると再生ページが開きます）。

- ナレーションは AI の音声合成（[Kokoro](https://huggingface.co/hexgrad/Kokoro-82M)、Apache License 2.0）で作成
- 動画の中のアプリは**仮のデータ**で動いています。振る場面は、ブラウザで揺れのデータを送って再現しています（実機で振った映像ではありません）

<p>
  <img src="docs/images/01-login.png" width="180" alt="ログイン画面">
  <img src="docs/images/02-home.png" width="180" alt="ホーム画面">
  <img src="docs/images/04-calendar.png" width="180" alt="カレンダー画面">
  <img src="docs/images/05-friends.png" width="180" alt="友達画面">
  <img src="docs/images/06-profile.png" width="180" alt="プロフィール画面">
</p>

---

## 目次

- [紹介動画](#紹介動画約-2-分音声あり)
- [なぜ作ったか](#なぜ作ったか)
- [できること](#できること)
- [しくみ](#しくみ)
- [技術構成と選んだ理由](#技術構成と選んだ理由)
- [動かし方](#動かし方)
- [iPhone アプリとして動かす（Xcode）](#iphone-アプリとして動かすxcode)
- [公開（Firebase Hosting）](#公開firebase-hosting)
- [フォルダ構成](#フォルダ構成)
- [バックエンドとの接続](#バックエンドとの接続)
- [ハッカソンへの提出](#ハッカソンへの提出)
- [開発のルール](#開発のルール)
- [使用している素材とライセンス](#使用している素材とライセンス)

---

## なぜ作ったか

運動したい気持ちはあるのに、続かない。スポーツ庁の調査（令和6年度、18〜79歳・40,000人）では、週 1 日以上運動している人は **52.5%**、運動したいと思っている人は **66.6%** で、**14.1 ポイントの差**があります。できなかった理由の 1 位は「**面倒くさいから**」（38.1%）で、「**仲間がいないから**」（11.4%）も挙がっています。
（出典：[スポーツ庁「令和6年度 スポーツの実施状況等に関する世論調査」](https://www.mext.go.jp/sports/b_menu/houdou/jsa_00202.html)）

そこで、**プロテインを飲む前にシェイカーを振る**という毎日の行動を、そのまま記録にしました。入力はゼロ。友達と同じタイミングで振れば乾杯になり、一緒にがんばっていることが伝わります。

| 課題 | このアプリの答え |
|---|---|
| 面倒くさい | シェイカーを**振るだけ**で記録 |
| 一人だと続かない | 友達と**同時に振ると乾杯**。「いま〇〇さんが振っています」で誘い合える |
| 続ける理由がない | 連続日数・スタンプ・キャラクターの成長で、**今日の 1 回**に意味を持たせる |
| 振り返らない | Gemini が記録から「今週のふりかえり」を作る |

## できること

| 画面 | 内容 |
|---|---|
| ログイン | Google でログイン |
| ホーム | 連続日数と今週のスタンプ、シェイカーくん（キャラクター）、シェイカーを振って記録、いま振っている友達 |
| 振った結果 | スタンプ・乾杯・連続日数・ログインボーナス・シェイカーくんの成長 |
| カレンダー | 振った日と乾杯した日のスタンプ、月ごとの集計 |
| 友達 | いま振っている友達、タイムライン、フォロー、招待 |
| プロフィール | 写真からアイコンを選ぶ、記録、好きなプロテイン（袋の写真から登録）、今週のふりかえり |

### シェイカーくん（キャラクター）

<img src="docs/images/03-mascot.png" width="600" alt="シェイカーくんの5段階と、味ごとのシェイクの色">

- **振った日数（＝筋トレした日数）**で 5 段階に育ちます：ひよっこ → ちょいマッチョ（3日）→ 細マッチョ（7日）→ マッチョ（14日）→ ムキムキ（30日）
- プロテインを飲んだ量ではなく日数で育てるので、1 日に何回振っても 1 日分。飲みすぎを促しません。
- 好きなプロテインの**味でシェイクの色が変わります**（ココア・ストロベリー・抹茶・バニラなど）。

### 実装の状況

画面とバックエンド API はつながっています。起動時に API の URL（`--dart-define=API_BASE_URL=…`）を渡すとバックエンドのデータで動き、渡さなければ**仮のデータ（モック）**で動きます（バックエンド無しのデモ用。ページを読み込み直すと最初の状態に戻ります）。

| 機能 | 状況 |
|---|---|
| 画面（8 画面）・画面の移動 | ✅ 実装済み |
| 振る検知（加速度センサー、iPhone の許可対応） | ✅ 実装済み（実機での調整が必要） |
| シェイカーくんの成長・味ごとの色・バッジ | ✅ 実装済み（成長とバッジは振る前後の数字から端末側で判定） |
| 記録・乾杯の判定・カレンダー・フォロー・タイムライン | ✅ API 接続済み（ローカルの `backend/` で 2 ユーザーの乾杯まで確認） |
| 友達の招待（リンクを作る → 開いた人と相互フォロー） | ✅ API 接続済み（`/invite/<code>` を開くとログイン後に受け取る） |
| 写真からアイコンを選ぶ（端末で 320px に縮小） | ✅ API 接続済み（`PUT /me/avatar`。友達のアイコンは ID トークン付きで取得して表示） |
| 袋の写真の読み取り・今週のふりかえり（Gemini） | ✅ API 接続済み（ローカルは Gemini の「代わり」で確認。本物の Vertex AI は未確認） |
| ログイン（Firebase Authentication の Google ログイン） | ✅ 実装済み（**本物の Firebase プロジェクトでの確認はまだ**。ローカルは開発用ログインで確認） |
| Cloud Run へのデプロイ・Firebase プロジェクトの作成 | ⏳ GCP のクレジットが届いてから（手順は `backend/README.md`） |

## しくみ

### 振る検知

```
ボタンを押す ──▶ センサーの使用許可（iPhone のみ）──▶ 加速度を監視
                                                         │
          重力の 2.5 倍を超える揺れを 2 秒以内に 8 回 ◀──┘
                                │
                                ▼
                     「振った」と判定して記録
```

- Web 版はブラウザの加速度センサー（`devicemotion`）を直接使っています。定番の `sensors_plus` は iPhone の Safari で値が届かない報告があるため、Web では使っていません。iPhone アプリ版は `sensors_plus` を使います。
- 判定の計算は Web とアプリで共通（`lib/shake/shake_counter.dart`）。数え時間は**最初の強い揺れから** 2 秒です（センサーは振っていない間も値を送ってくるため）。
- iPhone ではボタンを押したときにセンサーの使用許可を求めます。**HTTPS で公開したページでないと動きません。**
- 強さ・回数は `lib/shake/shake_counter.dart` で調整します。
- 振るボタンの中のシェイカーは、振るほど粉が混ざってプロテインの色になります。

### 乾杯

フォロー中の友達が**前後 5 秒以内に振ったら乾杯成立**。判定は端末ではなくサーバーの時刻で行います（詳細は [`docs/api-contract.md`](docs/api-contract.md)）。先に振った側の画面にも乾杯を出すため、サーバーは最大 5 秒だけ相手の振りを待ってから応答します。

## 技術構成と選んだ理由

| 技術 | 用途 | 選んだ理由 |
|---|---|---|
| **Flutter（Web）** | 画面 | チームに経験者がいる。シェイカーやキャラクターのアニメーションを自由に描ける。Google 技術でそろえられる |
| **Firebase Hosting** | 公開 | 加速度センサーは HTTPS が必須。静的ファイルを CDN と HTTPS 付きで配信できる |
| **Firebase Authentication** | Google ログイン（実装済み。プロジェクト作成待ち） | パスワードを自前で持たずに済む。ID トークンを API に付けて本人確認する |
| **Cloud Run** | API（`backend/` に実装済み。デプロイ待ち） | 乾杯の判定はサーバーの時刻で行う必要がある。使わないときは 0 台まで縮む |
| **Vertex AI の Gemini** | 袋の写真の読み取り・ふりかえり（実装済み。本番未確認） | 写真から商品名・味・たんぱく質量を構造化して取り出せる |
| **Cloud Storage** | アイコン写真（実装済み。本番未確認） | 非公開バケットに置き、API がログイン済みの本人と友達にだけ返す |

![アーキテクチャ図（実線は実装済み、点線は予定）](docs/images/architecture.png)

## 動かし方

[Flutter](https://docs.flutter.dev/get-started/install)（stable）が必要です。

```bash
flutter pub get
```

```bash
flutter run -d chrome --dart-define=DEV_TOOLS=true
```

`DEV_TOOLS=true` を付けると、PC でも確認できるように「（開発用）振ったことにする」ボタンと、Firebase なしの開発用ログインが出ます。**提出・デモ用のビルドには付けないでください**（デモ動画の偽装とみなされないように）。

API の URL を渡さないので、上のコマンドでは仮のデータ（モック）で動きます。

### バックエンドにつないで動かす（GCP なし）

[uv](https://docs.astral.sh/uv/) が必要です。ターミナルを 2 つ使います。

1 つ目（バックエンド。メモリ保存・開発用ログイン・Gemini の代わり、で動きます。`INVITE_BASE_URL` は招待リンクの先＝画面の URL）:

```bash
cd backend && uv sync && INVITE_BASE_URL=http://localhost:5555 uv run uvicorn app.main:app --port 8000
```

2 つ目（画面）:

```bash
flutter run -d chrome --web-port 5555 --dart-define=DEV_TOOLS=true --dart-define=API_BASE_URL=http://localhost:8000
```

ログイン画面の「（開発用）Firebase なしでログイン」で uid と名前を入れると、`Authorization: Bearer dev:<uid>:<名前>` でバックエンドに入れます。2 人で乾杯を試すには、別のウィンドウ（シークレットウィンドウでも可）で別の uid でログインし、片方の「友達」→「友達を招待しよう」で作ったリンクをもう片方で開いてから、5 秒以内に両方で振ります。

テストと静的チェック:

```bash
flutter test
```

```bash
flutter analyze
```

公開用のビルド（日本語フォントと描画エンジンを同梱し、外部に通信しない）:

```bash
flutter build web --release --no-web-resources-cdn
```

## iPhone アプリとして動かす（Xcode）

実機で振る検知を試したいときは、iPhone アプリとして動かせます（無料の Apple ID でOK）。手順は [`docs/ios.md`](docs/ios.md)。

```bash
open ios/Runner.xcworkspace
```

```bash
flutter run --release -d "あなたのiPhoneの名前"
```

## 公開（Firebase Hosting）

`main` に push すると、GitHub Actions（`.github/workflows/deploy.yml`）が静的チェック・テスト・ビルドを行い、Firebase の設定がそろっていれば Firebase Hosting に公開します。

**最初に一度だけ設定すること：**

1. [Firebase コンソール](https://console.firebase.google.com)でプロジェクトを作る（バックエンドと同じ GCP プロジェクト）。Authentication → Sign-in method で **Google** を有効にする
2. プロジェクトの設定 → サービスアカウント → 「新しい秘密鍵を生成」で JSON をダウンロード
3. プロジェクトの設定 → マイアプリ → **Web アプリ**を追加し、表示される `apiKey` / `appId` / `projectId` / `messagingSenderId` / `authDomain` を控える（公開ページに埋め込む識別子で、秘密ではありません）
4. GitHub のリポジトリ → Settings → Secrets and variables → Actions
   - **Secrets**：`FIREBASE_SERVICE_ACCOUNT` に JSON の中身をそのまま
   - **Variables**：`FIREBASE_PROJECT_ID` にプロジェクト ID
   - **Variables**：`FIREBASE_API_KEY`、`FIREBASE_APP_ID`、`FIREBASE_MESSAGING_SENDER_ID`、`FIREBASE_AUTH_DOMAIN`（手順 3 の値。無いと Google ログインが使えません）
   - **Variables**：`API_BASE_URL` に `/api`（`firebase.json` の rewrite で Cloud Run に中継。バックエンドは `API_PREFIX=/api` と `PUBLIC_BASE_URL=https://<Hosting の URL>/api`、`INVITE_BASE_URL=https://<Hosting の URL>` で起動する）。空なら仮のデータで公開される
   - （任意）**Variables**：`DEV_TOOLS` に `true` で開発用ボタン付きで公開

`firebase.json` の `/api/**` の rewrite は Cloud Run のサービス名 `protein-kanpai-api`・リージョン `asia-northeast1`（`backend/deploy.sh` の既定）に向けています。変えた場合はここも直してください。

> ⚠️ 秘密鍵の JSON は**絶対にリポジトリに入れない**でください（公開リポジトリです）。

## フォルダ構成

```
lib/
├── main.dart                 アプリの入口
├── app/                      テーマ（色・文字）と画面の移動
├── data/                     データの形・成長段階・データの窓口（AppRepository：仮データ版と API 版）・API クライアント・ログイン
├── features/                 画面ごとのコード
│   ├── login/  home/  calendar/  friends/  profile/  invite/
├── shake/                    振る検知（判定の計算は共通、センサーは Web とアプリで別）
├── photo/                    写真の選択と縮小（Web とアプリで別）
└── widgets/                  共通の部品（カード・シェイカー・シェイカーくん）
ios/                          iPhone アプリ用（Xcode で開く）
backend/                      バックエンド API（FastAPI / Cloud Run。app/ がコード、tests/ がテスト）
test/                         自動テスト
docs/                         API の約束・提出用の下書き・画像・紹介動画
scripts/                      提出用リポジトリへのコピー、紹介動画の作り方（scripts/video）
```

## バックエンドとの接続

画面が使うデータの窓口は [`lib/data/app_repository.dart`](lib/data/app_repository.dart)（`AppRepository`）です。中身は 2 つあり、起動時の `--dart-define=API_BASE_URL` の有無で選びます（`lib/main.dart`）。

| 中身 | ファイル | いつ使うか |
|---|---|---|
| `MockAppRepository` | `lib/data/mock_repository.dart` | `API_BASE_URL` 無し。仮のデータでデモする |
| `ApiAppRepository` | `lib/data/api_repository.dart` | `API_BASE_URL` あり。バックエンド API を呼ぶ |

つなぎ方の要点：

- **ログイン**：`lib/data/auth.dart`。本番は Firebase Authentication の Google ログイン（Web はポップアップ、iPhone アプリは OS のブラウザ画面）。`DEV_TOOLS=true` のときだけ、Firebase なしの開発用ログイン（`dev:<uid>:<名前>`）が使えます。
- **API 呼び出し**：`lib/data/api_client.dart` が毎回 `Authorization: Bearer <ID トークン>` を付けます。エラーは契約のエラー表の文言で画面に出し、401 ならログイン画面に戻します。
- **数字はサーバーのものをそのまま使う**：ポイント・連続日数・合計日数・乾杯回数は `GET /me` と `POST /shakes` の値。シェイカーくんの成長と新しいバッジだけは、振る前後の数字から端末側で判定します（`lib/data/progress.dart`）。
- **友達の様子**：ログイン中は数秒ごとに `GET /friends` を読み直し、「〇〇さんが振っています」を出します。
- **招待**：「友達を招待しよう」で `POST /invites` のリンクを作り、開いた人は `/invite/<code>` → ログイン → `POST /invites/<code>/accept` でお互いにフォローした状態になります（`lib/features/invite/`）。
- **アイコン画像**：`avatarUrl`（`GET /avatars/{userId}`）はログイン必須なので、`Image.network` ではなく ID トークン付きで取得してから表示します。

API の形（エンドポイント・返す JSON・エラー・安全性の確認項目）は [`docs/api-contract.md`](docs/api-contract.md) にまとめています。

バックエンド本体は [`backend/`](backend/)（Python 3.13 + FastAPI、Cloud Run）にあります。ローカルでの動かし方・テスト・Cloud Run へのデプロイ手順は [`backend/README.md`](backend/README.md)。

## ハッカソンへの提出

| ファイル | 内容 |
|---|---|
| [`docs/product.md`](docs/product.md) | プロダクト説明の下書き（`【要記入】` を埋める） |
| [`docs/copyright-sheet.md`](docs/copyright-sheet.md) | 著作物利用シートの下書き |
| [`docs/demo-script.md`](docs/demo-script.md) | デモ動画の台本（セリフ付き） |
| [`docs/submission.md`](docs/submission.md) | **提出の手順書**（締切前にこれを上から順に） |

提出用リポジトリ（運営の `df-2026-t071`）へは、履歴ごとではなく最新のファイルだけをコピーします（過去のコミットに秘密情報があっても公開されないように）。

```bash
git clone https://github.com/Devfest-Hackathon-2026/df-2026-t071.git ../df-2026-t071
```

```bash
scripts/export-to-submission.sh ../df-2026-t071
```

内容を確認してから、`../df-2026-t071` で `git push` します。締切：**2026-11-10（火）17:00**。

## 開発のルール

- `main` に push する前に `flutter analyze` と `flutter test` を通す（GitHub Actions でも確認されます）
- API キー・サービスアカウントの鍵・`.env` はコミットしない
- 画面の言葉は短く、具体的に。エラーは「何が起きたか・どうすればいいか」を書く
- デモ動画は実機で本当に振って撮る（開発用ボタンは使わない）

## 使用している素材とライセンス

| 素材 | ライセンス |
|---|---|
| Noto Sans JP（`assets/fonts/NotoSansJP-*.ttf`） | SIL Open Font License 1.1（[`OFL-NotoSansJP.txt`](assets/fonts/OFL-NotoSansJP.txt)） |
| Zen Maru Gothic（`assets/fonts/ZenMaruGothic-Black.ttf`） | SIL Open Font License 1.1（[`OFL-ZenMaruGothic.txt`](assets/fonts/OFL-ZenMaruGothic.txt)） |
| Material Icons（Flutter 同梱） | Apache License 2.0 |
| Flutter・go_router・package:web・sensors_plus・image_picker・http・firebase_core・firebase_auth | BSD 3-Clause |
| cupertino_icons | MIT |
| シェイカー・シェイカーくんのイラスト | チームがコードで描画（`lib/widgets/`） |
| 紹介動画のナレーション | [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M)（音声 `jf_alpha`）で生成。Apache License 2.0 |

詳しくは [`docs/copyright-sheet.md`](docs/copyright-sheet.md)。
