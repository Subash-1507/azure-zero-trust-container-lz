# Zero-Trust Container Landing Zone on Azure

**Hardened Docker images, a locked-down AKS cluster, and Azure Policy guardrails that refuse anything unsafe, before it ever runs.**

> 🚧 **Status: in progress.** This README tells the plan as a story; each chapter is ticked off as it is built, with evidence.
> Part 2 of my DevSecOps portfolio. Part 1: [multicloud-secure-iac](https://github.com/Subash-1507/multicloud-secure-iac), secure infrastructure as code with keyless, approval-gated deployments.

---

## The story

In my first project I secured the *infrastructure*: Terraform, scanners on every pull request, and a pipeline that deploys to Azure without a single stored password. But infrastructure is only the floor. What actually runs on it is **containers**, and that is where most real-world incidents start:

- an image pulled from a public registry that nobody has checked,
- a container running as **root**, one escape away from the host,
- a password baked into an image layer,
- a resource created by hand at 2 a.m. with no owner and no tags.

So I asked a simple question: **what if the platform itself said "no"?**

Not a checklist someone may forget, not a wiki page. A landing zone where:

1. **Images are hardened by design**: built in stages, on a minimal base, as a non-root user.
2. **Only my private registry is trusted**: a container from anywhere else is rejected at the door.
3. **Azure Policy blocks unsafe deployments** automatically: root containers, privilege escalation, untagged resources, an open Key Vault.
4. **No credentials exist anywhere**: the app reaches its secrets and data through managed identities.
5. **Defender for Cloud watches continuously**, scans images for vulnerabilities and maps everything to a compliance framework.

And then I **try to break my own rules** (deploy a root container from Docker Hub, create an untagged resource, push a vulnerable image) and capture the platform stopping me. A control you have not tested is only a hope.

---

## What I am building

```mermaid
flowchart LR
  user["User"] --> web["web<br/>nginx-unprivileged<br/>non-root · read-only FS"]
  web --> api["api<br/>FastAPI on distroless<br/>non-root · read-only FS"]
  api -->|"workload identity<br/>(no keys)"| table[("Azure Table Storage<br/>Entra ID only<br/>firewall deny")]
  api -->|"Secrets Store CSI"| kv["Key Vault<br/>RBAC · purge protection<br/>firewall deny"]
  acr["Azure Container Registry<br/>Entra ID only<br/>admin user off"] -->|"AcrPull<br/>(kubelet identity)"| aks
  subgraph aks["AKS: Entra ID only, local accounts off"]
    web
    api
  end
  policy["Azure Policy<br/>(Gatekeeper)"] -.->|"denies unsafe pods"| aks
  defender["Defender for Containers"] -.->|"scans images<br/>runtime alerts"| acr
  defender -.-> aks
```

**Three tiers:** a web front end, an API, and a data store, so the security controls are tested on something that behaves like a real application, while staying small enough that the focus stays on security rather than app code.

---

## The plan, chapter by chapter

| | Chapter | What happens | Evidence I will capture |
|---|---|---|---|
| ✅ | **0. Foundations** | Repo, Codespaces dev container, CI security gates (Hadolint, Trivy, SBOM, Checkov, Gitleaks, Terraform validate) | Green pipeline |
| ✅ | **1. Hardened images** | Build a deliberately naive image first, then a hardened multi-stage, distroless, non-root version | **Before/after: image size and CVE count** |
| ✅ | **2. Guardrails first** | Custom and built-in Azure Policies, grouped into one initiative, assigned **before** any resource exists | Compliance blade, policy JSON |
| ✅ | **3. Landing zone** | VNet, Container Registry, Key Vault and Storage, each locked down | Resource configuration |
| ✅ | **4. The cluster** | AKS with the Azure Policy add-on, workload identity, Entra ID-only access, Defender for Containers | Cluster security settings |
| ⬜ | **5. Deploy the app** | Kubernetes manifests with strict security contexts, default-deny network policy, secrets from Key Vault | Running app, no secrets in the cluster |
| ⬜ | **6. Break-fix tests** | Three deliberate violations (below) | **Screenshots of each block or alert** |
| ⬜ | **7. Compliance and teardown** | Map controls to NIST SP 800-190 and CIS, then delete everything | Mapping table, cost report |

---

## Security controls

| Risk | Control | Enforced by |
|---|---|---|
| Container runs as root | Images built as a non-root user; pods must run as non-root | Dockerfile + **Azure Policy (Deny)** |
| Privilege escalation, privileged containers | `allowPrivilegeEscalation: false`, all Linux capabilities dropped | **Azure Policy (Deny)** |
| Tampered or writable container filesystem | Read-only root filesystem | **Azure Policy (Deny)** |
| Untrusted images | Only images from my Azure Container Registry may run | **Azure Policy (Deny)** |
| Vulnerable images | Image scanning with Trivy in CI and Defender in Azure | CI gate + **Defender for Containers** |
| Hardcoded credentials | Managed identities and workload identity; secrets only in Key Vault | Design + Gitleaks in CI |
| Exposed Key Vault | Firewall default deny, VNet access only | **Azure Policy (Deny)** |
| Ungoverned resources | Environment, CostCenter and DataClassification tags required | **Custom Azure Policy (Deny)** |
| Unauthorized cluster access | Entra ID authentication only, Kubernetes local accounts disabled | AKS configuration |

---

## Break-fix tests: trying to break my own rules

| # | What I will try | What should happen |
|---|---|---|
| 1 | Deploy `nginx` from **Docker Hub**, running as **root** with privilege escalation allowed | The cluster **rejects** it, listing every policy it breaks |
| 2 | Create Azure resources **without governance tags** and a Key Vault **with no firewall** | Azure Resource Manager **refuses** the request (`RequestDisallowedByPolicy`) |
| 3 | Push a deliberately **outdated, vulnerable image** and simulate suspicious activity in the cluster | Defender **reports the CVEs** and raises a **security alert** |

---

## Honest trade-offs

This is a personal project on student credits, so I chose a **budget build** and I am recording what that costs in security, the same way a real team records accepted risk:

| Trade-off | Why | Production alternative |
|---|---|---|
| Container Registry on the **Basic** tier, reachable over the internet (Entra ID login required, admin user off) | Private endpoints and network rules need the Premium tier | Premium tier with a private endpoint; the matching policies switch from Audit to Deny |
| Key Vault and Storage use **firewalls and VNet service endpoints**, not private endpoints | Private endpoints cost extra per endpoint | Private endpoints and private DNS zones |
| AKS API server is public, restricted to my IP and Entra ID login | A private cluster needs a jump host | Private cluster |

**Cost plan:** about $8–12 of credits if built within a week, then **everything is deleted**. Defender for Containers runs on its free trial.

---

## Repository layout (planned)

```
app/            web and api source, with hardened Dockerfiles
policies/       custom Azure Policy definitions and the initiative (policy as code)
infra/          Terraform: governance, network, registry, Key Vault, AKS, Defender
k8s/            Kubernetes manifests: namespaces, deployments, network policies, identities
tests/          the three break-fix scenarios
docs/           architecture, compliance mapping, evidence screenshots
.github/        CI security gates and the deployment workflow
```

---

## Author

**Subash Chandra Bose**: DevOps, Cloud & Security Engineer · Microsoft Certified (SC-500, AZ-104, SC-200)
[Portfolio](https://subash-1507.github.io) · [LinkedIn](https://www.linkedin.com/in/subash-chandra-bose-014bb21b5) · [GitHub](https://github.com/Subash-1507)
