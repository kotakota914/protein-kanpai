# バックエンド API（Cloud Run / FastAPI）

`docs/api-contract.md` の API を Python 3.13 + FastAPI で実装したもの。保存先は Firestore、アイコン画像は Cloud Storage（非公開）、AI は Vertex AI の Gemini。

```
スマホのブラウザ / iPhone アプリ ──(ID トークン付き HTTPS)──▶ Cloud Run（この API）
                                                              ├─▶ Firestore（記録・フォロー・招待）
                                                              ├─▶ Cloud Storage（アイコン画像）
                                                              └─▶ Vertex AI Gemini（袋の読み取り・ふりかえり）
```

鍵ファイルや API キーは使わない。Cloud Run の実行用サービスアカウントに権限を付けるだけで動く。

## フォルダ

```
app/
├── main.py          アプリの組み立て（CORS・エラー変換・/healthz）。設定で本物と「代わり」を選ぶ
├── config.py        環境変数 → 設定。Cloud Run 上でテスト用設定なら起動を拒否
├── auth.py          Authorization: Bearer の検証（firebase / dev）
├── deps.py          ルーターが使う依存の取り出し
├── errors.py        {"error": {"code", "message"}} への変換
├── schemas.py       API の JSON の形（契約と 1:1）
├── dates.py         日本時間の日付・ISO 8601
├── rules.py         連続日数・ボーナス・乾杯の窓・連打の計算（純粋な関数）
├── store/           保存先。base.py が約束、memory.py と firestore.py が実装
├── services/        shakes（振る判断・乾杯相手の探索）、profile（集計）、gemini、storage、images
└── routers/         me / shakes / friends / protein
tests/               pytest。store_contract.py は memory と firestore の両方に流す
deploy.sh            Cloud Run へのデプロイ台本（gcloud が要る）
Dockerfile           Cloud Build が使う
firebase.json        Firestore エミュレータ用（Hosting 用はリポジトリ直下の firebase.json）
```

## ローカルで動かす（GCP なし）

[uv](https://docs.astral.sh/uv/) が必要。

```bash
cd backend && uv sync
```

```bash
cd backend && uv run uvicorn app.main:app --reload --port 8000
```

既定の設定は全部「代わり」（`STORE=memory`、`AUTH_MODE=dev`、`GEMINI=fake`、`STORAGE=fake`）なので、そのまま動く。データはプロセスを止めると消える。

dev 認証では `Authorization: Bearer dev:<uid>:<名前>` をそのまま信じる（名前は URL エンコード）。

```bash
curl -s -X POST http://localhost:8000/shakes -H "Authorization: Bearer dev:u1:kotaro" | jq
```

```bash
curl -s http://localhost:8000/me -H "Authorization: Bearer dev:u1:kotaro" | jq
```

2 人で乾杯を再現する（u1 が u2 をフォローした状態を招待で作ってから、5 秒以内に両方で振る）：

```bash
URL=$(curl -s -X POST http://localhost:8000/invites -H "Authorization: Bearer dev:u1:kotaro" | jq -r .url); CODE=${URL##*/}; curl -s -X POST "http://localhost:8000/invites/$CODE/accept" -H "Authorization: Bearer dev:u2:hanako"; curl -s -X POST http://localhost:8000/shakes -H "Authorization: Bearer dev:u2:hanako" & sleep 1; curl -s -X POST http://localhost:8000/shakes -H "Authorization: Bearer dev:u1:kotaro"; wait
```

## テスト

```bash
cd backend && uv run ruff check app tests && uv run pytest -q
```

Firestore 実装は本物と同じ動きをするエミュレータで確かめる（Java と firebase CLI が必要。初回は `firebase setup:emulators:firestore`）：

```bash
cd backend && firebase emulators:exec --only firestore --project demo-kanpai "uv run pytest tests/test_store_firestore.py -q"
```

## 環境変数

| 変数 | 既定 | 意味 |
|---|---|---|
| `STORE` | `memory` | `firestore` で Firestore |
| `AUTH_MODE` | `dev` | `firebase` で Firebase Authentication の ID トークンを検証 |
| `GEMINI` | `fake` | `vertex` で Vertex AI Gemini |
| `STORAGE` | `fake` | `gcs` で Cloud Storage |
| `GOOGLE_CLOUD_PROJECT` | — | GCP プロジェクト ID |
| `FIREBASE_PROJECT_ID` | = GOOGLE_CLOUD_PROJECT | Firebase のプロジェクト ID（通常は同じ） |
| `AVATAR_BUCKET` | — | アイコン画像のバケット名（`STORAGE=gcs` で必須） |
| `GEMINI_MODEL` | `gemini-2.5-flash` | モデル名。**Model Garden で提供中か確認する** |
| `GEMINI_LOCATION` | `global` | Vertex AI のロケーション |
| `PUBLIC_BASE_URL` | リクエストの Host | `avatarUrl` に使う外から見える API の URL |
| `INVITE_BASE_URL` | = PUBLIC_BASE_URL | 招待リンクの先（Hosting の URL） |
| `API_PREFIX` | 空 | Hosting の rewrite で `/api` に向けるなら `/api` |
| `ALLOWED_ORIGINS` | 空 | CORS で許可する公開 URL（カンマ区切り）。localhost は既定で許可 |
| `CHEER_WAIT_SECONDS` | `5` | 先に振った側のために相手の振りを待つ最大秒数。`0` で待たない。待ちは 1 件につき 1 スレッドを占めるので、Cloud Run の同時実行数は 40（`deploy.sh`）に合わせてある |

Cloud Run 上（環境変数 `K_SERVICE` あり）で `memory` / `dev` / `fake` が残っていると起動しない。

## Cloud Run にデプロイする

この Mac には gcloud が無いので、[Cloud Shell](https://shell.cloud.google.com) か gcloud を入れた環境で行う。

1. 代表者がクレジットを引き換え、GCP プロジェクトを作る（請求先アカウントにクレジットが付く）。
2. Firebase を有効にする：`firebase projects:addfirebase <PROJECT_ID>`。Firebase コンソール → Authentication → Sign-in method で **Google** を有効化。
3. リポジトリを clone して台本を実行：

```bash
PROJECT_ID=<PROJECT_ID> ./backend/deploy.sh
```

4. 表示された URL で確認：

```bash
curl https://<API の URL>/healthz
```

5. `PUBLIC_BASE_URL`（手順 4 の URL）、`ALLOWED_ORIGINS`（Hosting の URL）、`INVITE_BASE_URL` を付けて再実行。
6. Gemini の確認：Vertex AI の Model Garden で `GEMINI_MODEL` のモデルが使えるか見る。無ければ提供中の Flash 系に変えて再実行。
7. 本物の ID トークンで確認（Firebase Auth で Google ログインしたブラウザの開発者ツールで `firebase.auth().currentUser.getIdToken()` を取る）：

```bash
curl -s https://<API の URL>/me -H "Authorization: Bearer <ID トークン>"
```

8. **Gemini と Storage を 1 回ずつ本当に呼ぶ**（ここまで実行されたことがない経路なので、ログを開いたまま）：

```bash
curl -s -X POST https://<API の URL>/protein/scan -H "Authorization: Bearer <ID トークン>" --data-binary @袋の写真.jpg
```

```bash
curl -s https://<API の URL>/me/weekly-summary -H "Authorization: Bearer <ID トークン>"
```

```bash
gcloud run services logs read protein-kanpai-api --region asia-northeast1 --limit 50
```

失敗は画面には「いまは使えません」としか出ないが、ログに Gemini のエラー内容（モデル名の誤り、権限不足、スキーマ拒否）が残る。

- `gcloud run deploy --source` は Cloud Build でビルドする。新しいプロジェクトなら既定のサービスアカウントで動く。組織のポリシーで権限が絞られていて失敗する場合は、Compute Engine の既定サービスアカウントに `roles/cloudbuild.builds.builder` を付ける。

台本がやること：API の有効化、Firestore（Native）の作成、非公開バケットの作成、実行用サービスアカウントの作成と権限付与（`roles/datastore.user`、`roles/aiplatform.user`、バケットに `roles/storage.objectAdmin`）、`gcloud run deploy --source` によるビルドとデプロイ。

## 止め方・戻し方

- 前の版に戻す：`gcloud run revisions list --service protein-kanpai-api --region asia-northeast1` で版を確認し、`gcloud run services update-traffic protein-kanpai-api --region asia-northeast1 --to-revisions <REVISION>=100`
- 止める：`gcloud run services delete protein-kanpai-api --region asia-northeast1`（データは Firestore と バケットに残る）
- Gemini だけ止める：環境変数 `GEMINI=fake` にすると起動を拒否するので、代わりに Flutter 側で機能を隠す

## 設計上の決めごと（詳細は `design-docs-for-ai/backend-api-plan.md`）

- 日付は日本時間で区切る。時刻は UTC。「今日」はサーバー時刻で決める。
- 振る処理は 1 回のトランザクション。3 秒以内の連打は 429。連続日数・最長連続・合計日数・乾杯回数はユーザー文書のカウンタ。
- 乾杯は「自分がフォローしている人が前後 5 秒以内に振った」とき。先に振った側の画面にも出すため、`POST /shakes` は最大 5 秒だけ相手を待つ（フォローしている人がいなければ待たない）。
- 友達一覧はフォロー関係のある人だけ。新しい友達は招待リンク（7 日で失効）。`PUT /follows/{userId}` は相手が自分をフォローしているときだけ許可。
- アイコン画像は非公開バケットに置き、`GET /avatars/{userId}` が本人と友達にだけ返す。

## 未確認のこと

- Vertex AI Gemini の実呼び出し、Cloud Storage への実アップロード、Cloud Run へのデプロイ、Docker ビルド（この Mac に docker と gcloud が無い）。プロジェクト作成後に上の手順で確認する。
