# syntax=docker/dockerfile:1
# Hardened web tier: Chainguard nginx (Wolfi), non-root, no shell, base image pinned by digest.
# checkov:skip=CKV_DOCKER_2: Kubernetes ignores Docker HEALTHCHECK; liveness/readiness probes on /healthz are defined in the Kubernetes manifests
FROM cgr.dev/chainguard/nginx:latest@sha256:5b397d323878cd75f6c6968b2836bf5497b6e2d29f0cd7609f8d9d03ea6db2e6
COPY nginx.conf /etc/nginx/nginx.conf
COPY static/ /usr/share/nginx/html/
USER 65532:65532
EXPOSE 8080