#!/usr/bin/env bash
# Deploys the notes app to AKS. Tenant, client ID and vault name flow from Terraform outputs into the
# git-ignored k8s/azure.env, so those identifiers never live in the repository.
set -euo pipefail
cd "$(dirname "$0")/.."
tf() { terraform -chdir=infra/terraform/envs/dev output -raw "$1"; }

cat > k8s/azure.env <<EOF
API_CLIENT_ID=$(tf api_identity_client_id)
TENANT_ID=$(tf tenant_id)
KEY_VAULT_NAME=$(tf key_vault_name)
AZURE_TABLE_ENDPOINT=https://$(tf storage_account_name).table.core.windows.net
EOF

kubectl apply -k k8s
kubectl -n notes rollout status deployment/api --timeout=180s
kubectl -n notes rollout status deployment/web --timeout=120s
kubectl -n notes get pods -o wide
