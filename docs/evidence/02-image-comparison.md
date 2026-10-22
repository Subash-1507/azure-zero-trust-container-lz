# Container image hardening: before and after

API image, same code and same hash-locked dependencies. Scanned 2026-10-22 with Trivy 0.76.1.

| | Naive (`Dockerfile.naive`) | Distroless Debian 12 | **Wolfi / Chainguard (`Dockerfile`)** |
|---|---|---|---|
| Base image | `python:3.11` (floating tag, became Debian 13) | `gcr.io/distroless/python3-debian12:nonroot` | `cgr.dev/chainguard/python` pinned by digest |
| Python | 3.11 | 3.11.2 | 3.15.0 |
| Image size | 1.65 GB | 105 MB | 132 MB |
| Known CVEs | 3,493 | 293 (156 already fixable upstream) | **0** |
| Critical / High | 24 / 411 | 2 / 61 | **0 / 0** |
| User | root (UID 0) | non-root (UID 65532) | non-root (UID 65532) |
| Shell in image | yes | none | none |
| Runs with read-only filesystem and all capabilities dropped | not tested | yes | yes |

**Decision:** Wolfi. It is about 27 MB larger than distroless but has no known vulnerabilities, because it is rebuilt daily, while distroless inherits Debian's slower patch cycle.

**Accepted trade-off:** the free Chainguard tier publishes only `latest`. The image is pinned by digest for reproducibility, and Dependabot proposes digest updates so it does not go stale.
