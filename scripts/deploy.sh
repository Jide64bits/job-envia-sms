#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-us-central1}"
JOB_NAME="${JOB_NAME:-envia-sms}"
SCHEDULER_NAME="${SCHEDULER_NAME:-envia-sms-daily}"
SCHEDULE="${SCHEDULE:-0 9 * * *}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-}"

SECRETS="ENV=ENV:latest,DATABASE_URL=DATABASE_URL:latest,EVOLUTION_BASE_URL=EVOLUTION_BASE_URL:latest,EVOLUTION_INSTANCE=EVOLUTION_INSTANCE:latest,EVOLUTION_API_KEY=EVOLUTION_API_KEY:latest"

if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "None" ]]; then
  echo "Erro: defina PROJECT_ID (ex: export PROJECT_ID=seu-projeto)."
  exit 1
fi

echo "Projeto: $PROJECT_ID | Região: $REGION | Job: $JOB_NAME"

gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  cloudscheduler.googleapis.com \
  secretmanager.googleapis.com \
  --project="$PROJECT_ID"

if ! gcloud artifacts repositories describe jobs --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "Criando repositório de artefatos 'jobs'..."
  gcloud artifacts repositories create jobs \
    --repository-format=docker \
    --location="$REGION" \
    --project="$PROJECT_ID"
else
  echo "Repositório de artefatos 'jobs' já existe."
fi

IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/jobs/${JOB_NAME}:latest"
gcloud builds submit \
  --config=cloudbuild.yaml \
  --substitutions="_REGION=$REGION,_JOB_NAME=$JOB_NAME" \
  --project="$PROJECT_ID"

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
if [[ -z "$SERVICE_ACCOUNT" ]]; then
  SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
fi

if gcloud run jobs describe "$JOB_NAME" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "Atualizando job existente..."
  gcloud run jobs update "$JOB_NAME" \
    --image="$IMAGE" \
    --region="$REGION" \
    --service-account="$SERVICE_ACCOUNT" \
    --tasks=1 \
    --max-retries=2 \
    --task-timeout=3600s \
    --set-secrets="$SECRETS" \
    --project="$PROJECT_ID"
else
  echo "Criando job..."
  gcloud run jobs create "$JOB_NAME" \
    --image="$IMAGE" \
    --region="$REGION" \
    --service-account="$SERVICE_ACCOUNT" \
    --tasks=1 \
    --max-retries=2 \
    --task-timeout=3600s \
    --set-secrets="$SECRETS" \
    --project="$PROJECT_ID"
fi

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/run.invoker" \
  --condition=None \
  --project="$PROJECT_ID" >/dev/null 2>&1 || echo "Permissão run.invoker já configurada."

URI="https://${REGION}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${PROJECT_ID}/jobs/${JOB_NAME}:run"
AUDIENCE="$URI"

if gcloud scheduler jobs describe "$SCHEDULER_NAME" --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "Atualizando scheduler..."
  gcloud scheduler jobs update http "$SCHEDULER_NAME" \
    --schedule="$SCHEDULE" \
    --uri="$URI" \
    --http-method=POST \
    --oidc-service-account-email="$SERVICE_ACCOUNT" \
    --oidc-token-audience="$AUDIENCE" \
    --location="$REGION" \
    --project="$PROJECT_ID"
else
  echo "Criando scheduler..."
  gcloud scheduler jobs create http "$SCHEDULER_NAME" \
    --schedule="$SCHEDULE" \
    --uri="$URI" \
    --http-method=POST \
    --oidc-service-account-email="$SERVICE_ACCOUNT" \
    --oidc-token-audience="$AUDIENCE" \
    --location="$REGION" \
    --project="$PROJECT_ID"
fi

echo "Deploy concluído. Para testar: gcloud run jobs execute $JOB_NAME --region=$REGION --project=$PROJECT_ID"
