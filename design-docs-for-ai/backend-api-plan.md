# 実装計画：バックエンド API（`backend/`）

対象の依頼：`user-prompt/2026-11-09-backend-api.md`
仕様の一次情報：`docs/api-contract.md`、`lib/data/app_repository.dart`、`lib/data/models.dart`
状態：**実装済み。コードレビュー反映済み。PR 前**

## 0. 一言で

`docs/api-contract.md` の API を、Python 3.13 + FastAPI で `backend/` に実装する。保存先は Firestore、画像は Cloud Storage、AI は Vertex AI の Gemini。
GCP がなくても開発・テストできるように、保存先・認証・Gemini・Storage の 4 つは「本物」と「テスト用の代わり」を差し替えられる作りにする。

## 1. 変更対象

### 新規（`backend/`）

```
backend/
├── pyproject.toml / uv.lock        依存（uv で管理）
├── Dockerfile / .dockerignore      Cloud Run 用のコンテナ
├── README.md                       動かし方・環境変数・デプロイ手順
├── deploy.sh                       gcloud でのデプロイ台本（API 有効化・権限・run deploy）
├── firebase.json / firestore.rules Firestore エミュレータ用（テスト専用。ルールは全拒否）
├── app/
│   ├── main.py        FastAPI アプリの組み立て（CORS・エラー変換・ルーター登録・/healthz）
│   ├── config.py      環境変数 → 設定（Settings）
│   ├── errors.py      ApiError と {"error": {"code","message"}} への変換
│   ├── auth.py        Authorization: Bearer の検証 → CurrentUser（firebase / dev の 2 方式）
│   ├── schemas.py     リクエスト・レスポンスの形（pydantic。契約の JSON と 1:1）
│   ├── dates.py       日本時間の日付・週（月曜はじまり）・ISO 8601 UTC
│   ├── rules.py       純粋な計算：連続日数、ボーナス、乾杯の窓、連打判定、成長段階、タイムライン文
│   ├── store/
│   │   ├── base.py       Store の約束（Protocol）：ユーザー・日ごとの記録・フォロー・イベント・招待
│   │   ├── memory.py     メモリ上の実装（テスト・ローカル）
│   │   └── firestore.py  Firestore の実装
│   ├── services/
│   │   ├── gemini.py     Vertex AI Gemini（scan / weekly summary）＋ Fake
│   │   └── storage.py    Cloud Storage へのアイコン保存 ＋ Fake
│   └── routers/
│       ├── me.py         GET /me, PUT/DELETE /me/avatar, GET /avatars/{userId}, PUT /me/favorite-protein, GET /me/weekly-summary
│       ├── shakes.py     POST /shakes, GET /shakes?month=
│       ├── friends.py    GET /friends, PUT/DELETE /follows/{id}, GET /feed, POST /invites, POST /invites/{code}/accept
│       └── protein.py    POST /protein/scan
└── tests/
    ├── conftest.py              Memory store + dev 認証 + Fake Gemini/Storage + 固定時計
    ├── test_rules.py            純粋計算の単体テスト
    ├── test_auth.py / test_me.py / test_shakes.py / test_friends.py / test_protein.py
    └── integration/test_firestore_store.py   Firestore エミュレータに対する Store の試験（環境変数がある時だけ）
```

### 既存の変更（小さく）

| ファイル | 変更 | 理由 |
|---|---|---|
| `docs/api-contract.md` | 追記：`GET /me` の `bestStreak`、`GET /avatars/{userId}`（`avatarUrl` の意味の変更）、招待の受け取り `POST /invites/{code}/accept`、`GET /friends` の範囲、連打 429 の詳細、404 `NOT_FOUND`、`/healthz`、エラーコード一覧、開発用トークン、アイコンは PNG/JPEG を受け付ける | 契約は「案」。実装で決めた点を同じ文書に残す（契約の決まり） |
| `README.md` | 「バックエンドとの接続」に `backend/README.md` への 1 行、フォルダ構成に `backend/` | 入口を示す |
| `.github/workflows/backend.yml`（新規） | `backend/**` の変更時に ruff と pytest を実行 | 既存の Flutter 用ワークフローには触れない |
| `.gitignore` | `backend/.venv/`、`backend/.pytest_cache/`、`backend/__pycache__/` | 生成物を入れない |

**触らないもの**：`lib/`（Flutter 側）、`firebase.json`（Hosting 用）、`.github/workflows/deploy.yml`、`scripts/`。

## 2. 選んだ方法と理由（設計判断。識別子は図解と共通）

| ID | 判断 | 理由 | 代わりの案と捨てた理由 |
|---|---|---|---|
| D1 | Python 3.13 + FastAPI、依存は uv | 依頼者の決定。Firebase Admin・Firestore・Storage・Gemini（google-genai）の公式ライブラリがそろう。この Mac に Python 3.13 と uv がある | TypeScript：同等だが設定が増える。Dart：サーバー用の公式ライブラリがなく締切前に詰まる |
| D2 | データベースは **Firestore**（Native モード） | サーバーレスで接続管理が不要、使わない時は無料、Cloud Run と相性がよい。データが「人ごと」にまとまる形なので文書型で十分 | Cloud SQL：インスタンス常時課金・接続設定が必要。Memorystore：永続化の用途に合わない |
| D3 | **友達一覧はフォロー関係がある人だけ**（自分がフォロー ∪ 自分をフォロー）。新しい友達は**招待リンク**でつながる。そのため契約にない `POST /invites/{code}/accept`（相互フォロー）を追加 | 契約の安全性チェック「友達一覧はフォロー関係のある人の分だけ返す」に従う。招待リンクを作る API だけあって受け取る API がないと、誰ともつながれない | 全ユーザー一覧を返す：知らない人の名前が見える。名前検索：同上 |
| D4 | アイコン画像は**非公開**の Cloud Storage（`avatars/{uid}.png`）に置き、**API `GET /avatars/{userId}` がログイン済みの本人か友達（フォロー関係のある人）にだけ返す**。`avatarUrl` はこの API の URL（`{PUBLIC_BASE_URL}/avatars/{uid}?v=<更新時刻>`）。それ以外は 403 | **依頼者の決定（2026-11-09 23:05）**。画像をログインした人にしか見せない。URL を知っていても見られない | 公開 URL（推奨していた案）：フロント変更が不要だが URL を知れば誰でも見られる。署名付き URL：7 日で切れ IAM 設定が増える。**注意**：Flutter Web の `Image.network` はヘッダーを付けられないため、画面側は「ID トークン付きで取得してから表示」する実装が接続工程で必要になる |
| D5 | **Store（保存先）を差し替え可能**にする。`memory`（テスト・ローカル）と `firestore` の 2 実装。Firestore 実装は**エミュレータ**で同じシナリオを試す | GCP プロジェクトがまだ無い。ロジックのテストを速く回し、Firestore 固有の操作（配列追加・問い合わせ）はエミュレータで確かめる | Firestore 直書き＋エミュレータのみ：テストが遅く、GCP なしのローカル実行ができない |
| D6 | 認証は 2 方式。`firebase`：ID トークンを Firebase Admin で検証。`dev`：`Bearer dev:<uid>:<名前>` を無検証で受け付ける。**dev は Cloud Run 上（環境変数 `K_SERVICE` あり）では起動を拒否** | ローカルと自動テストで Firebase なしに動かすため。本番で誤って dev が有効になる事故を機械的に防ぐ | テストでトークン検証をモック：ローカルで curl できない |
| D7 | 乾杯の判定：各ユーザーの `lastShakeAt`（最後に振った時刻）だけを持つ。振った人の処理で、**フォロー中の友達の lastShakeAt が 5 秒以内**なら乾杯。成立したら**両方**の日記録とイベントに書く。同じ人との乾杯は 1 日 1 回まで数える | 生の振った履歴を貯めなくて済む。後から振った側が両方分を書くので、先に振った側も次の読み込みで乾杯が見える | 生ログを時間範囲で検索：書き込みが増え、問い合わせも複雑 |
| D8 | Gemini は Vertex AI 経由（`google-genai`、`vertexai=True`）。モデル名は環境変数（既定 `gemini-2.5-flash`）。袋の読み取りは **JSON スキーマ付きの構造化出力**。ふりかえりは**同じ週・同じ数字なら再利用**（ユーザー文書にキャッシュ） | クレジットは Vertex AI でしか使えない（product.md）。構造化出力で「読めない」を機械的に判定できる。ふりかえりは画面を開くたびに呼ぶと課金と遅延が増える | AI Studio の API キー：クレジット対象外・鍵の管理が増える |
| D9 | `backend/` を同じリポジトリに置く。CI は `backend/**` だけで動く別ワークフロー | `scripts/export-to-submission.sh` がリポジトリ全体をコピーするので、提出物に自動で含まれる。既存の Flutter の CI に影響しない | 別リポジトリ：提出時に手でコピーが要る、契約と実装が離れる |
| D10 | 公開経路は 2 択を両対応：Cloud Run の URL 直（CORS 許可リスト）または Firebase Hosting の `/api` 書き換え（`API_PREFIX=/api`） | ブラウザ版は別ドメインからの呼び出しになるので CORS が必要。iOS アプリ版は CORS 不要 | — |
| D11 | 日付は**日本時間**で区切る（`Asia/Tokyo`）。時刻は UTC の ISO 8601 で返す。「今日」はサーバー時刻から決める | 契約どおり。端末の時計は信用しない | — |

## 3. データの形（Firestore）

```
users/{uid}
  name, avatarUpdatedAt?, avatarContentType?, points, favoriteProtein?{name,flavor,proteinGrams},
  lastShakeAt?, lastShakeDate?（日本時間 YYYY-MM-DD）, lastScanAt?, weeklySummary?{key,text,model,generatedAt}, createdAt
users/{uid}/days/{YYYY-MM-DD}          その日に振った記録（スタンプ）
  date, firstShakeAt, cheerWith: [{id,name}]
users/{uid}/following/{otherUid}       フォロー（createdAt のみ。名前などは users を読む）
users/{uid}/followers/{otherUid}       逆引き（友達一覧のため。follow/unfollow 時に両方書く）
users/{uid}/events/{autoId}            本人の出来事（タイムラインの元）
  kind: shake|cheer|streak, at, counterpartId?, counterpartName?, streak?
invites/{code}                         招待
  inviterId, inviterName, createdAt, usedBy: []
```

- タイムライン（`GET /feed`）は**読む時に集める**：フォロー中の各人の `events` を新しい順に取り、自分の `cheer` イベントも混ぜ、時刻順に並べて `limit` 件。文はその場で作る（自分の乾杯は「〇〇さんと乾杯しました」、友達の乾杯は「〇〇さんが△△さんと乾杯しました」）。人数が少ないハッカソン規模では十分で、フォロー解除が即反映される。
- 連続日数・合計日数・今週の日数は `days` を日付の新しい順に最大 400 件読んで Python で数える（1 年分）。

## 4. 各 API のサーバー側の振る舞い（契約との対応）

| API | 要点 |
|---|---|
| 共通 | `Authorization: Bearer` 必須（`/healthz` 以外）。初回アクセス時に `users/{uid}` を作る（名前はトークンの `name`、無ければメールの @ より前、無ければ「名無し」）。エラーは `{"error":{"code","message"}}` |
| `GET /me` | 契約の形 ＋ **`bestStreak`（これまでの最長連続日数）を追加**。画面のバッジ「3日つづいた」「1週間つづいた」は最長連続で判定している（`lib/data/achievements.dart`）が、契約に項目がなく画面側で計算できないため。`avatarUrl`・`favoriteProtein` は未設定なら `null` |
| `PUT /me/avatar` | 本文は生のバイト列。2MB 超 → 413 `TOO_LARGE`。先頭バイトが PNG/JPEG でない → 400 `BAD_IMAGE`。非公開バケットに `avatars/{uid}.png` として上書き保存し、`users.avatarUpdatedAt` を更新。`{"avatarUrl": "{PUBLIC_BASE_URL}/avatars/{uid}?v=<更新時刻>"}` を返す |
| `GET /avatars/{userId}` | **追加**。本人、または `userId` とフォロー関係（どちら向きでも）がある人だけ → 画像のバイト列（`Content-Type` は保存時の形式、`Cache-Control: private, max-age=86400`）。関係がない → 403 `FORBIDDEN`。画像なし → 404 |
| `DELETE /me/avatar` | 画像を消し `avatarUrl=null`。204 |
| `POST /shakes` | ①3 秒以内の連打 → 429 `TOO_MANY`。②`lastShakeAt` 更新。③今日の `days` が無ければ作り、ボーナス `10`（連続日数が 7 の倍数なら `+50`）。2 回目以降は 0。④フォロー中で `lastShakeAt` が 5 秒以内の友達がいれば乾杯：両者の `days.cheerWith` に追加（同じ日・同じ相手は 1 回。相手側は**相手が最後に振った日**の記録に書く。日付をまたいだ直後に、振っていない日の記録を作らないため）、両者に `cheer` イベント。`cheerWith` は最も直近の 1 人を返す。⑤今日初回なら `shake` イベント、連続日数が 3・7・14・30 または 7 の倍数なら `streak` イベント |
| `GET /shakes?month=YYYY-MM` | その月の `days` を `[{date, cheerWith:[名前]}]` で。`month` の形が違えば 400 |
| `GET /friends` | フォロー ∪ フォロワー（自分以外）。id を集めてから `users` をまとめて読む（1 回）。`shakingNow` = `lastShakeAt` が 10 秒以内、`shookToday` = `lastShakeDate` が今日 |
| `PUT/DELETE /follows/{id}` | 自分 → 400。相手が存在しない → 404 `NOT_FOUND`。`following` と相手の `followers` を両方書く。204 |
| `GET /feed?limit=20` | 上記 3 節。`limit` は 1〜50 に丸める |
| `POST /invites` | 乱数コード（URL 安全な 8 文字）を作り `{"url": INVITE_BASE_URL + "/invite/" + code}` |
| `POST /invites/{code}/accept` | **追加**。招待者と受け取った人を相互フォロー。自分の招待 → 400。無いコード → 404。`{"friend": {"id","name"}}` |
| `POST /protein/scan` | 10MB 超 → 413。PNG/JPEG 以外 → 400。5 秒以内の再送 → 429。Gemini に画像＋指示を送り、スキーマ `{is_protein_package, name, flavor, protein_grams}` で受け取る。`is_protein_package=false` や欠け → 422 `UNREADABLE`。Gemini 失敗 → 503 `AI_UNAVAILABLE`。保存はしない |
| `PUT /me/favorite-protein` | 3 項目を保存。204 |
| `GET /me/weekly-summary` | 今週の日数・連続・今週の乾杯回数・目標 5 日を Gemini に渡し、応援の 2 文（医療的助言の禁止を指示）。`{text, model, generatedAt}`。同じ週・同じ数字ならキャッシュを返す。Gemini 失敗 → 503 |
| `GET /healthz` | `{"ok": true}`。Cloud Run の確認用 |

## 5. 影響範囲

- **Flutter 側**：変更なし。接続は別工程。契約に追加した `POST /invites/{code}/accept` と `GET /friends` の範囲は、接続時に画面側で使う（招待リンクを開いたら受け取る流れが必要）。**アイコン画像は `avatarUrl` を ID トークン付きで取得して表示する必要がある**（Flutter Web の `Image.network` はヘッダー不可）。
- **提出物**：`backend/` と文書がそのまま提出用リポジトリにコピーされる。秘密情報は環境変数のみで、ファイルには置かない。
- **GCP**：Cloud Run・Firestore・Cloud Storage・Vertex AI を使う。Cloud Run の実行用サービスアカウントに権限を付けるだけで動き、**鍵ファイルや API キーは 1 つも要らない**（Application Default Credentials）。Firestore の問い合わせは単一項目の並べ替え・範囲だけなので複合インデックスは不要。クレジットの範囲で収まる想定（Cloud Run は 0 台まで縮む、Firestore/Storage は無料枠、Gemini は呼び出し回数を抑える）。
- **他のメンバーの環境**：CI は `backend/**` の変更時だけ追加で走る。Flutter の CI は変わらない。

## 6. テストと確認

| 種類 | 内容 | GCP 不要か |
|---|---|---|
| 単体（`tests/test_rules.py`） | 連続日数・7 日ボーナス・週の数え方・乾杯の窓・連打・成長段階・タイムラインの文 | 不要 |
| API（`tests/test_*.py`） | Memory store + dev 認証 + Fake Gemini/Storage + 固定時計で、契約の全エンドポイントの正常系とエラー（401/400/404/413/422/429/503） | 不要 |
| Firestore エミュレータ（`tests/integration/`） | Store の実装を本物の Firestore 互換で確認（作成・配列追加・月の検索・フォロー両書き） | 不要（Java + firebase CLI で実行） |
| 静的チェック | `ruff check` / `ruff format --check` | 不要 |
| 手動 | `STORE=memory AUTH_MODE=dev GEMINI=fake` でローカル起動し curl。2 ユーザーで 5 秒以内に振って乾杯を再現 | 不要 |
| **未確認として残るもの** | Vertex AI Gemini の実呼び出し、Cloud Storage への実アップロード、Cloud Run へのデプロイ、Docker ビルド（この Mac に docker が無い） | プロジェクト作成後に `backend/README.md` の手順で確認 |

## 7. 完了条件

1. 契約の全エンドポイントが実装され、`uv run pytest` が全て通る（エミュレータ試験含む）。
2. `ruff` が通る。
3. `backend/README.md` に、ローカル起動・環境変数・デプロイ・権限・確認コマンドが書いてある。
4. `docs/api-contract.md` が実装と一致している。
5. PR が作られ、実装と計画の違い・未確認事項が本文に書いてある（push 先は kotakota914 さんのコラボレーター追加かフォーク。push 前に確認する）。

## 8. 進め方と時間の目安（締切 11/10 17:00）

1. 骨組み（設定・認証・エラー・Store の約束・Memory store）＋ `/me` ＋ テスト基盤 — 1 時間
2. 振る・乾杯・カレンダー（rules.py を先にテスト駆動で） — 1.5 時間
3. 友達・フォロー・タイムライン・招待 — 1 時間
4. Gemini（Fake → 本物の呼び出しコード）・アイコン（Fake → Storage） — 1 時間
5. Firestore store ＋ エミュレータ試験 — 1.5 時間
6. Dockerfile・deploy.sh・README・契約の更新・CI — 1 時間
7. 自己レビュー 3 回、PR — 1 時間

## 9. 未決事項（人の判断が必要）

- （決定済み 2026-11-09 23:05）D3：招待リンクでつなぐ案で確定。D4：API 経由の配信で確定（推奨案の公開 URL ではなく、依頼者がログイン必須を選択）。
- リージョン：Cloud Run・Firestore・Storage は `asia-northeast1`（東京）。Gemini だけは `GEMINI_LOCATION` の既定を `global`（Vertex AI のグローバルエンドポイント。モデルの提供地域に左右されない）にし、必要なら環境変数で変える。

## 10. 自己レビューの記録

- 人の確認（23:05）：D3 招待リンク案で確定。D4 は推奨の公開 URL ではなく API 経由配信に変更 → `GET /avatars/{userId}` を追加、Storage は非公開、Flutter 側への影響を明記。
- 3 回目（運用・安全）：CI は ruff と pytest のみ（エミュレータ試験はローカルで実行。CI に Java と firebase CLI を入れる手間を避ける）。dev 認証のトークンは `dev:<uid>:<名前>` を最大 2 分割で読む。契約に「403 を返すのは `GET /avatars/{userId}` と `PUT /follows/{userId}` だけ」と明記する。
- 2 回目（データの流れ）：ユーザー文書に `lastShakeDate` を追加し、友達一覧の `shookToday` と乾杯の相手側の日付決定に使う（友達ごとに `days` を読まない）。フォロー関係の文書は id と時刻だけにし、名前は `users` から読む（名前変更に追従）。
- 1 回目（契約・画面コードとの突き合わせ）：`GET /me` に `bestStreak` を追加（バッジ判定に必要）。乾杯の相手側は「相手が最後に振った日」に書く。Gemini のリージョンは `global` 既定。鍵不要・索引不要を明記。

## 11. 計画レビュー（2026-11-09 23:15。Codex 用スキルが無いため、別文脈のレビュー用エージェントで代替）

15 件の指摘。採否と対応：

| # | 指摘 | 採否 | 対応 |
|---|---|---|---|
| 1 | FastAPI 既定の 422 / `{"detail"}` が契約と衝突 | 採用（実装済み） | `errors.py` で入力エラー → 400 `INVALID_ARGUMENT`、HTTP エラーも同じ封筒に変換。テストあり |
| 2 | 乾杯が「後から振った側」にしか出ない（順序依存） | 採用 → **D12** | `POST /shakes` は自分の記録を書いた後、フォロー中の友達の振りを**最大 5 秒**（`CHEER_WAIT_SECONDS`、0 で無効）待って読み直す。フォローしている人がいなければ待たない。相互フォロー条件には変えない（契約どおり「自分がフォローしている人」） |
| 3 | `backend/app/` と uv 雛形（src レイアウト）の矛盾 | 採用（実装済み） | `src/` を消し `[tool.uv] package = false`。`app/` に統一 |
| 4 | デプロイ前提（API 有効化・DB 作成・IAM・Cloud Shell）が未記載 | 採用 | `deploy.sh` と README に具体コマンドを書く（工程 6） |
| 5 | 同一ユーザーの同時 POST と 400 件読み | 採用 → **D13** | ユーザー文書に `streak / bestStreak / totalDays / totalCheers` をカウンタで持ち、振る処理は `Store.apply_shake`（Firestore トランザクション）で読んで決めて書く。`GET /me` は今週分（≤7 件）だけ読む |
| 6 | 書き順の明記と、同時検知時の二重書き | 採用 | 「自分の lastShakeAt を書いてから相手を読む」をコードに明記。乾杯は `Store.record_cheer`（トランザクション、同じ日・同じ相手なら何もしない）。出来事 ID は決定的（`cheer-日付-相手`） |
| 7 | google-genai 3.0 の `vertexai` は旧名、`response_schema` より `response_json_schema`、モデル提供は未確認 | 採用 | `enterprise=True`、`response_json_schema`。モデル名は環境変数で、README に「Model Garden で確認」を手順化。**既定 `gemini-2.5-flash` は未確認** |
| 8 | `PUT /follows/{userId}` が任意 uid を受け、D4 が弱まる | 採用 → **D14** | 相手が自分をフォローしている（招待でつながった）ときだけ許可。それ以外は 403。新しいつながりは招待リンクのみ |
| 9 | D10 と「firebase.json は触らない」の矛盾 | 採用 | D10 を「サーバーは `API_PREFIX` に対応。Hosting の rewrite 追加は接続工程の作業」に修正 |
| 10 | Memory store では Firestore 固有の不具合を拾えない | 採用 | `dates.jst_date_of` はタイムゾーン無しを拒否。Store 契約テストを memory / firestore（エミュレータ）の両方に流す。結果を PR に貼る |
| 11 | 見積が楽観。Firestore を前倒し | 採用 | 順序を「振る → Firestore＋エミュレータ → 友達・招待・Gemini → デプロイ文書」に変更。Memory store は小さいので残す |
| 12 | 「403 はどの API も返さない」の誤記 | 採用 | 修正済み |
| 13 | `POST /shakes` に points / totalDays / bestStreak / totalCheers を追加 | 採用 | 追加（契約に追記） |
| 14 | 招待コードが無期限 | 採用 | `expiresAt = 7 日後`。期限切れは 404 |
| 15 | `nosniff`、pyproject のメール・説明 | 採用 | 対応済み |

追加の設計判断（人の確認待ち。PR で提示）：
- **D12** 乾杯の待ち：振った人は最大 5 秒、結果が返るのを待つことになる（友達をフォローしている人だけ）。デモで両方の画面に乾杯を出すための選択。嫌なら `CHEER_WAIT_SECONDS=0`。
- **D13** カウンタ方式：連続日数などを都度計算せず保存する。書き込みはトランザクションなので二重計上しない。
- **D14** フォロー制限：uid を知っていても一方的にフォローできない。契約の `PUT /follows/{userId}` の意味が狭まる。
- タイムラインの「種類で絞る」問い合わせは Firestore で複合インデックスが要るため、約束から外し Python 側で絞る（インデックスのデプロイ手順を増やさないため）。

## 12. コードレビュー（2026-11-09 23:40。Codex 用スキルが無いため、別文脈のレビュー用エージェントで代替）

乾杯・トランザクションの中心部分、Firestore の問い合わせ（複合インデックス不要）、契約との形の一致、デプロイの各フラグに誤りは見つからなかった。指摘 12 件と対応：

| # | 指摘 | 採否 | 対応 |
|---|---|---|---|
| 1 | `async def` の入口で Gemini / Storage の同期呼び出しをしていて、その間サーバー全体が止まる | **必須・採用** | `run_in_threadpool` で別スレッドへ（`routers/protein.py`、`routers/me.py`） |
| 2 | `save_user` の丸ごと書き戻しで、並行する乾杯の加算を古い値で消す | 採用 | `Store.update_user_fields` を追加し、リクエスト処理ではこちらだけ使う。`save_user` はテストの準備用 |
| 3 | ログが無く、想定外の例外は封筒形式にならない | 採用 | `logging` を導入。Gemini・Firebase の失敗はログに残す。想定外の例外は 500 `INTERNAL` の封筒で返す |
| 4 | pydantic の JSON スキーマに Vertex が受け付けない `default` / `title` が含まれる | 採用 | `response_schema_for` で落としてから送る。テストあり。**本物の呼び出しは未確認** |
| 5 | 契約との食い違い（DELETE /follows の 404、avatarUrl の例、第三者名の扱い） | 採用 | DELETE は「相手がいなくても 204」に契約を修正。例と説明を直した |
| 6 | 毎リクエストで失敗する `create()` → `get()` の 2 往復 | 採用 | 先に `get()`、無いときだけ `create()` |
| 7 | 5 秒待ちがスレッドを占め、既定 40 本を超えると詰まる | 採用 | Cloud Run の同時実行数を 40 に設定（`deploy.sh`）。README に記載 |
| 8 | `deploy.sh` が作成失敗を「作成済み」と誤認する | 採用 | 有無を `describe` で調べてから作る。Cloud Build の権限の注意を README に追記 |
| 9 | `.gcloudignore` が無い | 採用 | 追加 |
| 10 | 招待 URL の既定が `API_PREFIX` を含む | 採用 | 起点（prefix 無し）に変更。テストあり |
| 11 | 古い出来事にも「今日の」と付く | 採用 | その日の出来事にだけ付ける |
| 12 | テストの穴 | 一部採用 | 名前の決め方、`API_PREFIX`、想定外例外の封筒、画像欠落の 404、Gemini 応答の解釈（偽クライアント）、招待 URL の既定、Cloud Run 上の起動拒否を追加 |
