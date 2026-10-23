# syntax=docker/dockerfile:1
# Hardened API image: Chainguard Wolfi Python (rebuilt daily), base images pinned by digest.
# checkov:skip=CKV_DOCKER_2: Kubernetes ignores Docker HEALTHCHECK; liveness/readiness probes on /healthz are defined in the Kubernetes manifests

# ---- build stage: stays on the image's non-root user and installs hash-locked deps into /tmp
FROM cgr.dev/chainguard/python:latest-dev@sha256:7108dea9b9f31c30c20d43d17ecc61d4eb33789e9a8a10cd361e2ed37d8bd931 AS build
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --require-hashes --only-binary=:all: --target /tmp/deps -r /tmp/requirements.txt

# ---- runtime stage: no shell, no package manager, non-root; files owned by root so the app cannot modify its own code
FROM cgr.dev/chainguard/python:latest@sha256:93c92d4ee2d0a4e540ec4de4e708267b45c2551a3c836fdf3e174a05017a76de
WORKDIR /app
COPY --from=build /tmp/deps ./deps
COPY src/ ./src/
ENV PYTHONPATH=/app/deps \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]