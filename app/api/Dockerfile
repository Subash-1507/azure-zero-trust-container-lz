# syntax=docker/dockerfile:1
# Hardened API image: Chainguard Wolfi Python (rebuilt daily), base images pinned by digest.
# checkov:skip=CKV_DOCKER_2: Kubernetes ignores Docker HEALTHCHECK; liveness/readiness probes on /healthz are defined in the Kubernetes manifests

# ---- build stage: stays on the image's non-root user and installs hash-locked deps into /tmp
FROM cgr.dev/chainguard/python:latest-dev@sha256:c179c7d8e23caed59a51ff74d4742f8f8d3f16af4c33c40acaf8d3ee07234592 AS build
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --require-hashes --only-binary=:all: --target /tmp/deps -r /tmp/requirements.txt

# ---- runtime stage: no shell, no package manager, non-root; files owned by root so the app cannot modify its own code
FROM cgr.dev/chainguard/python:latest@sha256:fd6d0771e8ec99b1710dfc3d72ca19ba2ff6b14f72b7978922ab0c8acb72c3f3
WORKDIR /app
COPY --from=build /tmp/deps ./deps
COPY src/ ./src/
ENV PYTHONPATH=/app/deps \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]