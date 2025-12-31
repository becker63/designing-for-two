This repository contains infrastructure configuration for a small home / edge network setup. It uses Crossplane and Kubernetes as the control plane, with configuration written in KCL and delivered via GitOps. Tooling, schema generation, and tests are managed with Nix and Buck2 to keep builds reproducible. Tests are used to validate rendered configuration and integration points rather than to drive provisioning.

### Install Nix

If you don’t already have Nix installed, follow the official installer:

curl -L https://nixos.org/nix/install | sh

After installation, restart your shell and ensure flakes are enabled.

### Enter the development environment

From the repository root:

nix develop

This will provision all required toolchains, run all schema and code generation steps, and leave you in a ready-to-use shell. No additional setup is required.
