#!/usr/bin/env bash
# Installs the tools that are not available as dev container features.
set -euo pipefail

# kubelogin: AKS sign-in with Entra ID (the cluster has local accounts disabled)
sudo az aks install-cli --only-show-errors >/dev/null

# Trivy from Aqua's signed apt repository (HTTPS only, TLS 1.2+, no downgrade on redirect)
sudo apt-get update -qq
sudo apt-get install -y -qq gnupg
curl -fsSL --proto '=https' --proto-redir '=https' --tlsv1.2 \
  https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list >/dev/null
sudo apt-get update -qq
sudo apt-get install -y -qq trivy

echo "Ready. Hadolint and Syft run as containers: see the Makefile (added in a later step)."