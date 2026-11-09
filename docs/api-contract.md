# API の約束（フロントエンド → バックエンド）

フロントエンドの `lib/data/app_repository.dart` が使うデータを、API の形にしたもの。**バックエンド担当と合意するまでは案**として扱う。
項目を変えるときは、この文書と `lib/data/models.dart` を同時に直す。

## 共通

- ベース URL：Cloud Run の URL（例：`https://api-xxxx.a.run.app`）。Firebase Hosting の rewrites で `/api` に向けてもよい。
- ログイン：フロントで Firebase Authentication（Google）にログインし、**ID トークン**を毎回 `Authorization: Bearer <ID トークン>` で送る。バックエンドは Firebase Admin SDK で検証する。
- 日時は ISO 8601（UTC）。日付だけのものは `YYYY-MM-DD`（日本時間の日付）。
- 「振った時刻」「乾杯の判定」は**サーバーの時刻**で行う（端末の時計は信用しない）。

### エラー

| ステータス | いつ | フロントの表示 |
|---|---|---|
| 400 | 入力の形が違う | 「入力を確認してください」 |
| 401 | ログインしていない・トークン切れ | ログイン画面へ戻す |
| 403 | 他人のデータを操作しようとした | 「この操作はできません」 |
| 413 | 写真が大きすぎる | 「写真が大きすぎます」 |
| 422 | 写真が読めない／プロテインの袋と判定できない | 「読み取れませんでした。撮り直してください」 |
| 429 | 短時間に送りすぎ | 「少し待ってからもう一度」 |
| 503 | Gemini などが止まっている | 「いまは使えません。時間をおいてください」 |

本文は `{ "error": { "code": "TOO_LARGE", "message": "…" } }`。

## 自分

### `GET /me`

```json
{
  "id": "u_123",
  "name": "こうたろう",
  "avatarUrl": "https://storage.googleapis.com/…/u_123.png",
  "points": 120,
  "streak": 3,
  "shookToday": false,
  "totalDays": 7,
  "totalCheers": 1,
  "daysThisWeek": 4,
  "favoriteProtein": { "name": "ホエイプロテイン", "flavor": "ココア味", "proteinGrams": 20 }
}
```

`avatarUrl` と `favoriteProtein` は未設定なら `null`。

### `PUT /me/avatar`（アイコンの写真）

- 本文：`image/png` のバイト列。フロントで長い辺 320px に縮めてから送る（`lib/photo/photo_picker.dart`）。
- 上限 2MB（`AppRepository.maxAvatarBytes`）。サーバー側でも**サイズと画像形式（先頭のバイト）を必ず確認**する。友達の画面にも出るため。
- Cloud Storage に保存し、`{ "avatarUrl": "…" }` を返す。

### `DELETE /me/avatar`

写真を外す。`204`。

## 振る

### `POST /shakes`

シェイカーを振ったときに呼ぶ。本文なし。

```json
{
  "firstToday": true,
  "streak": 4,
  "bonusPoints": 10,
  "cheerWith": { "id": "u_456", "name": "はなこ" }
}
```

サーバーでやること：

1. 振った時刻を記録する。
2. 今日はじめてならスタンプ（その日の記録）を作り、ログインボーナスを付ける（`10pt`、連続日数が 7 の倍数の日は `+50pt`）。2 回目以降は `bonusPoints: 0`。
3. **フォロー中の友達が前後 5 秒以内に振っていたら乾杯成立**。いなければ `cheerWith: null`。成立したら両方の記録とタイムラインに残す。
4. 同じ人の連打を防ぐ（例：3 秒以内の 2 回目は無視、`429`）。

### `GET /shakes?month=2026-11`（カレンダー）

```json
[
  { "date": "2026-11-05", "cheerWith": ["たろう"] },
  { "date": "2026-11-06", "cheerWith": [] }
]
```

## 友達

### `GET /friends`

```json
[
  { "id": "u_456", "name": "はなこ", "avatarUrl": null, "following": true, "shakingNow": true, "shookToday": true }
]
```

- `shakingNow`：直近 10 秒以内に振った（ホームの「〇〇さんが振っています」に使う）。
- ホーム画面を開いている間、フロントは数秒ごとに読み直す。Firestore のリアルタイム更新でもよい（その場合はここを相談）。

### `PUT /follows/{userId}` ／ `DELETE /follows/{userId}`

フォロー・解除。自分自身は `400`。`204`。

### `GET /feed?limit=20`（タイムライン）

```json
[
  { "kind": "cheer", "friend": { "id": "u_789", "name": "たろう" }, "text": "たろうさんと乾杯しました", "at": "2026-11-07T10:00:00Z" }
]
```

`kind` は `shake`（振った）、`cheer`（乾杯）、`streak`（連続達成）。フォロー中の人の分だけ返す。

### `POST /invites`

招待リンクを作る。`{ "url": "https://…/invite/abc" }`。

## Gemini を使うもの

### `POST /protein/scan`（袋の写真から登録）

- 本文：写真（`image/jpeg` または `image/png`、10MB まで）。
- Vertex AI の Gemini で商品名・味・1 食あたりのたんぱく質量を読み取り、JSON スキーマ付きの構造化出力で受け取る。
- 返す：`{ "name": "ホエイプロテイン", "flavor": "ココア味", "proteinGrams": 20 }`。読めなければ `422`。
- 結果はそのまま保存せず、フロントで確認してから `PUT /me/favorite-protein` で保存する。

### `PUT /me/favorite-protein`

本文は上の 3 項目。`204`。

### `GET /me/weekly-summary`（今週のふりかえり）

```json
{ "text": "今週は 4日 振れました。あと 1日 で目標の 5日 に届きます。", "model": "gemini-…", "generatedAt": "2026-11-07T09:00:00Z" }
```

- 記録（日数・乾杯・連続）だけを入力にする。**医療的な助言はしない**（プロンプトで禁止し、応援にとどめる）。
- 使ったモデル名と作成日時を返す（審査の説明・再現のため）。

## 安全性の確認項目

- [ ] すべての API で ID トークンを検証している
- [ ] 他人の記録・プロフィールを書き換えられない
- [ ] タイムライン・友達一覧はフォロー関係のある人の分だけ返す
- [ ] 画像はサイズと形式をサーバーでも確認している
- [ ] API キー・サービスアカウントの鍵はリポジトリに入れず、Secret Manager に置いている
