# API の約束（フロントエンド → バックエンド）

フロントエンドの `lib/data/app_repository.dart` が使うデータを、API の形にしたもの。
**実装は `backend/`（FastAPI / Cloud Run）。** 動かし方・環境変数・デプロイは `backend/README.md`。
項目を変えるときは、この文書と `lib/data/models.dart`、`backend/app/schemas.py` を同時に直す。
「（実装で追加）」と付いている項目は、バックエンド実装時にこの案へ足したもの。

## 共通

- ベース URL：Cloud Run の URL（例：`https://api-xxxx.a.run.app`）。Firebase Hosting の rewrites で `/api` に向けてもよい（その場合はサーバーの `API_PREFIX=/api`。rewrite の追加は接続時に `firebase.json` で行う）。
- `GET /healthz` はログイン不要で `{"ok": true}` を返す（実装で追加。Cloud Run の確認用）。
- ローカル開発では `Authorization: Bearer dev:<uid>:<URL エンコードした名前>` を無検証で受け付けるモードがある（`AUTH_MODE=dev`。本番では起動を拒否する）。
- ログイン：フロントで Firebase Authentication（Google）にログインし、**ID トークン**を毎回 `Authorization: Bearer <ID トークン>` で送る。バックエンドは Firebase Admin SDK で検証する。
- 日時は ISO 8601（UTC）。日付だけのものは `YYYY-MM-DD`（日本時間の日付）。
- 「振った時刻」「乾杯の判定」は**サーバーの時刻**で行う（端末の時計は信用しない）。

### エラー

| ステータス | いつ | フロントの表示 |
|---|---|---|
| 400 | 入力の形が違う | 「入力を確認してください」 |
| 401 | ログインしていない・トークン切れ | ログイン画面へ戻す |
| 403 | 他人のデータを操作しようとした（`GET /avatars/{userId}` で友達でない人の画像、`PUT /follows/{userId}` で招待を経ていない相手） | 「この操作はできません」 |
| 404 | 相手・招待・画像が無い（実装で追加） | 「見つかりません」 |
| 413 | 写真が大きすぎる | 「写真が大きすぎます」 |
| 422 | 写真が読めない／プロテインの袋と判定できない | 「読み取れませんでした。撮り直してください」 |
| 429 | 短時間に送りすぎ | 「少し待ってからもう一度」 |
| 503 | Gemini などが止まっている | 「いまは使えません。時間をおいてください」 |

本文は `{ "error": { "code": "TOO_LARGE", "message": "…" } }`。
`code` は `INVALID_ARGUMENT`（400）、`BAD_IMAGE`（400）、`UNAUTHENTICATED`（401）、`FORBIDDEN`（403）、`NOT_FOUND`（404）、`TOO_LARGE`（413）、`UNREADABLE`（422）、`TOO_MANY`（429）、`AI_UNAVAILABLE`（503）。入力の形の誤りも 400（FastAPI 既定の 422 は使わない）。

## 自分

### `GET /me`

```json
{
  "id": "u_123",
  "name": "こうたろう",
  "avatarUrl": "https://api-xxxx.a.run.app/avatars/u_123?v=1762650000",
  "points": 120,
  "streak": 3,
  "bestStreak": 7,
  "shookToday": false,
  "totalDays": 7,
  "totalCheers": 1,
  "daysThisWeek": 4,
  "favoriteProtein": { "name": "ホエイプロテイン", "flavor": "ココア味", "proteinGrams": 20 }
}
```

`avatarUrl` と `favoriteProtein` は未設定なら `null`。`bestStreak`（これまでの最長連続日数。実装で追加）はバッジ「3日つづいた」「1週間つづいた」の判定に使う。
`streak` は今日か昨日に振っていなければ 0。

### `PUT /me/avatar`（アイコンの写真）

- 本文：`image/png`（または `image/jpeg`）のバイト列。フロントで長い辺 320px に縮めてから送る（`lib/photo/photo_picker.dart`）。
- 上限 2MB（`AppRepository.maxAvatarBytes`）。サーバー側でも**サイズと画像形式（先頭のバイト）を必ず確認**する。友達の画面にも出るため。
- 非公開の Cloud Storage に保存し、`{ "avatarUrl": "https://<API>/avatars/u_123?v=1762650000" }` を返す。

### `GET /avatars/{userId}`（実装で追加）

`avatarUrl` の実体。**ログイン必須**で、本人か、`userId` とフォロー関係（どちら向きでも）がある人にだけ画像のバイト列を返す。関係がなければ 403、画像が無ければ 404。
画面側は `Image.network` ではなく、ID トークン付きで取得してから表示する（Flutter Web の `Image.network` はヘッダーを付けられない）。

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
  "cheerWith": { "id": "u_456", "name": "はなこ" },
  "points": 130,
  "totalDays": 8,
  "bestStreak": 7,
  "totalCheers": 2
}
```

- `points` 以下の 4 つは実装で追加。画面が成長段階とバッジの変化を 1 往復で出すため。
- `levelUpTo`（シェイカーくんの段階が上がったか）と `newAchievements`（新しくもらえたバッジ）は**サーバーでは返さない**（省略可の取り決めに従う）。画面側は、振る前に持っていた自分の数字と、この応答の `totalDays`・`bestStreak`・`totalCheers` から計算する。段階は `lib/data/growth.dart`、バッジは `lib/data/achievements.dart` の判定をそのまま使えばよい。

サーバーでやること：

1. 振った時刻を記録する。
2. 今日はじめてならスタンプ（その日の記録）を作り、ログインボーナスを付ける（`10pt`、連続日数が 7 の倍数の日は `+50pt`）。2 回目以降は `bonusPoints: 0`。
3. **フォロー中の友達が前後 5 秒以内に振っていたら乾杯成立**。いなければ `cheerWith: null`。成立したら両方の記録とタイムラインに残す。
4. 同じ人の連打を防ぐ：前回から 3 秒未満の 2 回目は `429`（何も記録しない）。
5. 「前後 5 秒」の「後」のために、フォロー中の友達がまだ振っていなければ**最大 5 秒待って**読み直す（`CHEER_WAIT_SECONDS`）。先に振った側の画面にも乾杯が出る。フォローしている人がいなければ待たない。
6. 乾杯は 1 日 1 回・相手ごとに数える。判定・記録は 1 回のトランザクションで行い、2 人が同時に互いを見つけても二重に数えない。

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

- 返すのは**フォロー関係（どちら向きでも）がある人だけ**（実装で確定）。`following` が false の人は「自分をフォローしている人」。知らない人は出ない。新しい友達は招待リンクでつなぐ。
- `shakingNow`：直近 10 秒以内に振った（ホームの「〇〇さんが振っています」に使う）。
- ホーム画面を開いている間、フロントは数秒ごとに読み直す。Firestore のリアルタイム更新でもよい（その場合はここを相談）。

### `PUT /follows/{userId}` ／ `DELETE /follows/{userId}`

フォロー・解除。自分自身は `400`。`PUT` は相手がいなければ `404`。`DELETE` は相手がいなくても `204`（何度呼んでも同じ結果）。
`PUT` は**相手が自分をフォローしているときだけ**許可し、それ以外は `403`（実装で追加。uid を知っているだけの人がフォローしてアイコンや記録を見られないように）。新しいつながりは招待リンクで作る。

### `GET /feed?limit=20`（タイムライン）

```json
[
  { "kind": "cheer", "friend": { "id": "u_789", "name": "たろう" }, "text": "たろうさんと乾杯しました", "at": "2026-11-07T10:00:00Z" }
]
```

`kind` は `shake`（振った）、`cheer`（乾杯）、`streak`（連続達成）。フォロー中の人の分と、自分の乾杯だけ返す。
`text` の例：「はなこさんが今日のプロテインを振りました」（今日でなければ「今日の」が付かない）、「たろうさんと乾杯しました」（自分の乾杯）、「はなこさんがたろうさんと乾杯しました」（フォロー中の人の乾杯。相手が自分の友達でなくても**名前だけ**は出る）、「たろうさんが 7日連続を達成！」。

### `POST /invites`

招待リンクを作る。`{ "url": "https://…/invite/abc" }`。リンクの先は `INVITE_BASE_URL`（Hosting の URL）。**7 日で失効**。

### `POST /invites/{code}/accept`（実装で追加）

招待リンクを開いた人が呼ぶ。招待した人と**相互フォロー**になり、`{ "friend": { "id": "u_123", "name": "こうたろう" } }` を返す。自分の招待は `400`、無い・期限切れは `404`。
画面側は `/invite/{code}` を開いたらログイン後にこの API を呼ぶ流れが必要。

## Gemini を使うもの

### `POST /protein/scan`（袋の写真から登録）

- 本文：写真（`image/jpeg` または `image/png`、10MB まで）。形式は先頭バイトで判定し、違えば `400`。前回から 5 秒未満の再送は `429`。
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

- [x] すべての API で ID トークンを検証している（`/healthz` 以外。`backend/app/deps.py`）
- [x] 他人の記録・プロフィールを書き換えられない（操作は常にトークンの本人。他人の id を取る API はフォロー・招待・画像だけで、いずれも関係を確認する）
- [x] タイムライン・友達一覧はフォロー関係のある人の分だけ返す
- [x] 画像はサイズと形式をサーバーでも確認している（`backend/app/services/images.py`）
- [x] API キー・サービスアカウントの鍵は使わない（Cloud Run の実行用サービスアカウントの権限だけで動く。Secret Manager も不要）
