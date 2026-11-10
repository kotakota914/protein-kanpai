# 依頼：バックエンド（API サーバー）の実装

- 日付：2026-11-09（締切：2026-11-10 17:00、提出用リポジトリ df-2026-t071）
- 依頼者：naminamina（team KIT）
- 依頼の言葉：「（Google Cloud のクレジットが届いた）らしいのでバックエンドを実装しておこう」

## 合意した要件（2026-11-09 22:30 ごろ）

| 論点 | 決定 |
|---|---|
| 言語・枠組み | Python 3.13 + FastAPI（Cloud Run に載せる） |
| 範囲 | `docs/api-contract.md` の全エンドポイント。優先順：振る・乾杯・カレンダー → 友達・タイムライン → Gemini（袋の読み取り・ふりかえり）→ アイコン・招待 |
| 対象外 | Flutter 側の接続（`AppRepository` の差し替え）、GCP / Firebase プロジェクトの作成、クレジットの引き換え、実際のデプロイ（手順と台本は用意する） |
| 置き場所 | このリポジトリの `backend/`（提出用リポジトリへのコピーに自動で含まれる） |
| 作業フォルダ | `~/protein-kanpai`、ブランチ `backend-api` |

## 前提として確認した事実

- 画面（Flutter Web / iOS）は実装済みで全て仮データ。データの窓口は `lib/data/app_repository.dart`。
- API の仕様は `docs/api-contract.md`（「バックエンド担当と合意するまでは案」）。
- 運営の提出用リポジトリでは GitHub Actions / Pages が使えない。開発はここで行い、`scripts/export-to-submission.sh` で最新ファイルだけをコピーして提出する。
- 秘密情報（クレジットコード、サービスアカウント鍵、API キー）はリポジトリに入れない。
