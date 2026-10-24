# 0001. Run the landing zone in Korea Central

- Status: accepted
- Date: 2026-10-24

## Context

The landing zone was first built in Southeast Asia. Before creating AKS, a capacity check showed that this
subscription (Azure for Students) is offered only **Arm64** VM sizes (Bpsv2) in Southeast Asia, and that family
is not on AKS's supported Arm64 list. Korea Central offers a full range of x64 sizes within quota.

Running only AKS in another region was rejected: Key Vault and Storage trust the cluster's subnet through VNet
service endpoints, which are regional. A split would have forced IP-based firewall rules instead.

## Decision

Move the whole landing zone to `koreacentral` and run AKS on `Standard_B2s_v2` (x64, 2 vCPU, 8 GB).
Terraform state stays in Southeast Asia (it is not part of the workload).

## Consequences

- One region, and nothing is trusted by IP: Key Vault and Storage allow only `snet-aks`.
- The move recreated the empty landing zone with a new name suffix. The old Key Vault name stays reserved for
  7 days under purge protection, by design.
- Lesson recorded: Azure Resource Manager is eventually consistent. Recreating a resource group with the same
  name immediately after deleting it produced stale 404s. Recovery used `terraform import` and `untaint`, and
  waiting for consistency instead of re-applying on stale reads.
## Update (2026-10-24): node size

The first cluster used `Standard_B2s_v2` with a 32 GB OS disk. The node went into `DiskPressure` (AKS node images
pre-cache system images), and the system add-ons alone requested 86% of its 2 vCPUs, leaving no room for the
Defender sensor or the application. The cluster now runs on `Standard_B4s_v2` (4 vCPU, 16 GB) with a 64 GB OS disk.
It was recreated rather than resized, because an in-place rotation would temporarily need 8 vCPUs, above this
subscription's regional quota of 6. The cluster is stopped whenever it is not in use.
