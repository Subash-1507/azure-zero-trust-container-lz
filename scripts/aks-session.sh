#!/usr/bin/env bash
# Begin or end a working session on the dev cluster.
#   start: start the cluster, then open just-in-time access (API server, Key Vault, Storage) for this machine's IP
#   stop:  close just-in-time access (apply without admin_ip), then stop the cluster so the node costs nothing
# Terraform shows its plan and asks for "yes": only firewall and API server IP lists should change.
set -euo pipefail

action="${1:?usage: $0 start|stop}"
tf_dir="$(cd "$(dirname "$0")/../infra/terraform/envs/dev" && pwd)"
rg="rg-ztlz-dev"
aks="aks-ztlz-dev"

case "$action" in
  start)
    az aks start -g "$rg" -n "$aks" -o none
    terraform -chdir="$tf_dir" apply -var "admin_ip=$(curl -fsS https://api.ipify.org)"
    az aks get-credentials -g "$rg" -n "$aks" --overwrite-existing -o none
    kubelogin convert-kubeconfig -l azurecli
    kubectl get nodes
    ;;
  stop)
    terraform -chdir="$tf_dir" apply
    az aks stop -g "$rg" -n "$aks" -o none
    echo "power state: $(az aks show -g "$rg" -n "$aks" --query powerState.code -o tsv)"
    ;;
  *)
    echo "usage: $0 start|stop" >&2
    exit 1
    ;;
esac