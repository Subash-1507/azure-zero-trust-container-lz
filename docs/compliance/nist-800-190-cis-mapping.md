# Compliance mapping: NIST SP 800-190 and the CIS AKS Benchmark

[NIST SP 800-190](https://csrc.nist.gov/pubs/sp/800/190/final), the *Application Container Security Guide*, groups container risks into five areas (section 4). This page maps every one of its 23 risks to what this landing zone does, where the control is enforced, and the evidence that it works.

| Status | Meaning |
|---|---|
| ✅ | Control in place and verified with evidence |
| 🟡 | Control in place, with a documented gap (see [Gaps](#gaps-and-what-production-would-do)) |

**Result: 13 ✅, 10 🟡, none unaddressed.** Every 🟡 is a deliberate budget or scope decision, recorded with its production alternative.

Evidence files are in [docs/evidence](../evidence/).

## 4.1 Image risks

| Risk | Control in this project | Enforced by | Evidence | Status |
|---|---|---|---|---|
| 4.1.1 Image vulnerabilities | Wolfi (Chainguard) and Chainguard nginx bases pinned by digest: 3,493 known CVEs reduced to 0. Trivy fails CI on fixable HIGH/CRITICAL; Dependabot proposes digest updates; Defender rescans the registry | CI (Trivy), Defender for Containers | [02](../evidence/02-image-comparison.md), [07](../evidence/07-break-fix-admission-and-runtime.txt) test 3a | ✅ |
| 4.1.2 Image configuration defects | Non-root user (UID 65532), no shell or package manager in the final image; Hadolint fails on warnings; Checkov Dockerfile checks | CI (Hadolint, Checkov) | [02](../evidence/02-image-comparison.md), [08](../evidence/08-checkov-kubernetes.txt) | ✅ |
| 4.1.3 Embedded malware | Minimal images from a trusted publisher, pinned by digest; Defender detects suspicious processes at runtime | CI, Defender for Containers | [07](../evidence/07-break-fix-admission-and-runtime.txt) test 3b | 🟡 |
| 4.1.4 Embedded clear-text secrets | Gitleaks scans the full git history; Trivy and Checkov scan for secrets (one narrow, documented allow rule); runtime secrets come only from Key Vault | CI, design | [06](../evidence/06-app-deployment.txt) | ✅ |
| 4.1.5 Use of untrusted images | Azure Policy denies any image that is not from this project's registry; deployments reference images by digest | Azure Policy (Gatekeeper) | [07](../evidence/07-break-fix-admission-and-runtime.txt) test 1 | ✅ |

## 4.2 Registry risks

| Risk | Control in this project | Enforced by | Evidence | Status |
|---|---|---|---|---|
| 4.2.1 Insecure connections to registries | HTTPS only; nodes pull with the kubelet's managed identity (AcrPull), admin user disabled | ACR, Azure RBAC | [05](../evidence/05-aks-cluster.txt) | ✅ |
| 4.2.2 Stale images in registries | Deployments pin digests, so a stale or re-pushed tag is never pulled by mistake; Defender rescans stored images; test images deleted after use | Kustomize, Defender | [06](../evidence/06-app-deployment.txt), [07](../evidence/07-break-fix-admission-and-runtime.txt) | 🟡 |
| 4.2.3 Insufficient authentication and authorization | Entra ID required (admin user off); only the kubelet identity can pull | ACR, Azure RBAC | [04](../evidence/04-landing-zone-compliance.txt) | 🟡 |

## 4.3 Orchestrator risks

| Risk | Control in this project | Enforced by | Evidence | Status |
|---|---|---|---|---|
| 4.3.1 Unbounded administrative access | Entra ID with Azure RBAC for Kubernetes; local accounts and run command disabled; a static admin kubeconfig is refused | AKS configuration | [05](../evidence/05-aks-cluster.txt) | ✅ |
| 4.3.2 Unauthorized access | API server allow-list: the cluster's own egress IP, plus my IP only during a work session (just in time) | Terraform, `scripts/aks-session.sh` | [05](../evidence/05-aks-cluster.txt) | 🟡 |
| 4.3.3 Poorly separated inter-container network traffic | Calico default deny, then explicit allows: web to api on port 8080 only, DNS, api to HTTPS | NetworkPolicy | [06](../evidence/06-app-deployment.txt) | ✅ |
| 4.3.4 Mixing of workload sensitivity levels | The app has its own namespace with Pod Security `restricted`; test workloads run in a separate namespace | Namespaces, Pod Security Admission | [06](../evidence/06-app-deployment.txt), [07](../evidence/07-break-fix-admission-and-runtime.txt) | 🟡 |
| 4.3.5 Orchestrator node trust | AKS-managed control plane and node bootstrap; Azure Linux nodes with host encryption; kubelet uses a managed identity | AKS | [05](../evidence/05-aks-cluster.txt) | ✅ |

## 4.4 Container risks

| Risk | Control in this project | Enforced by | Evidence | Status |
|---|---|---|---|---|
| 4.4.1 Vulnerabilities in the runtime software | Node OS channel `SecurityPatch` and Kubernetes `patch` auto-upgrade keep containerd and the kubelet patched | AKS upgrade channels | [05](../evidence/05-aks-cluster.txt) | 🟡 |
| 4.4.2 Unbounded network access from containers | web may reach only the api; the api may reach only HTTPS on public addresses, with private ranges and the instance metadata endpoint blocked | NetworkPolicy | [06](../evidence/06-app-deployment.txt) | 🟡 |
| 4.4.3 Insecure container runtime configurations | Deny rules for privileged, privilege escalation, root and writable root filesystems; Pod Security `restricted`; seccomp `RuntimeDefault`, all capabilities dropped | Azure Policy, Pod Security Admission, CI (Checkov) | [07](../evidence/07-break-fix-admission-and-runtime.txt) tests 1 and 1b, [08](../evidence/08-checkov-kubernetes.txt) | ✅ |
| 4.4.4 App vulnerabilities | Parameterized Table Storage queries; security headers and an XSS test on the web tier; hash-locked dependencies scanned by Trivy | Code, CI | [02](../evidence/02-image-comparison.md) | 🟡 |
| 4.4.5 Rogue containers | Only digest-pinned images from this registry can run; Defender alerts on suspicious processes (98 s) and API requests (19 min) | Azure Policy, Defender for Containers | [07](../evidence/07-break-fix-admission-and-runtime.txt) tests 1 and 3b | ✅ |

## 4.5 Host OS risks

| Risk | Control in this project | Enforced by | Evidence | Status |
|---|---|---|---|---|
| 4.5.1 Large attack surface | Azure Linux, a minimal container host OS | AKS | [05](../evidence/05-aks-cluster.txt) | ✅ |
| 4.5.2 Shared kernel | No privileged pods, all capabilities dropped, seccomp `RuntimeDefault`, non-root | Azure Policy, Pod Security Admission | [07](../evidence/07-break-fix-admission-and-runtime.txt) | 🟡 |
| 4.5.3 Host OS component vulnerabilities | Node OS channel `SecurityPatch`; Image Cleaner removes unused images every 48 hours | AKS | [05](../evidence/05-aks-cluster.txt) | ✅ |
| 4.5.4 Improper user access rights | Cluster access only through the Entra ID–authenticated API; run command disabled; no interactive node access used | AKS configuration | [05](../evidence/05-aks-cluster.txt) | 🟡 |
| 4.5.5 Host file system tampering | Read-only container root filesystems; Pod Security `restricted` forbids host path mounts; host encryption | Pod Security Admission, AKS | [06](../evidence/06-app-deployment.txt), [07](../evidence/07-break-fix-admission-and-runtime.txt) | ✅ |

## CIS AKS Benchmark

The CIS Benchmark for AKS splits into cluster policies (what runs inside Kubernetes) and managed services (how Azure runs it). Node and control-plane settings are managed by Azure.

| CIS area | This project | Evidence |
|---|---|---|
| Policies: RBAC and service accounts | Azure RBAC for Kubernetes; one service account per workload; service account tokens not mounted | [05](../evidence/05-aks-cluster.txt), [06](../evidence/06-app-deployment.txt) |
| Policies: Pod Security Standards | Pod Security `restricted` on the app namespace, backed by Azure Policy deny rules | [06](../evidence/06-app-deployment.txt), [07](../evidence/07-break-fix-admission-and-runtime.txt) |
| Policies: network policies | Calico, default deny in the app namespace | [06](../evidence/06-app-deployment.txt) |
| Policies: secrets management | Key Vault through the CSI driver, mounted as files; no Kubernetes Secrets | [06](../evidence/06-app-deployment.txt) |
| Policies: general | Workloads in their own namespace, never `default`; seccomp `RuntimeDefault`; 185 of 185 Checkov Kubernetes checks pass on the rendered manifests | [08](../evidence/08-checkov-kubernetes.txt) |
| Managed services: image registry and scanning | Trivy in CI, Defender registry scanning, trusted registry only | [02](../evidence/02-image-comparison.md), [07](../evidence/07-break-fix-admission-and-runtime.txt) |
| Managed services: identity and access | Entra ID only, local accounts disabled, workload identity for the app (no keys) | [05](../evidence/05-aks-cluster.txt), [06](../evidence/06-app-deployment.txt) |
| Managed services: cluster networking | API server authorized IP ranges, network policies | [05](../evidence/05-aks-cluster.txt), [06](../evidence/06-app-deployment.txt) |
| Managed services: key management | Platform-managed keys with host encryption (customer-managed keys are shown in [Project 1](https://github.com/Subash-1507/multicloud-secure-iac)) | [05](../evidence/05-aks-cluster.txt) |

## Scanner suppressions

24 inline suppressions, each next to the code with its reason: 4 in Dockerfiles and 20 in Terraform. Most cover features that need ACR Premium or private networking, which this budget build does not buy (see [Honest trade-offs](../../README.md#honest-trade-offs)). No suppression exists in the Kubernetes manifests.

## Defender for Cloud findings at the end of the build

| Finding | Response |
|---|---|
| Container registries should not allow unrestricted network access | Accepted: ACR Basic cannot restrict network access; Entra ID is required and the matching Azure Policy audits it |
| Storage accounts should restrict network access (the Terraform state account) | Accepted: the state must be reachable from Codespaces; access requires Entra ID (shared keys disabled) and a role scoped to the state container |
| Kubernetes nodes should be upgraded to a newer version | Noted: patch versions upgrade automatically; minor upgrades are a planned, manual step |

## Gaps and what production would do

| Gap (🟡 above) | Production alternative |
|---|---|
| No malware scan of image contents (4.1.3) | Add an image malware scanner in CI, alongside Defender's runtime detection |
| No registry retention policy; registry reachable from the internet (4.2.2, 4.2.3) | ACR Premium with retention, a private endpoint and public access disabled |
| Public API server endpoint (4.3.2) | Private cluster with a jump host or VPN |
| System and app pods share one node pool (4.3.4) | Separate system and user node pools, with taints |
| Kubernetes minor upgrades are manual (4.4.1) | Upgrade channel `stable` with a maintenance window |
| No domain-name (FQDN) egress filtering (4.4.2) | Azure Firewall or a service mesh egress gateway |
| No dynamic application testing (4.4.4) | DAST (for example OWASP ZAP) against a staging deployment |
| No sandboxed container runtime (4.5.2) | Kata Containers (Pod Sandboxing) for untrusted workloads |
| Node SSH configuration not separately audited (4.5.4) | Disable node SSH and audit node access |
| Gatekeeper fails open (`failurePolicy: Ignore`) | Pod Security `restricted` on every app namespace (done here) and an alert on Gatekeeper health |
