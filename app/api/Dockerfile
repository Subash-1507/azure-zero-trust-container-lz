# syntax=docker/dockerfile:1
# Hardened API image: Chainguard Wolfi Python (rebuilt daily), base images pinned by digest.
# checkov:skip=CKV_DOCKER_2: Kubernetes ignores Docker HEALTHCHECK; liveness/readiness probes on /healthz are defined in the Kubernetes manifests

# ---- build stage: stays on the image's non-root user and installs hash-locked deps into /tmp
FROM cgr.dev/chainguard/python:latest-dev@sha256:9bff0d7edba90589c302b2e08014340b0b4c718fba28ff0326b519771e379c0a AS build
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --require-hashes --only-binary=:all: --target /tmp/deps -r /tmp/requirements.txt

# ---- runtime stage: no shell, no package manager, non-root; files owned by root so the app cannot modify its own code
FROM cgr.dev/chainguard/python:latest@sha256:8d518c3454134ac288e7efd0460d0e9856a046f60e23dc0d2cd02161195bda3e
WORKDIR /app
COPY --from=build /tmp/deps ./deps
COPY src/ ./src/
ENV PYTHONPATH=/app/deps \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]