# syntax=docker/dockerfile:1
# Hardened web tier: Chainguard nginx (Wolfi), non-root, no shell, base image pinned by digest.
# checkov:skip=CKV_DOCKER_2: Kubernetes ignores Docker HEALTHCHECK; liveness/readiness probes on /healthz are defined in the Kubernetes manifests
FROM cgr.dev/chainguard/nginx:latest@sha256:16d0e55ffe62f55744d9b903d8eb57e533d0f660332a9fbb967d78b4e77c8bdb
COPY nginx.conf /etc/nginx/nginx.conf
COPY static/ /usr/share/nginx/html/
USER 65532:65532
EXPOSE 8080