#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
ENV_FILE="${ENV_FILE:-.env}"

if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "None" ]]; then
  echo "Erro: defina PROJECT_ID (ex: export PROJECT_ID=seu-projeto)."
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Erro: arquivo $ENV_FILE não encontrado na raiz do projeto."
  exit 1
fi

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo "Projeto: $PROJECT_ID"
echo "Service account padrão: $SA"

grep -v '^#' "$ENV_FILE" | grep '=' | grep -E '^[A-Za-z][A-Za-z0-9_]*=' | while IFS='=' read -r key value; do
  if gcloud secrets describe "$key" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "Secret $key já existe. Adicionando nova versão..."
    gcloud secrets versions add "$key" --data-file=<(printf '%s' "$value") --project="$PROJECT_ID" >/dev/null
  else
    echo "Criando secret $key..."
    printf '%s' "$value" | gcloud secrets create "$key" --data-file=- --replication-policy=automatic --project="$PROJECT_ID" >/dev/null
  fi

  gcloud secrets add-iam-policy-binding "$key" \
    --member="serviceAccount:$SA" \
    --role="roles/secretmanager.secretAccessor" \
    --project="$PROJECT_ID" >/dev/null
  echo "Permissão de leitura concedida para $key."
done

echo "Secrets prontos no Secret Manager."
