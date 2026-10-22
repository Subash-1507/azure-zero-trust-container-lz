# syntax=docker/dockerfile:1
# Candidate: Chainguard Wolfi Python (rebuilt daily, minimal packages), base images pinned by digest.

# ---- build stage: root only here, to write the dependency folder
FROM cgr.dev/chainguard/python:latest-dev@sha256:7108dea9b9f31c30c20d43d17ecc61d4eb33789e9a8a10cd361e2ed37d8bd931 AS build
USER root
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --require-hashes --only-binary=:all: --target /build/deps -r requirements.txt
COPY src/ ./src/

# ---- runtime stage: no shell, no package manager, non-root
FROM cgr.dev/chainguard/python:latest@sha256:93c92d4ee2d0a4e540ec4de4e708267b45c2551a3c836fdf3e174a05017a76de
WORKDIR /app
COPY --from=build /build/deps ./deps
COPY --from=build /build/src ./src
ENV PYTHONPATH=/app/deps \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]
