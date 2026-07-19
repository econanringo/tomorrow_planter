#!/usr/bin/env bash
# Create a Firestore vector index for memories.embedding (768 dims).
# Requires gcloud and project tomorrow-planter.

set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-tomorrow-planter}"
DATABASE="(default)"

echo "Creating vector index on users/{uid}/memories.embedding (dim=768)..."
echo "If this fails, create it in Firebase Console > Firestore > Indexes > Vector."

gcloud firestore indexes composite create \
  --project="${PROJECT_ID}" \
  --database="${DATABASE}" \
  --collection-group=memories \
  --query-scope=COLLECTION \
  --field-config=field-path=embedding,vector-config='{"dimension":"768","flat":"{}"}' \
  || true

echo "Done (or already exists)."
