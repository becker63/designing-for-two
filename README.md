# static-control-plane

Crossplane-based Kubernetes control plane that provisions a NixOS-backed FRP gateway on DigitalOcean, reconciles DNS records, and deploys cluster infrastructure via GitOps.

---

## What It Does

- Provisions a custom NixOS VM image in DigitalOcean via Crossplane.
- Creates and manages Droplets using Crossplane pipeline-mode compositions.
- Conditionally reconciles DNS records once Droplet IPs are available.
- Deploys FRP client as a Kubernetes DaemonSet to expose services behind NAT.
- Installs and manages Crossplane, FluxCD, Traefik, cert-manager, and Infisical via HelmRelease resources.
- Uses GitOps (FluxCD) to converge cluster state from this repository.
- Validates rendered KCL output using structural pytest tests and native `frpc/frps verify`.

This repository represents a full Git → Cluster → Cloud reconciliation flow.

---

## Architecture Overview

```
                ┌──────────────────────────┐
                │        Git Repo          │
                │  (this repository)       │
                └────────────┬─────────────┘
                             │
                             ▼
                       ┌───────────┐
                       │  FluxCD   │
                       └─────┬─────┘
                             │
                             ▼
                     ┌───────────────┐
                     │   Kubernetes   │
                     │   Control Plane│
                     └─────┬─────────┘
                           │
                           ▼
                     ┌───────────────┐
                     │  Crossplane    │
                     │  (Pipeline)    │
                     └─────┬─────────┘
                           │
            ┌──────────────┴──────────────┐
            ▼                             ▼
     DigitalOcean                    Kubernetes
   (Image, Droplet, DNS)         (FRP, Traefik, TLS,
                                  Infisical, etc.)
```

Flow:

1. Flux reconciles this repo into the cluster.
2. Crossplane executes KCL pipeline functions.
3. Custom NixOS image → Droplet → DNS records.
4. FRP server runs on VPS.
5. FRP client runs inside cluster to expose services behind NAT.

---

## Crossplane Composition Design

The DigitalOcean composition uses Crossplane **pipeline mode** with KCL functions:

- `image.k` → creates custom image resource.
- `droplet.k` → waits for image readiness, provisions Droplet.
- `dns.k` → waits for Droplet IP, provisions DNS records.

Each step:

- Reads observed composed resources (OCDS).
- Emits new resources conditionally.
- Avoids runtime scripting inside reconciliation.

This models real dependency ordering inside infrastructure provisioning.

---

## Reproducible Tooling

CRDs and schemas are not hand-written.

Generation pipeline:

- CRDs → Python models via custom `python-crd-cloudcoil`.
- CRDs → KCL schemas via `kcl import -m crd`.
- FRP Go structs → JSON Schema → KCL schemas via custom Go codegen.
- All tooling is Nix-pinned and invoked via Buck2.
- Generated sources are reproducible and not committed.

This enables typed validation of infrastructure artifacts.

---

## Testing Strategy

Tests operate on rendered KCL output, not raw YAML strings.

They verify:

- Required exports exist.
- HelmRelease objects render correctly.
- FRP configurations pass native `verify` commands.
- Grouped configuration files behave consistently.

Infrastructure is treated as something that can regress.

---

## Tech Stack

- Kubernetes
- Crossplane (pipeline mode)
- KCL
- DigitalOcean Provider
- FluxCD
- Traefik
- cert-manager
- Infisical
- FRP
- Nix flakes
- Buck2
- pytest
- Cloudcoil (typed resource validation)

---

## Why This Is Interesting

This project demonstrates:

- Conditional resource generation inside Crossplane pipeline mode.
- Real cloud infrastructure provisioning (DigitalOcean image + Droplet + DNS).
- GitOps-based control plane layering.
- Reproducible schema tooling for CRDs and external systems.
- Structural testing of rendered infrastructure resources.

It is not a demo YAML collection — it is a full reconciliation system from Git to cloud resources.

---

## Development

Requires Nix.

```bash
nix develop
```

All schemas and toolchains are pinned via flakes.
