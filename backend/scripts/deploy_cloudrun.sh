#!/usr/bin/env bash
# Build Flutter web, bundle into FastAPI, deploy one Cloud Run service.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_ID="${PROJECT_ID:-tomorrow-planter}"
REGION="${REGION:-asia-northeast1}"
SERVICE="${SERVICE:-tomorrow-planter}"
SA_EMAIL="${SA_EMAIL:-tomorrow-planter-backend@${PROJECT_ID}.iam.gserviceaccount.com}"

cd "${ROOT}"
flutter build web --release

rm -rf backend/app/static
mkdir -p backend/app/static
cp -R build/web/. backend/app/static/

cd backend
gcloud run deploy "${SERVICE}" \
  --source=. \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --service-account="${SA_EMAIL}" \
  --allow-unauthenticated \
  --memory=1Gi \
  --cpu=1 \
  --timeout=300 \
  --set-env-vars="GCP_PROJECT_ID=${PROJECT_ID},GCP_LOCATION=${REGION},FIREBASE_PROJECT_ID=${PROJECT_ID},GEMINI_MODEL=gemini-3.5-flash,EMBEDDING_MODEL=text-embedding-004,CORS_ORIGINS=*"

URL="$(gcloud run services describe "${SERVICE}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format='value(status.url)')"

echo ""
echo "Deployed: ${URL}"
echo "Health:   ${URL}/health"
echo ""
echo "Add this host to Firebase Auth → Authorized domains:"
echo "  $(echo "${URL}" | sed -E 's|https?://||')"
