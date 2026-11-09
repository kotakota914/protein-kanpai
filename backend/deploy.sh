#!/usr/bin/env bash
# Cloud Run へのデプロイ台本。gcloud が入った環境で実行する（Cloud Shell を推奨。この Mac には gcloud が無い）。
#
#   PROJECT_ID=<GCP のプロジェクト ID> ./backend/deploy.sh
#
# 任意の環境変数：
#   REGION=asia-northeast1   SERVICE=protein-kanpai-api   BUCKET=<バケット名>
#   GEMINI_MODEL=gemini-2.5-flash  （Model Garden で提供中のモデル名に合わせる）
#   ALLOWED_ORIGINS=https://xxxx.web.app,https://xxxx.firebaseapp.com  （ブラウザ版の公開 URL）
#   PUBLIC_BASE_URL=https://<Cloud Run の URL>  （初回は空でよい。表示された URL を入れて再実行）
#   INVITE_BASE_URL=https://xxxx.web.app  （招待リンクの先。Hosting の URL）
#
# 2 回目以降は同じコマンドで更新される。戻すときは README の「止め方・戻し方」を見る。
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?GCP のプロジェクト ID を PROJECT_ID で指定してください}"
REGION="${REGION:-asia-northeast1}"
SERVICE="${SERVICE:-protein-kanpai-api}"
BUCKET="${BUCKET:-${PROJECT_ID}-protein-kanpai-avatars}"
SA_NAME="${SA_NAME:-protein-kanpai-api}"
SA="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
GEMINI_MODEL="${GEMINI_MODEL:-gemini-2.5-flash}"
ALLOWED_ORIGINS="${ALLOWED_ORIGINS:-}"
PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-}"
INVITE_BASE_URL="${INVITE_BASE_URL:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== プロジェクト: $PROJECT_ID / リージョン: $REGION"
gcloud config set project "$PROJECT_ID" >/dev/null

echo "== 使う API を有効にする"
gcloud services enable run.googleapis.com firestore.googleapis.com storage.googleapis.com \
  aiplatform.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com

echo "== Firestore（Native モード）"
# 「作成済み」と「作成に失敗」を区別するため、先に有無を調べてから作る（失敗はそのまま表示される）
if gcloud firestore databases describe --database="(default)" >/dev/null 2>&1; then
  echo "   作成済み"
else
  gcloud firestore databases create --location="$REGION" --type=firestore-native
fi

echo "== アイコン用の非公開バケット: gs://$BUCKET"
if gcloud storage buckets describe "gs://$BUCKET" >/dev/null 2>&1; then
  echo "   作成済み"
else
  gcloud storage buckets create "gs://$BUCKET" --location="$REGION" \
    --uniform-bucket-level-access --public-access-prevention
fi

echo "== 実行用サービスアカウント: $SA"
if gcloud iam service-accounts describe "$SA" >/dev/null 2>&1; then
  echo "   作成済み"
else
  gcloud iam service-accounts create "$SA_NAME" --display-name="protein-kanpai API"
fi
for role in roles/datastore.user roles/aiplatform.user; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA" \
    --role="$role" --condition=None >/dev/null
done
gcloud storage buckets add-iam-policy-binding "gs://$BUCKET" --member="serviceAccount:$SA" \
  --role="roles/storage.objectAdmin" >/dev/null

# 区切りを ; にしているのは、ALLOWED_ORIGINS がカンマを含むため（gcloud の ^;^ 記法）
ENV_VARS="^;^AUTH_MODE=firebase;STORE=firestore;GEMINI=vertex;STORAGE=gcs"
ENV_VARS="$ENV_VARS;GOOGLE_CLOUD_PROJECT=$PROJECT_ID;AVATAR_BUCKET=$BUCKET"
ENV_VARS="$ENV_VARS;GEMINI_MODEL=$GEMINI_MODEL;GEMINI_LOCATION=global"
[ -n "$ALLOWED_ORIGINS" ] && ENV_VARS="$ENV_VARS;ALLOWED_ORIGINS=$ALLOWED_ORIGINS"
[ -n "$PUBLIC_BASE_URL" ] && ENV_VARS="$ENV_VARS;PUBLIC_BASE_URL=$PUBLIC_BASE_URL"
[ -n "$INVITE_BASE_URL" ] && ENV_VARS="$ENV_VARS;INVITE_BASE_URL=$INVITE_BASE_URL"

echo "== Cloud Run にデプロイ（Cloud Build でビルド）"
gcloud run deploy "$SERVICE" --source "$HERE" --region "$REGION" \
  --service-account "$SA" --allow-unauthenticated \
  --set-env-vars "$ENV_VARS" --max-instances 3 --memory 512Mi --cpu 1 --concurrency 40

URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format 'value(status.url)')"
echo
echo "API の URL: $URL"
echo "動作確認:   curl $URL/healthz"
echo "Gemini の確認（ログイン済みの ID トークンが要る）: README の手順 7〜8"
if [ -z "$PUBLIC_BASE_URL" ]; then
  echo "次に PUBLIC_BASE_URL=$URL を付けて再実行すると、avatarUrl がこの URL で返ります。"
fi
