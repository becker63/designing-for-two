# static-control-plane

A reproducible, GitOps-driven Kubernetes control plane built with:

- [Crossplane](https://crossplane.io/)
- KCL compositions
- [FluxCD](https://fluxcd.io/)
- [Infisical](https://infisical.com/)
- Nix flakes
- Buck2-based code generation
- Structural tests over rendered configuration

This repository explores treating infrastructure configuration as a build artifact: typed, testable, and reproducible.

---

## What This Is

This is an experimental Kubernetes control plane built around three ideas:

1. Infrastructure is a compilation target.
2. Configuration should be typed and testable.
3. Reconciliation boundaries should be explicit.

It uses:

- **Crossplane** in function-pipeline mode
- **KCL** for composition logic
- **FluxCD** for GitOps delivery
- **Infisical** for secret materialization
- Hermetic schema generation using Buck2 and Nix
- Tests that operate on rendered resource graphs

It is not production hardened. It is a design experiment.

---

## High-Level Architecture

### 1. Composition with KCL (Crossplane Function Pipeline)

Compositions are written in KCL and executed inside Crossplane’s function-pipeline mode.

Each function:

- Reads observed composed resources (OCDS)
- Emits new resources conditionally
- Encodes readiness explicitly
- Produces deterministic output

KCL is treated as a constrained configuration language.  
It evaluates to Kubernetes manifests — or fails.

There is no runtime scripting inside reconciliation.

---

### 2. Hermetic Code Generation

CRDs and upstream schemas are not manually wrapped.

Instead:

- CRDs → Python models via `python-crd-cloudcoil`
- CRDs → KCL schemas via `kcl import -m crd`
- FRP Go structs → JSON Schema → KCL schemas via a custom Go tool

All generation:

- Runs through Buck2
- Uses Nix-pinned toolchains
- Produces deterministic output
- Is intentionally not committed to Git

Schemas can be regenerated from source at any time.

Infrastructure schema is reproducible.

---

### 3. Typed Execution Layer

The `lib/` directory contains:

- A minimal KCL execution wrapper
- A small override system for test scenarios
- Pytest integration
- Typed resource matching using Cloudcoil models

Tests operate on rendered resource graphs rather than raw YAML strings.

This shifts validation from string matching to structural guarantees.

---

### 4. Structural Tests

Tests verify:

- Required exports exist
- Helm releases render correctly
- FRP configs pass native `verify`
- Groups of KCL files behave as expected

Configuration is treated as something that can regress.

Rendered infrastructure is testable.

---

### 5. GitOps Delivery

GitOps delivery is handled by [FluxCD](https://fluxcd.io/).

Flux:

- Reconciles this repository into Kubernetes cluster state
- Installs [Crossplane](https://crossplane.io/) controllers
- Applies Helm releases and CRDs
- Deploys the [Infisical](https://infisical.com/) Kubernetes operator

Crossplane performs infrastructure reconciliation.

Infisical materializes secrets for workloads.

Flux’s role is strictly declarative state convergence.

Control loop layering:

Git → Flux → Controllers (Crossplane, Infisical) → Kubernetes resources

The cluster bootstraps entirely from Git.

---

## What This Demonstrates

This project reflects experience with:

- Crossplane composition design
- Function-pipeline mode
- KCL as a configuration language
- CRD introspection and schema tooling
- Nix-based reproducible environments
- Buck2 build rules
- Typed Kubernetes resource modeling
- Structural testing of infrastructure artifacts
- GitOps workflows
- Control-plane boundary design

It is intentionally opinionated.

---

## Development

Install Nix, then:

```bash
nix develop
```

This provisions all toolchains and runs required schema generation.

From there:

```bash
buck2 build //...
pytest
```
