# Hermetic Control Plane

## Overview

This repository contains a fully reproducible, GitOps-driven control plane built with:

- **Kubernetes + Crossplane**
- **KCL-based compositions**
- **FluxCD**
- **Nix flakes**
- **Buck2 for hermetic code generation**
- **Typed model generation for CRDs**
- **Structural tests over rendered configuration**

The goal is not just to provision infrastructure — but to treat infrastructure configuration as a **typed, testable, reproducible artifact**.

---

## Design Thesis

This project explores a simple question:

> What if infrastructure composition behaved more like a compiler pipeline than a collection of YAML files?

Instead of manually stitching CRDs and Helm charts together, this repository:

- Generates typed Python models from CRDs
- Generates KCL schemas from CRDs and Go types
- Executes KCL compositions as structured programs
- Tests rendered outputs structurally
- Ensures reproducibility through Nix and Buck2

The control plane is treated as a **build artifact**, not as mutable cluster state.

---

## Architecture

### 1. KCL-Based Composition

Compositions are written in KCL and executed via Crossplane’s function pipeline mode.

Example: DigitalOcean droplet + DNS + custom image composition.

Each function:
- Reads observed composed resources (OCDS)
- Emits new resources conditionally
- Treats readiness and lifecycle explicitly

This makes reconciliation behavior legible and testable.

---

### 2. Hermetic Code Generation (Buck2 + Nix)

CRDs are not manually wrapped.

Instead:

- CRDs → Python models via `python-crd-cloudcoil`
- CRDs → KCL schemas via `kcl import -m crd`
- FRP Go structs → JSON Schema → KCL schemas via custom Go tool

All generation:
- Runs inside Buck2
- Uses Nix-pinned toolchains
- Produces deterministic output
- Is not committed to git (reproducible from source)

This eliminates schema drift.

---

### 3. Typed Execution Layer

The `lib/` directory contains:

- A KCL execution runtime wrapper
- A lightweight override system for test scenarios
- A pytest integration layer
- Typed resource matching using Cloudcoil models

Tests operate on rendered resource graphs, not just text.

---

### 4. Structural Tests

Tests verify:

- Required exports exist
- Helm releases are valid
- FRP configs pass `verify`
- Grouped KCL files behave correctly

This treats configuration as something that can regress.

---

### 5. GitOps Delivery

FluxCD is used to:

- Sync this repository into cluster state
- Install Crossplane
- Install Helm-based dependencies
- Manage secret injection via Infisical

The cluster bootstraps from the repo.

---

## What This Demonstrates

This project signals experience in:

- Crossplane composition design
- Function-pipeline mode
- KCL as a configuration language
- CRD introspection and schema tooling
- Reproducible build systems (Nix + Buck2)
- Infrastructure code generation
- Typed Kubernetes resource modeling
- Structural testing of infra artifacts
- GitOps workflow design

It is intentionally opinionated and non-trivial.

---

## Development

Install Nix and enter the shell:

```bash
nix develop
